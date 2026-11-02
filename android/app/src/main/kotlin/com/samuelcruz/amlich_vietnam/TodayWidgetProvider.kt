package com.samuelcruz.amlich_vietnam

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.time.temporal.ChronoUnit

/** "Hôm nay" widget: today's solar and lunar date, stem-branch, day star, and the next holiday or event. */
class TodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
        Widgets.scheduleMidnight(context)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        update(context, manager, intArrayOf(id))

    override fun onDisabled(context: Context) = Widgets.scheduleMidnight(context)

    companion object {
        fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            for (id in ids) manager.updateAppWidget(id, build(context, manager.getAppWidgetOptions(id)))
        }

        private fun build(context: Context, options: Bundle): RemoteViews {
            val small = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250) < 200
            val views = RemoteViews(context.packageName, if (small) R.layout.widget_today_small else R.layout.widget_today)
            val date = Widgets.today()
            val lunar = LunarCalendar.solarToLunar(date.dayOfMonth, date.monthValue, date.year)
            val jd = LunarCalendar.jdFromDate(date.dayOfMonth, date.monthValue, date.year)

            views.setTextViewText(R.id.day, date.dayOfMonth.toString())
            views.setTextViewText(R.id.weekday, LunarCalendar.WEEKDAYS[date.dayOfWeek.value - 1])
            views.setOnClickPendingIntent(R.id.root, Widgets.openApp(context, null, 1))
            if (small) {
                views.setTextViewText(R.id.lunar, "${lunar.day}/${lunar.month}${if (lunar.leap) "N" else ""} âm")
                return views
            }

            views.setTextViewText(R.id.month_year, "THÁNG ${date.monthValue} · ${date.year}")
            views.setTextViewText(R.id.lunar, "${lunar.day} ${LunarCalendar.monthName(lunar)}")
            views.setTextViewText(
                R.id.canchi,
                "Ngày ${LunarCalendar.canChiDay(jd)} · Năm ${LunarCalendar.canChiYear(lunar.year)}",
            )
            val (star, good) = LunarCalendar.dayStar(jd, lunar.month)
            views.setTextViewText(R.id.star, "${if (good) "✦ Hoàng đạo" else "Hắc đạo"} · $star")

            val kinds = WidgetData.settings(context).holidayKinds
            val holiday = LunarCalendar.holidays(date.dayOfMonth, date.monthValue, lunar, kinds).firstOrNull()
            val next = WidgetData.occurrences(context).firstOrNull { !it.date.isBefore(date) }
            val line = when {
                holiday != null -> "🎉 $holiday"
                next != null -> {
                    val days = ChronoUnit.DAYS.between(date, next.date)
                    "● ${next.title} · ${if (days == 0L) "hôm nay" else "còn $days ngày"}"
                }
                else -> null
            }
            if (line == null) {
                views.setViewVisibility(R.id.next, View.GONE)
            } else {
                views.setViewVisibility(R.id.next, View.VISIBLE)
                views.setTextViewText(R.id.next, line)
            }
            return views
        }
    }
}
