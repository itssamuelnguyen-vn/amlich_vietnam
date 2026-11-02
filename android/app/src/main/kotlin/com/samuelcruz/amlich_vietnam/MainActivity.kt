package com.samuelcruz.amlich_vietnam

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts Flutter and two channels.
 *
 * "amlich/widget":
 * - Flutter → Android: `sync` stores event occurrences, settings and the countdown target, then redraws the
 *   widgets and reschedules reminders; `takeLaunchDate` returns the date a widget or notification tap opened the app
 *   on (once); `notificationsEnabled` / `requestNotificationPermission` for reminders.
 * - Android → Flutter: `showDate` when a widget tap reaches the already running app.
 *
 * "amlich/files": `saveText` / `openText` through the system document picker (backup and restore).
 */
class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null
    private var launchDate: String? = null

    private var pendingFile: MethodChannel.Result? = null
    private var pendingText: String? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchDate = dateOf(intent)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        widgetChannel = MethodChannel(messenger, "amlich/widget").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        WidgetData.save(
                            this@MainActivity,
                            call.argument<String>("occurrences") ?: "[]",
                            call.argument<String>("settings") ?: "{}",
                            call.argument<String>("countdown") ?: "{}",
                        )
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
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) return
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
        if (requestCode != REQUEST_NOTIFICATIONS) return
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
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
    }
}
