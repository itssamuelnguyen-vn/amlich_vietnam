package com.samuelcruz.amlich_vietnam

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/** A notification to show at [at]; tapping it opens the app on [date]. */
data class Reminder(val at: LocalDateTime, val title: String, val text: String, val date: LocalDate)

/**
 * Event, mùng 1 / rằm and day-counter milestone reminders, scheduled natively so they fire without the app running.
 *
 * Only the next [MAX] are scheduled; each one that fires schedules the following ones, and so do app syncs, the
 * midnight refresh and boot. Alarms are inexact (setAndAllowWhileIdle): no exact-alarm permission is needed and a few
 * minutes' delay does not matter for a day-ahead reminder.
 */
object Reminders {
    private const val ACTION_FIRE = "com.samuelcruz.amlich_vietnam.REMINDER"
    private const val CHANNEL = "reminders"
    private const val FIRST_CODE = 2000
    private const val MAX = 12

    /** Upcoming reminders after [now], soonest first (pure, for tests). */
    fun upcoming(
        occurrences: List<Occurrence>,
        settings: SyncSettings,
        now: LocalDateTime,
        milestones: List<MilestoneInfo> = emptyList(),
    ): List<Reminder> {
        val list = mutableListOf<Reminder>()
        for (m in milestones) {
            val at = m.date.atTime(settings.reminderHour, settings.reminderMinute)
            if (at.isAfter(now)) list += Reminder(at, m.text, formatDate(m.date), m.date)
        }
        for (o in occurrences) {
            if (o.remindDays < 0) continue
            val at = o.date.minusDays(o.remindDays.toLong()).atTime(settings.reminderHour, settings.reminderMinute)
            if (at.isAfter(now)) list += Reminder(at, o.title, describe(o.date, o.remindDays), o.date)
        }
        if (settings.lunarReminders) {
            // The day before each mùng 1 and rằm, over the next ~2 lunar months.
            for (i in 0..70L) {
                val date = now.toLocalDate().plusDays(i)
                val lunar = LunarCalendar.solarToLunar(date.dayOfMonth, date.monthValue, date.year)
                if (lunar.day != 1 && lunar.day != 15) continue
                val at = date.minusDays(1).atTime(settings.reminderHour, settings.reminderMinute)
                if (!at.isAfter(now)) continue
                val what = if (lunar.day == 1) "mùng 1" else "rằm"
                list += Reminder(at, "Mai là $what ${LunarCalendar.monthName(lunar)}", formatDate(date), date)
            }
        }
        return list.sortedBy { it.at }.take(MAX)
    }

    private fun describe(date: LocalDate, remindDays: Int): String {
        val whenText = when (remindDays) {
            0 -> "Hôm nay"
            1 -> "Ngày mai"
            else -> "Còn $remindDays ngày"
        }
        return "$whenText · ${formatDate(date)}"
    }

    /** "Thứ Ba, 03/11 (25/9 âm)". */
    fun formatDate(date: LocalDate): String {
        val lunar = LunarCalendar.solarToLunar(date.dayOfMonth, date.monthValue, date.year)
        val dd = date.dayOfMonth.toString().padStart(2, '0')
        val mm = date.monthValue.toString().padStart(2, '0')
        return "${LunarCalendar.WEEKDAYS[date.dayOfWeek.value - 1]}, $dd/$mm (${lunar.day}/${lunar.month} âm)"
    }

    private fun pending(context: Context, index: Int, reminder: Reminder?): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).setAction(ACTION_FIRE)
        if (reminder != null) {
            intent.putExtra("title", reminder.title).putExtra("text", reminder.text).putExtra("date", reminder.date.toString())
        }
        return PendingIntent.getBroadcast(
            context, FIRST_CODE + index, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    fun reschedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (i in 0 until MAX) alarms.cancel(pending(context, i, null))
        val reminders = upcoming(
            WidgetData.occurrences(context), WidgetData.settings(context), LocalDateTime.now(), WidgetData.milestones(context),
        )
        for ((i, r) in reminders.withIndex()) {
            val millis = r.at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, pending(context, i, r))
        }
    }

    fun show(context: Context, title: String, text: String, date: LocalDate?) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Nhắc sự kiện", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Nhắc ngày giỗ, sinh nhật, mùng 1 và rằm"
            },
        )
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_lich)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .setContentIntent(Widgets.openApp(context, date, (title + date).hashCode()))
            .build()
        manager.notify((title + date).hashCode(), notification)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: return
        val date = intent.getStringExtra("date")?.let { LocalDate.parse(it) }
        Reminders.show(context, title, intent.getStringExtra("text") ?: "", date)
        Reminders.reschedule(context)
    }
}
