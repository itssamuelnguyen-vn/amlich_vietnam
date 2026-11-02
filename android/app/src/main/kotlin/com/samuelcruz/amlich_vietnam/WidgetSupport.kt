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
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId

/** One event occurrence written by Flutter (lib/widget/widget_bridge.dart); [remindDays] is -1 for no reminder. */
data class Occurrence(val title: String, val date: LocalDate, val color: Int, val remindDays: Int)

/** Settings Flutter sends along (see WidgetBridge.syncPayload). */
data class SyncSettings(
    val weekStartsMonday: Boolean = true,
    val holidayKinds: Set<String> = LunarCalendar.ALL_KINDS,
    val reminderHour: Int = 7,
    val reminderMinute: Int = 0,
    val lunarReminders: Boolean = false,
)

data class Countdown(val title: String, val dates: List<LocalDate>)

/** What Flutter last pushed, kept in SharedPreferences so widgets and alarms work while the app is closed. */
object WidgetData {
    private const val PREFS = "amlich_widget"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(context: Context, occurrences: String, settings: String, countdown: String) {
        prefs(context).edit()
            .putString("occurrences", occurrences)
            .putString("settings", settings)
            .putString("countdown", countdown)
            .apply()
    }

    /** Occurrences from the start of last month to a year ahead, sorted by date. */
    fun occurrences(context: Context): List<Occurrence> = try {
        val array = JSONArray(prefs(context).getString("occurrences", null) ?: "[]")
        (0 until array.length()).map {
            val o = array.getJSONObject(it)
            Occurrence(o.getString("t"), LocalDate.parse(o.getString("d")), o.getInt("c"), o.optInt("r", -1))
        }
    } catch (e: Exception) {
        emptyList()
    }

    fun settings(context: Context): SyncSettings = try {
        val o = JSONObject(prefs(context).getString("settings", null) ?: "{}")
        val kinds = o.optJSONArray("holidayKinds")
        SyncSettings(
            weekStartsMonday = o.optBoolean("weekStartsMonday", true),
            holidayKinds = if (kinds == null) LunarCalendar.ALL_KINDS else (0 until kinds.length()).map { kinds.getString(it) }.toSet(),
            reminderHour = o.optInt("reminderHour", 7),
            reminderMinute = o.optInt("reminderMinute", 0),
            lunarReminders = o.optBoolean("lunarReminders", false),
        )
    } catch (e: Exception) {
        SyncSettings()
    }

    fun countdown(context: Context): Countdown? = try {
        val o = JSONObject(prefs(context).getString("countdown", null) ?: return null)
        val dates = o.getJSONArray("dates")
        Countdown(o.getString("title"), (0 until dates.length()).map { LocalDate.parse(dates.getString(it)) })
    } catch (e: Exception) {
        null
    }

    fun monthOffset(context: Context, widgetId: Int): Int = prefs(context).getInt("month_offset_$widgetId", 0)

    fun setMonthOffset(context: Context, widgetId: Int, offset: Int) {
        prefs(context).edit().putInt("month_offset_$widgetId", offset).apply()
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
        CountdownWidgetProvider.update(context, manager, ids(context, manager, CountdownWidgetProvider::class.java))
        scheduleMidnight(context)
        Reminders.reschedule(context)
    }

    private fun ids(context: Context, manager: AppWidgetManager, cls: Class<*>): IntArray =
        manager.getAppWidgetIds(ComponentName(context, cls))

    private fun hasWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return listOf(TodayWidgetProvider::class.java, MonthWidgetProvider::class.java, CountdownWidgetProvider::class.java)
            .any { ids(context, manager, it).isNotEmpty() }
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

/** Midnight alarm, boot, clock and time-zone changes: redraw every widget and reschedule reminders. */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Widgets.updateAll(context)
}
