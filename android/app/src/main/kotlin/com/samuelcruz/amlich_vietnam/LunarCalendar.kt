package com.samuelcruz.amlich_vietnam

import kotlin.math.PI
import kotlin.math.floor
import kotlin.math.sin

/** A lunar date; [monthLength] is 29 or 30. */
data class LunarDate(val day: Int, val month: Int, val year: Int, val leap: Boolean, val monthLength: Int)

/**
 * Kotlin port of lib/lunar/lunar_calendar.dart (Hồ Ngọc Đức's algorithm, UTC+7), so the home-screen widgets stay
 * correct without starting Flutter. Keep the two in sync; LunarCalendarTest checks this port against values from Dart.
 */
object LunarCalendar {
    private const val TIME_ZONE = 7.0

    val CAN = arrayOf("Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý")
    val CHI = arrayOf("Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi")
    val MONTH_NAMES = arrayOf(
        "Giêng", "Hai", "Ba", "Tư", "Năm", "Sáu", "Bảy", "Tám", "Chín", "Mười", "Mười Một", "Chạp",
    )
    val WEEKDAYS = arrayOf("Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật")
    private val DAY_STARS = arrayOf(
        "Thanh Long", "Minh Đường", "Thiên Hình", "Chu Tước", "Kim Quỹ", "Kim Đường",
        "Bạch Hổ", "Ngọc Đường", "Thiên Lao", "Huyền Vũ", "Tư Mệnh", "Câu Trần",
    )
    private val GOOD_STARS = setOf(0, 1, 4, 5, 7, 10)

    fun jdFromDate(dd: Int, mm: Int, yy: Int): Int {
        val a = (14 - mm) / 12
        val y = yy + 4800 - a
        val m = mm + 12 * a - 3
        var jd = dd + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        if (jd < 2299161) jd = dd + (153 * m + 2) / 5 + 365 * y + y / 4 - 32083
        return jd
    }

    private fun newMoon(k: Int): Double {
        val t = k / 1236.85
        val t2 = t * t
        val t3 = t2 * t
        val dr = PI / 180
        var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3
        jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr)
        val m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3
        val mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3
        val f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3
        var c1 = (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m)
        c1 = c1 - 0.4068 * sin(mpr * dr) + 0.0161 * sin(dr * 2 * mpr)
        c1 -= 0.0004 * sin(dr * 3 * mpr)
        c1 = c1 + 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (m + mpr))
        c1 = c1 - 0.0074 * sin(dr * (m - mpr)) + 0.0004 * sin(dr * (2 * f + m))
        c1 = c1 - 0.0004 * sin(dr * (2 * f - m)) - 0.0006 * sin(dr * (2 * f + mpr))
        c1 = c1 + 0.0010 * sin(dr * (2 * f - mpr)) + 0.0005 * sin(dr * (2 * mpr + m))
        val deltaT = if (t < -11) {
            0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
        } else {
            -0.000278 + 0.000265 * t + 0.000262 * t2
        }
        return jd1 + c1 - deltaT
    }

    private fun sunLongitude(jdn: Double): Double {
        val t = (jdn - 2451545.0) / 36525
        val t2 = t * t
        val dr = PI / 180
        val m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2
        val l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2
        var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m)
        dl = dl + (0.019993 - 0.000101 * t) * sin(dr * 2 * m) + 0.000290 * sin(dr * 3 * m)
        var l = (l0 + dl) * dr
        l -= PI * 2 * floor(l / (PI * 2))
        return l
    }

    private fun sunSegment(dayNumber: Int, segments: Int): Int =
        floor(sunLongitude(dayNumber - 0.5 - TIME_ZONE / 24) / PI * (segments / 2.0)).toInt()

    private fun newMoonDay(k: Int): Int = floor(newMoon(k) + 0.5 + TIME_ZONE / 24).toInt()

    private fun lunarMonth11(yy: Int): Int {
        val off = jdFromDate(31, 12, yy) - 2415021
        val k = floor(off / 29.530588853).toInt()
        var nm = newMoonDay(k)
        if (sunSegment(nm, 12) >= 9) nm = newMoonDay(k - 1)
        return nm
    }

    private fun leapMonthOffset(a11: Int): Int {
        val k = floor((a11 - 2415021.076998695) / 29.530588853 + 0.5).toInt()
        var i = 1
        var arc = sunSegment(newMoonDay(k + i), 12)
        var last: Int
        do {
            last = arc
            i++
            arc = sunSegment(newMoonDay(k + i), 12)
        } while (arc != last && i < 14)
        return i - 1
    }

    fun solarToLunar(dd: Int, mm: Int, yy: Int): LunarDate {
        val dayNumber = jdFromDate(dd, mm, yy)
        var k = floor((dayNumber - 2415021.076998695) / 29.530588853).toInt() + 1
        while (newMoonDay(k) > dayNumber) k--
        while (newMoonDay(k + 1) <= dayNumber) k++
        val monthStart = newMoonDay(k)
        val monthLength = newMoonDay(k + 1) - monthStart
        var a11 = lunarMonth11(yy)
        var b11 = a11
        var lunarYear: Int
        if (a11 >= monthStart) {
            lunarYear = yy
            a11 = lunarMonth11(yy - 1)
        } else {
            lunarYear = yy + 1
            b11 = lunarMonth11(yy + 1)
        }
        val lunarDay = dayNumber - monthStart + 1
        val diff = (monthStart - a11) / 29
        var leap = false
        var lunarMonth = diff + 11
        if (b11 - a11 > 365) {
            val leapDiff = leapMonthOffset(a11)
            if (diff >= leapDiff) {
                lunarMonth = diff + 10
                if (diff == leapDiff) leap = true
            }
        }
        if (lunarMonth > 12) lunarMonth -= 12
        if (lunarMonth >= 11 && diff < 4) lunarYear -= 1
        return LunarDate(lunarDay, lunarMonth, lunarYear, leap, monthLength)
    }

    fun canChiYear(lunarYear: Int) = "${CAN[(lunarYear + 6) % 10]} ${CHI[(lunarYear + 8) % 12]}"

    fun canChiMonth(lunarMonth: Int, lunarYear: Int) =
        "${CAN[(lunarYear * 12 + lunarMonth + 3) % 10]} ${CHI[(lunarMonth + 1) % 12]}"

    fun canChiDay(jd: Int) = "${CAN[(jd + 9) % 10]} ${CHI[(jd + 1) % 12]}"

    /** Name of the star ruling the day and whether it is auspicious (hoàng đạo), as dayStarOf in Dart. */
    fun dayStar(jd: Int, lunarMonth: Int): Pair<String, Boolean> {
        val start = (lunarMonth - 1) % 6 * 2
        val index = ((jd + 1) % 12 - start + 12) % 12
        return DAY_STARS[index] to (index in GOOD_STARS)
    }

    fun monthName(l: LunarDate) = "tháng ${MONTH_NAMES[l.month - 1]}${if (l.leap) " (nhuận)" else ""}"

    /** Holiday groups, named as HolidayKind in lib/data/settings.dart. */
    val ALL_KINDS = setOf("lunar", "vietnam", "international")

    private val SOLAR_HOLIDAYS = mapOf(
        (1 to 1) to ("Tết Dương lịch" to "vietnam"), (14 to 2) to ("Lễ Tình nhân" to "international"),
        (8 to 3) to ("Quốc tế Phụ nữ" to "international"), (30 to 4) to ("Giải phóng miền Nam" to "vietnam"),
        (1 to 5) to ("Quốc tế Lao động" to "vietnam"), (1 to 6) to ("Quốc tế Thiếu nhi" to "international"),
        (2 to 9) to ("Quốc khánh" to "vietnam"), (20 to 10) to ("Phụ nữ Việt Nam" to "vietnam"),
        (20 to 11) to ("Nhà giáo Việt Nam" to "vietnam"), (22 to 12) to ("Quân đội Nhân dân" to "vietnam"),
        (24 to 12) to ("Giáng sinh" to "international"),
    )
    private val LUNAR_HOLIDAYS = mapOf(
        (1 to 1) to "Tết Nguyên đán", (2 to 1) to "Mùng 2 Tết", (3 to 1) to "Mùng 3 Tết",
        (15 to 1) to "Rằm tháng Giêng", (10 to 3) to "Giỗ Tổ Hùng Vương", (15 to 4) to "Lễ Phật đản",
        (5 to 5) to "Tết Đoan ngọ", (15 to 7) to "Vu Lan", (15 to 8) to "Tết Trung thu",
        (23 to 12) to "Ông Công Ông Táo",
    )

    /** Holidays on a day in the groups [kinds], as holidaysOf in lib/lunar/holidays.dart. */
    fun holidays(dd: Int, mm: Int, lunar: LunarDate, kinds: Set<String> = ALL_KINDS): List<String> {
        val traditional = "lunar" in kinds && !lunar.leap
        return listOfNotNull(
            SOLAR_HOLIDAYS[dd to mm]?.takeIf { it.second in kinds }?.first,
            if (traditional) LUNAR_HOLIDAYS[lunar.day to lunar.month] else null,
            if (traditional && lunar.month == 12 && lunar.day == lunar.monthLength) "Giao thừa" else null,
        )
    }
}
