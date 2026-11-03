package com.samuelcruz.amlich_vietnam

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import java.time.temporal.ChronoUnit

/** "Lịch dải" 4×1 widget: solar day, weekday, lunar date, stem-branch and day star on one line. */
class StripWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
        Widgets.scheduleMidnight(context)
    }

    override fun onDisabled(context: Context) = Widgets.scheduleMidnight(context)

    companion object {
        fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            val date = Widgets.today()
            val lunar = LunarCalendar.solarToLunar(date.dayOfMonth, date.monthValue, date.year)
            val jd = LunarCalendar.jdFromDate(date.dayOfMonth, date.monthValue, date.year)
            val (star, good) = LunarCalendar.dayStar(jd, lunar.month)
            val views = RemoteViews(context.packageName, R.layout.widget_strip)
            views.setTextViewText(R.id.day, date.dayOfMonth.toString())
            views.setTextViewText(
                R.id.line1,
                "${LunarCalendar.WEEKDAYS[date.dayOfWeek.value - 1]} · tháng ${date.monthValue}/${date.year}",
            )
            views.setTextViewText(
                R.id.line2,
                "${lunar.day}/${lunar.month}${if (lunar.leap) " nhuận" else ""} âm · ngày ${LunarCalendar.canChiDay(jd)} · " +
                    (if (good) "✦ $star" else star),
            )
            views.setOnClickPendingIntent(R.id.root, Widgets.openApp(context, null, 5))
            for (id in ids) manager.updateAppWidget(id, views)
        }
    }
}

/** "Sắp tới" 4×2 widget: the next four event occurrences with their countdown. */
class UpcomingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
        Widgets.scheduleMidnight(context)
    }

    override fun onDisabled(context: Context) = Widgets.scheduleMidnight(context)

    companion object {
        private val ROWS = intArrayOf(R.id.row1, R.id.row2, R.id.row3, R.id.row4)

        fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            val today = Widgets.today()
            val next = WidgetData.occurrences(context).filter { !it.date.isBefore(today) }.take(ROWS.size)
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming)
            views.setViewVisibility(R.id.empty, if (next.isEmpty()) View.VISIBLE else View.GONE)
            for ((i, row) in ROWS.withIndex()) {
                val o = next.getOrNull(i)
                if (o == null) {
                    views.setViewVisibility(row, View.GONE)
                    continue
                }
                val days = ChronoUnit.DAYS.between(today, o.date)
                val dd = o.date.dayOfMonth.toString().padStart(2, '0')
                val mm = o.date.monthValue.toString().padStart(2, '0')
                val text = android.text.SpannableStringBuilder()
                text.append("● ")
                text.setSpan(android.text.style.ForegroundColorSpan(o.color), 0, 1, 0)
                text.append("$dd/$mm  ${o.title}  ·  ${if (days == 0L) "hôm nay" else "còn $days ngày"}")
                views.setViewVisibility(row, View.VISIBLE)
                views.setTextViewText(row, text)
                views.setOnClickPendingIntent(row, Widgets.openApp(context, o.date, 600 + i))
            }
            views.setOnClickPendingIntent(R.id.root, Widgets.openApp(context, null, 6))
            for (id in ids) manager.updateAppWidget(id, views)
        }
    }
}
