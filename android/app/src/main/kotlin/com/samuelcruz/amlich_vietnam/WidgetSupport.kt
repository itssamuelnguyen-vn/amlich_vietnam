package com.samuelcruz.amlich_vietnam

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import org.json.JSONArray
import java.time.LocalDate
import java.time.ZoneId

/** One event occurrence written by Flutter (lib/widget/widget_bridge.dart). */
data class Occurrence(val title: String, val date: LocalDate, val color: Int)

object WidgetData {
    private const val PREFS = "amlich_widget"
    private const val KEY_OCCURRENCES = "occurrences"

    fun saveOccurrences(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_OCCURRENCES, json).apply()
    }

    /** Occurrences from the start of last month to a year ahead, sorted by date. */
    fun occurrences(context: Context): List<Occurrence> {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_OCCURRENCES, null)
            ?: return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map {
                val o = array.getJSONObject(it)
                Occurrence(o.getString("t"), LocalDate.parse(o.getString("d")), o.getInt("c"))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun monthOffset(context: Context, widgetId: Int): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("month_offset_$widgetId", 0)

    fun setMonthOffset(context: Context, widgetId: Int, offset: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt("month_offset_$widgetId", offset).apply()
    }
}

object Widgets {
    const val ACTION_REFRESH = "com.samuelcruz.amlich_vietnam.WIDGET_REFRESH"

    fun today(): LocalDate = LocalDate.now(ZoneId.systemDefault())

    /** Redraws every widget and schedules the next midnight refresh. */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        TodayWidgetProvider.update(context, manager, ids(context, manager, TodayWidgetProvider::class.java))
        MonthWidgetProvider.update(context, manager, ids(context, manager, MonthWidgetProvider::class.java))
        scheduleMidnight(context)
    }

    private fun ids(context: Context, manager: AppWidgetManager, cls: Class<*>): IntArray =
        manager.getAppWidgetIds(ComponentName(context, cls))

    private fun hasWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return ids(context, manager, TodayWidgetProvider::class.java).isNotEmpty() ||
            ids(context, manager, MonthWidgetProvider::class.java).isNotEmpty()
    }

    /**
     * Refreshes just after midnight with an inexact, non-waking alarm: no exact-alarm permission is needed, and if the
     * phone is asleep the widgets update as soon as it wakes. updatePeriodMillis in the widget XML is the fallback.
     */
    fun scheduleMidnight(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 0, Intent(context, WidgetRefreshReceiver::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        if (!hasWidgets(context)) {
            alarms.cancel(pending)
            return
        }
        val next = today().plusDays(1).atStartOfDay().plusSeconds(5)
        val millis = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        alarms.setWindow(AlarmManager.RTC, millis, 10 * 60 * 1000L, pending)
    }

    /** Opens the app on [date] (or today when null). */
    fun openApp(context: Context, date: LocalDate?, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (date != null) data = Uri.parse("amlich://date/$date")
        }
        return PendingIntent.getActivity(
            context, requestCode, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

}

/** Midnight alarm, clock and time-zone changes: redraw everything. */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Widgets.updateAll(context)
}
