package com.samuelcruz.amlich_vietnam

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.time.temporal.ChronoUnit

/** "Đếm ngược" widget: days left to the next Tết, or to the event chosen in the app's settings. */
class CountdownWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
        Widgets.scheduleMidnight(context)
    }

    override fun onDisabled(context: Context) = Widgets.scheduleMidnight(context)

    companion object {
        fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            val views = build(context)
            for (id in ids) manager.updateAppWidget(id, views)
        }

        private fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_countdown)
            val today = Widgets.today()
            val countdown = WidgetData.countdown(context)
            val next = countdown?.dates?.firstOrNull { !it.isBefore(today) }
            views.setOnClickPendingIntent(R.id.root, Widgets.openApp(context, next, 3))
            if (countdown == null || next == null) {
                views.setTextViewText(R.id.days, "—")
                views.setTextViewText(R.id.unit, "")
                views.setTextViewText(R.id.title, countdown?.title ?: "Đếm ngược")
                views.setTextViewText(R.id.date, "Mở app để cập nhật")
                return views
            }
            val days = ChronoUnit.DAYS.between(today, next)
            views.setTextViewText(R.id.days, if (days == 0L) "🎉" else days.toString())
            views.setTextViewText(R.id.unit, if (days == 0L) "Hôm nay" else "ngày nữa")
            views.setTextViewText(R.id.title, countdown.title)
            views.setTextViewText(R.id.date, Reminders.formatDate(next))
            return views
        }
    }
}
