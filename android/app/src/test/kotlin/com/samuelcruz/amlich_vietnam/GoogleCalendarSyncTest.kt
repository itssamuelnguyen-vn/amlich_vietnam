package com.samuelcruz.amlich_vietnam

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class GoogleCalendarSyncTest {
    private val today = LocalDate.of(2026, 11, 3)

    private fun item(key: String, title: String = "Giỗ") =
        SyncItem(key, title, LocalDate.parse(key.substringAfter('|')), "mô tả")

    @Test
    fun plansOnlyTheChanges() {
        val same = item("1|2026-12-01")
        val changed = item("2|2026-12-05", title = "Họp lớp (đổi giờ)")
        val state = mapOf(
            same.key to SyncedRow(10, same.hash),
            "2|2026-12-05" to SyncedRow(11, item("2|2026-12-05").hash),
            "3|2026-12-09" to SyncedRow(12, 0), // event deleted in the app
            "3|2026-10-09" to SyncedRow(13, 0), // past occurrence: kept as history
            "4|2026-12-20" to SyncedRow(14, 0), // already deleted by the user in the calendar
        )
        val fresh = item("5|2027-01-01")
        val readded = item("6|2027-02-02")
        val plan = GoogleCalendarSync.plan(
            state + (readded.key to SyncedRow(15, readded.hash)),
            existing = setOf(10, 11, 12, 13),
            desired = listOf(same, changed, fresh, readded),
            today = today,
        )
        assertEquals(listOf(fresh, readded), plan.insert) // row 15 was removed by the user, so it is written again
        assertEquals(listOf(11L to changed), plan.update)
        assertEquals(listOf(12L), plan.delete)
        assertEquals(setOf("3|2026-10-09", "4|2026-12-20"), plan.forget.toSet())
    }
}
