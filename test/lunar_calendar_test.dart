import 'package:amlich_vietnam/lunar/lunar_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tết (1st day of the 1st lunar month)', () {
    final tet = {
      1985: DateTime(1985, 1, 21), // Vietnam differs from China (20/02) this year
      2007: DateTime(2007, 2, 17), // and this one (China: 18/02)
      2014: DateTime(2014, 1, 31),
      2017: DateTime(2017, 1, 28),
      2018: DateTime(2018, 2, 16),
      2019: DateTime(2019, 2, 5),
      2020: DateTime(2020, 1, 25),
      2021: DateTime(2021, 2, 12),
      2022: DateTime(2022, 2, 1),
      2023: DateTime(2023, 1, 22),
      2024: DateTime(2024, 2, 10),
      2025: DateTime(2025, 1, 29),
      2026: DateTime(2026, 2, 17),
    };
    tet.forEach((year, date) {
      test('$year', () {
        expect(solarToLunar(date), LunarDate(1, 1, year));
        expect(lunarToSolar(LunarDate(1, 1, year)), date);
        expect(solarToLunar(date.subtract(const Duration(days: 1))).year, year - 1);
      });
    });
  });

  test('leap months', () {
    expect(leapMonthOf(2014), 9);
    expect(leapMonthOf(2017), 6);
    expect(leapMonthOf(2020), 4);
    expect(leapMonthOf(2023), 2);
    expect(leapMonthOf(2025), 6);
    expect(leapMonthOf(2024), isNull);
    expect(leapMonthOf(2026), isNull);
  });

  test('days in a leap month are marked leap', () {
    // 2023: the regular 2nd month starts 20/02, the leap 2nd month starts 22/03.
    expect(solarToLunar(DateTime(2023, 3, 21)), const LunarDate(30, 2, 2023));
    expect(solarToLunar(DateTime(2023, 3, 22)), const LunarDate(1, 2, 2023, isLeap: true));
    expect(lunarToSolar(const LunarDate(1, 2, 2023, isLeap: true)), DateTime(2023, 3, 22));
    expect(lunarToSolar(const LunarDate(1, 3, 2023, isLeap: true)), isNull);
  });

  test('Trung thu 2024 and invalid days', () {
    expect(lunarToSolar(const LunarDate(15, 8, 2024)), DateTime(2024, 9, 17));
    final len = daysInLunarMonth(12, 2024);
    expect(len, anyOf(29, 30));
    expect(lunarToSolar(LunarDate(len + 1, 12, 2024)), isNull);
  });

  test('round trip every day 1900–2100', () {
    for (var d = DateTime(1900, 1, 1); d.year <= 2100; d = DateTime(d.year, d.month, d.day + 1)) {
      final l = solarToLunar(d);
      expect(lunarToSolar(l), d, reason: '$d -> $l');
    }
  });

  test('can chi', () {
    expect(canChiYear(2024), 'Giáp Thìn');
    expect(canChiYear(2025), 'Ất Tỵ');
    expect(canChiYear(2026), 'Bính Ngọ');
    expect(canChiDay(DateTime(2024, 2, 10)), 'Giáp Thìn');
    expect(canChiMonth(1, 2024), 'Bính Dần'); // tháng Giêng năm Giáp is always Bính Dần
    expect(canChiMonth(1, 2025), 'Mậu Dần'); // năm Ất -> Mậu Dần
  });

  test('solar terms and auspicious hours', () {
    expect(tietKhiOf(DateTime(2024, 12, 21)), 'Đông chí');
    expect(tietKhiOf(DateTime(2024, 6, 21)), 'Hạ chí');
    final hours = gioHoangDao(DateTime(2024, 2, 10));
    expect(hours, hasLength(6));
    // A Dragon (Thìn) day: Dần, Thìn, Tỵ, Thân, Dậu, Hợi
    expect(hours.map((h) => h.branch), ['Dần', 'Thìn', 'Tỵ', 'Thân', 'Dậu', 'Hợi']);
  });
}
