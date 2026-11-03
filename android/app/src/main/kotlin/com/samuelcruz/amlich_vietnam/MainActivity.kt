package com.samuelcruz.amlich_vietnam

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.time.LocalDate
import java.util.concurrent.Executors

/**
 * Hosts Flutter and two channels.
 *
 * "amlich/widget":
 * - Flutter → Android: `sync` stores event occurrences, settings and the countdown target, then redraws the
 *   widgets and reschedules reminders; `takeLaunchDate` returns the date a widget or notification tap opened the app
 *   on (once); `notificationsEnabled` / `requestNotificationPermission` for reminders.
 * - Android → Flutter: `showDate` when a widget tap reaches the already running app.
 *
 * "amlich/files": `saveText` / `openText` (backup and restore) and `pickImage` (counter photos) through the system
 * document picker; `shareImage` opens the share sheet with a PNG.
 *
 * "amlich/calendar": calendar permission, the phone's writable calendars, and `sync` / `clear` of the app's events in
 * one of them (GoogleCalendarSync).
 */
class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null
    private var launchDate: String? = null

    private var pendingFile: MethodChannel.Result? = null
    private var pendingText: String? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchDate = dateOf(intent)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        widgetChannel = MethodChannel(messenger, "amlich/widget").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        val keys = listOf("occurrences", "settings", "countdown", "counter", "milestones")
                        WidgetData.save(this@MainActivity, keys.mapNotNull { k -> call.argument<String>(k)?.let { k to it } }.toMap())
                        Widgets.updateAll(this@MainActivity)
                        result.success(null)
                    }
                    "notificationsEnabled" ->
                        result.success(getSystemService(NotificationManager::class.java).areNotificationsEnabled())
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT < 33 ||
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(getSystemService(NotificationManager::class.java).areNotificationsEnabled())
                        } else {
                            pendingPermission = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
                        }
                    }
                    "takeLaunchDate" -> {
                        result.success(launchDate)
                        launchDate = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(messenger, "amlich/calendar").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (hasCalendarPermission()) {
                        result.success(true)
                    } else {
                        pendingPermission = result
                        requestPermissions(
                            arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
                            REQUEST_CALENDAR,
                        )
                    }
                }
                "hasPermission" -> result.success(hasCalendarPermission())
                "calendars" -> background(result) {
                    GoogleCalendarSync.calendars(this).map {
                        mapOf("id" to it.id, "name" to it.name, "account" to it.account, "color" to it.color, "google" to it.isGoogle)
                    }
                }
                "sync" -> {
                    val calendarId = (call.argument<Number>("calendarId") ?: return@setMethodCallHandler result.error("args", "calendarId", null)).toLong()
                    val items = JSONArray(call.argument<String>("items") ?: "[]").let { a ->
                        (0 until a.length()).map {
                            val o = a.getJSONObject(it)
                            SyncItem(o.getString("k"), o.getString("t"), LocalDate.parse(o.getString("d")), o.getString("n"))
                        }
                    }
                    background(result) {
                        val (added, changed, removed) = GoogleCalendarSync.sync(this, calendarId, items)
                        mapOf("added" to added, "changed" to changed, "removed" to removed)
                    }
                }
                "clear" -> background(result) { GoogleCalendarSync.clear(this) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "amlich/files").setMethodCallHandler { call, result ->
            if (pendingFile != null) {
                result.error("busy", "Another file dialog is open", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "saveText" -> {
                    pendingFile = result
                    pendingText = call.argument<String>("text") ?: ""
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("application/json")
                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "amlich.json")
                    startActivityForResult(intent, REQUEST_SAVE)
                }
                "shareImage" -> {
                    // Not a dialog with a result: answer at once and let the share sheet run on its own.
                    try {
                        val dir = java.io.File(cacheDir, "share").apply { mkdirs() }
                        val file = java.io.File(dir, "amlich.png")
                        file.writeBytes(call.argument<ByteArray>("bytes") ?: ByteArray(0))
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        val send = Intent(Intent.ACTION_SEND)
                            .setType("image/png")
                            .putExtra(Intent.EXTRA_STREAM, uri)
                            .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(Intent.createChooser(send, "Chia sẻ"))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("share", e.message, null)
                    }
                    return@setMethodCallHandler
                }
                "pickImage" -> {
                    pendingFile = result
                    startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("image/*"),
                        REQUEST_IMAGE,
                    )
                }
                "openText" -> {
                    pendingFile = result
                    // "*/*": Drive and other providers often label .json files as octet-stream.
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
                    startActivityForResult(intent, REQUEST_OPEN)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("startActivityForResult is enough for two one-off pickers")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN && requestCode != REQUEST_IMAGE) return
        val result = pendingFile ?: return
        pendingFile = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == REQUEST_SAVE) false else null)
            return
        }
        try {
            if (requestCode == REQUEST_SAVE) {
                contentResolver.openOutputStream(uri, "wt")!!.use { it.write(pendingText!!.toByteArray()) }
                result.success(true)
            } else if (requestCode == REQUEST_IMAGE) {
                // Copied into the app's own storage, so the photo survives the original being moved or deleted.
                val dir = java.io.File(filesDir, "photos").apply { mkdirs() }
                val file = java.io.File(dir, "counter_${System.currentTimeMillis()}.img")
                contentResolver.openInputStream(uri)!!.use { input -> file.outputStream().use { input.copyTo(it) } }
                result.success(file.absolutePath)
            } else {
                result.success(contentResolver.openInputStream(uri)!!.use { it.readBytes().decodeToString() })
            }
        } catch (e: Exception) {
            result.error("io", e.message, null)
        } finally {
            pendingText = null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS && requestCode != REQUEST_CALENDAR) return
        pendingPermission?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        pendingPermission = null
    }

    private fun hasCalendarPermission() =
        checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    /** Runs calendar work off the UI thread and answers on it. */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        executor.execute {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                runOnUiThread { result.error("calendar", e.message, null) }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        dateOf(intent)?.let { widgetChannel?.invokeMethod("showDate", it) }
    }

    /** "2026-11-02" from an amlich://date/2026-11-02 intent. */
    private fun dateOf(intent: Intent?): String? =
        intent?.data?.takeIf { it.scheme == "amlich" && it.host == "date" }?.lastPathSegment

    private companion object {
        const val REQUEST_SAVE = 4101
        const val REQUEST_OPEN = 4102
        const val REQUEST_NOTIFICATIONS = 4103
        const val REQUEST_CALENDAR = 4104
        const val REQUEST_IMAGE = 4105
    }
}
