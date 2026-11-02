import 'lunar_calendar.dart';

const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const weekdayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
const lunarMonthNames = ['Giêng', 'Hai', 'Ba', 'Tư', 'Năm', 'Sáu', 'Bảy', 'Tám', 'Chín', 'Mười', 'Mười Một', 'Chạp'];

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Vietnamese name of a lunar month, e.g. "tháng Chín", "tháng Tư (nhuận)" for a leap month.
String lunarMonthName(LunarDate l) => 'tháng ${lunarMonthNames[l.month - 1]}${l.isLeap ? ' (nhuận)' : ''}';

String two(int n) => n.toString().padLeft(2, '0');
