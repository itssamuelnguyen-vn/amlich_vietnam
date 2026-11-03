package com.samuelcruz.amlich_vietnam

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.time.temporal.ChronoUnit

/** "Đếm ngày" widget: the day counter pinned in the app (e.g. "❤️ Bên nhau · 1.234 ngày"). */
class CounterWidgetProvider : AppWidgetProvider() {
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

        /** "1.234" with Vietnamese thousands separators. */
        private fun format(n: Long) = "%,d".format(n).replace(',', '.')

        private fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_counter)
            views.setOnClickPendingIntent(R.id.root, Widgets.openApp(context, null, 4))
            val c = WidgetData.counter(context)
            if (c == null) {
                views.setTextViewText(R.id.emoji, "❤️")
                views.setTextViewText(R.id.days, "—")
                views.setTextViewText(R.id.unit, "")
                views.setTextViewText(R.id.title, "Tạo bộ đếm trong Tiện ích")
                return views
            }
            val today = Widgets.today()
            val diff = ChronoUnit.DAYS.between(c.date, today)
            val future = diff < 0
            views.setInt(R.id.bg, "setColorFilter", c.color)
            views.setTextViewText(R.id.emoji, c.emoji)
            views.setTextViewText(R.id.days, format(if (future) -diff else diff + if (c.firstDayIsOne) 1 else 0))
            views.setTextViewText(R.id.unit, if (future) "ngày nữa" else "ngày")
            views.setTextViewText(R.id.title, c.title)
            return views
        }
    }
}
