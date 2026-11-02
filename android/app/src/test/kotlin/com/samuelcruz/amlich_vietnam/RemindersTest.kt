package com.samuelcruz.amlich_vietnam

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

class RemindersTest {
    private val now = LocalDateTime.of(2026, 11, 2, 9, 0)

    @Test
    fun eventRemindersUseRemindDaysAndTime() {
        val occurrences = listOf(
            Occurrence("Họp lớp", LocalDate.of(2026, 11, 20), 0, 1),
            Occurrence("Không nhắc", LocalDate.of(2026, 11, 10), 0, -1),
            Occurrence("Đã qua", LocalDate.of(2026, 11, 2), 0, 0), // 07:00 today is already past
            Occurrence("Giỗ", LocalDate.of(2026, 11, 3), 0, 0),
        )
        val list = Reminders.upcoming(occurrences, SyncSettings(reminderHour = 7, reminderMinute = 30), now)
        assertEquals(listOf("Giỗ", "Họp lớp"), list.map { it.title })
        assertEquals(LocalDateTime.of(2026, 11, 3, 7, 30), list[0].at)
        assertEquals("Hôm nay · Thứ Ba, 03/11 (25/9 âm)", list[0].text)
        assertEquals(LocalDateTime.of(2026, 11, 19, 7, 30), list[1].at)
        assertEquals("Ngày mai · Thứ Sáu, 20/11 (12/10 âm)", list[1].text)
    }

    @Test
    fun lunarRemindersComeTheDayBefore() {
        val list = Reminders.upcoming(emptyList(), SyncSettings(lunarReminders = true), now)
        // 09/11/2026 is mùng 1 tháng Mười, 23/11/2026 is rằm tháng Mười.
        assertEquals("Mai là mùng 1 tháng Mười", list[0].title)
        assertEquals(LocalDateTime.of(2026, 11, 8, 7, 0), list[0].at)
        assertEquals("Mai là rằm tháng Mười", list[1].title)
        assertEquals(LocalDate.of(2026, 11, 23), list[1].date)
    }
}
