package com.samuelcruz.amlich_vietnam

import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.provider.CalendarContract.Calendars
import android.provider.CalendarContract.Events
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneOffset

/** One all-day event occurrence to mirror into the phone's calendar; [key] is "<app event id>|<yyyy-MM-dd>". */
data class SyncItem(val key: String, val title: String, val date: LocalDate, val description: String) {
    val hash: Int get() = listOf(title, date.toString(), description).hashCode()
}

/** A row we wrote earlier: its calendar event id and the [SyncItem.hash] it was written with. */
data class SyncedRow(val eventId: Long, val hash: Int)

/** What to change in the calendar to match the app (see [GoogleCalendarSync.plan]). */
data class SyncPlan(
    val insert: List<SyncItem>,
    val update: List<Pair<Long, SyncItem>>,
    val delete: List<Long>,
    /** Keys no longer tracked: past occurrences kept in the calendar as history, or rows already gone. */
    val forget: List<String>,
)

/**
 * Mirrors app events into a calendar of the phone (normally the user's Google calendar) through CalendarContract,
 * so Android's own Google sync uploads them; no OAuth or Google Cloud project is needed.
 *
 * One-way (app → calendar). Lunar recurrences cannot be written as RRULEs, so every occurrence in the coming two years
 * is its own all-day event. Rows written earlier are remembered with a content hash so a sync only touches what
 * changed; past occurrences stay in the calendar as history.
 */
object GoogleCalendarSync {
    private const val PREFS = "amlich_google_sync"

    data class CalendarInfo(val id: Long, val name: String, val account: String, val color: Int, val isGoogle: Boolean)

    fun calendars(context: Context): List<CalendarInfo> {
        val projection = arrayOf(
            Calendars._ID, Calendars.CALENDAR_DISPLAY_NAME, Calendars.ACCOUNT_NAME, Calendars.CALENDAR_COLOR,
            Calendars.ACCOUNT_TYPE,
        )
        val list = mutableListOf<CalendarInfo>()
        context.contentResolver.query(
            Calendars.CONTENT_URI, projection,
            "${Calendars.CALENDAR_ACCESS_LEVEL} >= ? AND ${Calendars.VISIBLE} = 1",
            arrayOf(Calendars.CAL_ACCESS_CONTRIBUTOR.toString()), null,
        )?.use { c ->
            while (c.moveToNext()) {
                list += CalendarInfo(
                    c.getLong(0), c.getString(1) ?: "", c.getString(2) ?: "", c.getInt(3), c.getString(4) == "com.google",
                )
            }
        }
        return list.sortedWith(compareByDescending<CalendarInfo> { it.isGoogle }.thenBy { it.account }.thenBy { it.name })
    }

    /** Pure diff between what was written ([state]), what still exists ([existing]) and what should exist. */
    fun plan(state: Map<String, SyncedRow>, existing: Set<Long>, desired: List<SyncItem>, today: LocalDate): SyncPlan {
        val wanted = desired.associateBy { it.key }
        val insert = mutableListOf<SyncItem>()
        val update = mutableListOf<Pair<Long, SyncItem>>()
        val delete = mutableListOf<Long>()
        val forget = mutableListOf<String>()
        for ((key, row) in state) {
            if (key in wanted) continue
            val date = LocalDate.parse(key.substringAfter('|'))
            // Past occurrences stay as history; rows the user already deleted need no work.
            if (date.isBefore(today) || row.eventId !in existing) forget += key else delete += row.eventId
        }
        for (item in desired) {
            val row = state[item.key]
            when {
                row == null || row.eventId !in existing -> insert += item // new, or deleted by the user in the calendar
                row.hash != item.hash -> update += row.eventId to item
            }
        }
        return SyncPlan(insert, update, delete, forget)
    }

    /** Brings [calendarId] in line with [items]; returns (added, changed, removed). */
    fun sync(context: Context, calendarId: Long, items: List<SyncItem>): Triple<Int, Int, Int> {
        var (stateCalendar, state) = load(context)
        if (stateCalendar != calendarId) {
            // Moved to another calendar: take our rows out of the old one first.
            deleteRows(context, state.values.map { it.eventId })
            state = emptyMap()
        }
        val existing = existingIds(context, state.values.map { it.eventId })
        val p = plan(state, existing, items, Widgets.today())

        val ops = ArrayList<ContentProviderOperation>()
        for (id in p.delete) ops += ContentProviderOperation.newDelete(eventUri(id)).build()
        for ((id, item) in p.update) ops += ContentProviderOperation.newUpdate(eventUri(id)).withValues(values(calendarId, item)).build()
        val insertStart = ops.size
        for (item in p.insert) ops += ContentProviderOperation.newInsert(Events.CONTENT_URI).withValues(values(calendarId, item)).build()
        val results = if (ops.isEmpty()) emptyArray() else context.contentResolver.applyBatch(Events.CONTENT_URI.authority!!, ops)

        val next = state.toMutableMap()
        p.forget.forEach { next.remove(it) }
        val deleted = p.delete.toSet()
        next.entries.removeAll { it.value.eventId in deleted }
        for ((id, item) in p.update) next[item.key] = SyncedRow(id, item.hash)
        p.insert.forEachIndexed { i, item ->
            results[insertStart + i].uri?.let { next[item.key] = SyncedRow(ContentUris.parseId(it), item.hash) }
        }
        save(context, calendarId, next)
        return Triple(p.insert.size, p.update.size, p.delete.size)
    }

    /** Removes every event this app wrote (including past ones it still tracks) and forgets the calendar. */
    fun clear(context: Context): Int {
        val (_, state) = load(context)
        deleteRows(context, state.values.map { it.eventId })
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        return state.size
    }

    private fun eventUri(id: Long) = ContentUris.withAppendedId(Events.CONTENT_URI, id)

    private fun values(calendarId: Long, item: SyncItem) = ContentValues().apply {
        // All-day events are stored at UTC midnight.
        val start = item.date.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli()
        put(Events.CALENDAR_ID, calendarId)
        put(Events.TITLE, item.title)
        put(Events.DESCRIPTION, item.description)
        put(Events.DTSTART, start)
        put(Events.DTEND, start + 24 * 60 * 60 * 1000L)
        put(Events.ALL_DAY, 1)
        put(Events.EVENT_TIMEZONE, "UTC")
        put(Events.AVAILABILITY, Events.AVAILABILITY_FREE)
    }

    private fun existingIds(context: Context, ids: List<Long>): Set<Long> {
        val found = mutableSetOf<Long>()
        for (chunk in ids.chunked(500)) {
            context.contentResolver.query(
                Events.CONTENT_URI, arrayOf(Events._ID),
                "${Events._ID} IN (${chunk.joinToString(",")}) AND ${Events.DELETED} = 0", null, null,
            )?.use { c -> while (c.moveToNext()) found += c.getLong(0) }
        }
        return found
    }

    private fun deleteRows(context: Context, ids: List<Long>) {
        if (ids.isEmpty()) return
        val ops = ArrayList(ids.map { ContentProviderOperation.newDelete(eventUri(it)).build() })
        try {
            context.contentResolver.applyBatch(Events.CONTENT_URI.authority!!, ops)
        } catch (e: Exception) {
            // Rows the user already removed make no difference.
        }
    }

    private fun load(context: Context): Pair<Long, Map<String, SyncedRow>> {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("state", null)
            ?: return -1L to emptyMap()
        return try {
            val o = JSONObject(json)
            val rows = o.getJSONObject("rows")
            o.getLong("calendar") to rows.keys().asSequence().associateWith {
                val r = rows.getJSONObject(it)
                SyncedRow(r.getLong("id"), r.getInt("hash"))
            }
        } catch (e: Exception) {
            -1L to emptyMap()
        }
    }

    private fun save(context: Context, calendarId: Long, rows: Map<String, SyncedRow>) {
        val o = JSONObject().put("calendar", calendarId)
        val r = JSONObject()
        for ((key, row) in rows) r.put(key, JSONObject().put("id", row.eventId).put("hash", row.hash))
        o.put("rows", r)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("state", o.toString()).apply()
    }
}
