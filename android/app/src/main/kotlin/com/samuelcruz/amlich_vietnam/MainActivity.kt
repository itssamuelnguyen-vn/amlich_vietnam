package com.samuelcruz.amlich_vietnam

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts Flutter and the "amlich/widget" channel:
 * - Flutter → Android: `updateWidgets` stores the upcoming event occurrences and redraws the widgets;
 *   `takeLaunchDate` returns the date a widget tap opened the app on (once).
 * - Android → Flutter: `showDate` when a widget tap reaches the already running app.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var launchDate: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchDate = dateOf(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "amlich/widget").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidgets" -> {
                        WidgetData.saveOccurrences(this@MainActivity, call.argument<String>("occurrences") ?: "[]")
                        Widgets.updateAll(this@MainActivity)
                        result.success(null)
                    }
                    "takeLaunchDate" -> {
                        result.success(launchDate)
                        launchDate = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        dateOf(intent)?.let { channel?.invokeMethod("showDate", it) }
    }

    /** "2026-11-02" from an amlich://date/2026-11-02 intent. */
    private fun dateOf(intent: Intent?): String? =
        intent?.data?.takeIf { it.scheme == "amlich" && it.host == "date" }?.lastPathSegment
}
