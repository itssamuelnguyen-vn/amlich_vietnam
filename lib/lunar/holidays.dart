import '../data/settings.dart';
import 'lunar_calendar.dart';

const Map<(int, int), (String, HolidayKind)> _solarHolidays = {
  (1, 1): ('Tết Dương lịch', HolidayKind.vietnam),
  (14, 2): ('Lễ Tình nhân', HolidayKind.international),
  (8, 3): ('Quốc tế Phụ nữ', HolidayKind.international),
  (30, 4): ('Giải phóng miền Nam', HolidayKind.vietnam),
  (1, 5): ('Quốc tế Lao động', HolidayKind.vietnam),
  (1, 6): ('Quốc tế Thiếu nhi', HolidayKind.international),
  (2, 9): ('Quốc khánh', HolidayKind.vietnam),
  (20, 10): ('Phụ nữ Việt Nam', HolidayKind.vietnam),
  (20, 11): ('Nhà giáo Việt Nam', HolidayKind.vietnam),
  (22, 12): ('Quân đội Nhân dân', HolidayKind.vietnam),
  (24, 12): ('Giáng sinh', HolidayKind.international),
};

const Map<(int, int), String> _lunarHolidays = {
  (1, 1): 'Tết Nguyên đán',
  (2, 1): 'Mùng 2 Tết',
  (3, 1): 'Mùng 3 Tết',
  (15, 1): 'Rằm tháng Giêng',
  (10, 3): 'Giỗ Tổ Hùng Vương',
  (15, 4): 'Lễ Phật đản',
  (5, 5): 'Tết Đoan ngọ',
  (15, 7): 'Vu Lan',
  (15, 8): 'Tết Trung thu',
  (23, 12): 'Ông Công Ông Táo',
};

/// Vietnamese names of the holidays falling on [date] in the groups [kinds]; [lunar] must be `solarToLunar(date)`.
List<String> holidaysOf(DateTime date, LunarDate lunar, {Set<HolidayKind> kinds = const {...HolidayKind.values}}) {
  final solar = _solarHolidays[(date.day, date.month)];
  final traditional = kinds.contains(HolidayKind.lunar) && !lunar.isLeap;
  return [
    if (solar != null && kinds.contains(solar.$2)) solar.$1,
    if (traditional) ?_lunarHolidays[(lunar.day, lunar.month)],
    if (traditional && lunar.month == 12 && lunar.day == daysInLunarMonth(12, lunar.year)) 'Giao thừa',
  ];
}

class UpcomingHoliday {
  const UpcomingHoliday(this.date, this.name, this.daysLeft);

  final DateTime date;
  final String name;
  final int daysLeft;
}

/// The next [count] holidays on or after [from] (the 2nd and 3rd days of Tết left out).
List<UpcomingHoliday> upcomingHolidays(
  DateTime from, {
  int count = 5,
  Set<HolidayKind> kinds = const {...HolidayKind.values},
}) {
  final result = <UpcomingHoliday>[];
  for (var i = 0; i < 400 && result.length < count; i++) {
    final d = DateTime(from.year, from.month, from.day + i);
    for (final name in holidaysOf(d, solarToLunar(d), kinds: kinds)) {
      if (!name.startsWith('Mùng')) result.add(UpcomingHoliday(d, name, i));
    }
  }
  return result.take(count).toList();
}

/// Solar date of the next Tết Nguyên đán on or after [from].
DateTime nextTet(DateTime from) {
  final lunarYear = solarToLunar(from).year;
  final tet = lunarToSolar(LunarDate(1, 1, lunarYear))!;
  return tet.isBefore(from) ? lunarToSolar(LunarDate(1, 1, lunarYear + 1))! : tet;
}
