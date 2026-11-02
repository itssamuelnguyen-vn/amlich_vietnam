package com.samuelcruz.amlich_vietnam

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.time.DayOfWeek
import java.time.LocalDate

/** "Lịch tháng" widget: a 6-week grid with lunar days and event dots; ‹ › change month, tapping a day opens it. */
class MonthWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
        Widgets.scheduleMidnight(context)
    }

    override fun onDisabled(context: Context) = Widgets.scheduleMidnight(context)

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val delta = when (intent.action) {
            ACTION_PREV -> -1
            ACTION_NEXT -> 1
            ACTION_TODAY -> 0
            else -> return super.onReceive(context, intent)
        }
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        WidgetData.setMonthOffset(context, id, if (delta == 0) 0 else WidgetData.monthOffset(context, id) + delta)
        update(context, AppWidgetManager.getInstance(context), intArrayOf(id))
    }

    companion object {
        private const val ACTION_PREV = "com.samuelcruz.amlich_vietnam.MONTH_PREV"
        private const val ACTION_NEXT = "com.samuelcruz.amlich_vietnam.MONTH_NEXT"
        private const val ACTION_TODAY = "com.samuelcruz.amlich_vietnam.MONTH_TODAY"
        private const val RED = 0xFFD32F2F.toInt()

        fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            val occurrences = WidgetData.occurrences(context).groupBy({ it.date }, { it.color })
            for (id in ids) manager.updateAppWidget(id, build(context, id, occurrences))
        }

        private fun navIntent(context: Context, id: Int, action: String, code: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context, id * 10 + code,
                Intent(context, MonthWidgetProvider::class.java)
                    .setAction(action)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        private fun build(context: Context, id: Int, occurrences: Map<LocalDate, List<Int>>): RemoteViews {
            val today = Widgets.today()
            val offset = WidgetData.monthOffset(context, id)
            val month = today.withDayOfMonth(1).plusMonths(offset.toLong())
            val views = RemoteViews(context.packageName, R.layout.widget_month)

            views.setTextViewText(R.id.title, "Tháng ${month.monthValue}, ${month.year}")
            val first = LunarCalendar.solarToLunar(1, month.monthValue, month.year)
            val lastDay = month.plusMonths(1).minusDays(1)
            val last = LunarCalendar.solarToLunar(lastDay.dayOfMonth, lastDay.monthValue, lastDay.year)
            val range = if (first.month == last.month && first.leap == last.leap) {
                LunarCalendar.monthName(first)
            } else {
                "${LunarCalendar.monthName(first)} – ${LunarCalendar.monthName(last)}"
            }
            views.setTextViewText(
                R.id.subtitle,
                "${range.replaceFirstChar { it.uppercase() }} · ${LunarCalendar.canChiYear(last.year)}",
            )
            views.setOnClickPendingIntent(R.id.prev, navIntent(context, id, ACTION_PREV, 1))
            views.setOnClickPendingIntent(R.id.next, navIntent(context, id, ACTION_NEXT, 2))
            views.setOnClickPendingIntent(R.id.today, navIntent(context, id, ACTION_TODAY, 3))
            views.setOnClickPendingIntent(R.id.title_area, Widgets.openApp(context, month, id * 100))

            views.removeAllViews(R.id.grid)
            var day = month.minusDays((month.dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())
            for (week in 0 until 6) {
                val row = RemoteViews(context.packageName, R.layout.widget_month_row)
                for (d in 0 until 7) {
                    row.addView(R.id.row, cell(context, day, today, month, occurrences[day], id * 100 + week * 7 + d + 1))
                    day = day.plusDays(1)
                }
                views.addView(R.id.grid, row)
            }
            return views
        }

        private fun cell(
            context: Context,
            date: LocalDate,
            today: LocalDate,
            month: LocalDate,
            colors: List<Int>?,
            requestCode: Int,
        ): RemoteViews {
            val lunar = LunarCalendar.solarToLunar(date.dayOfMonth, date.monthValue, date.year)
            val holiday = LunarCalendar.holidays(date.dayOfMonth, date.monthValue, lunar).isNotEmpty()
            val layout = when {
                date == today -> R.layout.widget_cell_today
                date.monthValue != month.monthValue -> R.layout.widget_cell_other
                date.dayOfWeek == DayOfWeek.SUNDAY || holiday -> R.layout.widget_cell_red
                else -> R.layout.widget_cell
            }
            val cell = RemoteViews(context.packageName, layout)
            cell.setTextViewText(R.id.cell_solar, date.dayOfMonth.toString())
            cell.setTextViewText(
                R.id.cell_lunar,
                if (lunar.day == 1) "${lunar.day}/${lunar.month}${if (lunar.leap) "N" else ""}" else lunar.day.toString(),
            )
            if ((lunar.day == 1 || lunar.day == 15) && layout == R.layout.widget_cell) cell.setTextColor(R.id.cell_lunar, RED)
            // One dot per event (up to 3), each in its event colour.
            val dots = (colors.orEmpty() + if (holiday) listOf(RED) else emptyList()).take(3)
            if (dots.isEmpty()) {
                cell.setTextViewText(R.id.cell_dots, "")
            } else {
                val text = android.text.SpannableStringBuilder()
                for (c in dots) {
                    val start = text.length
                    text.append("●")
                    text.setSpan(android.text.style.ForegroundColorSpan(c), start, text.length, 0)
                }
                cell.setTextViewText(R.id.cell_dots, text)
            }
            cell.setOnClickPendingIntent(R.id.cell, Widgets.openApp(context, date, requestCode))
            return cell
        }
    }
}
