import 'lunar_calendar.dart';

const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Weekday columns in display order: Monday-first (Vietnamese default) or Sunday-first. Values are DateTime.weekday.
List<int> weekdayOrder({required bool mondayFirst}) =>
    mondayFirst ? const [1, 2, 3, 4, 5, 6, 7] : const [7, 1, 2, 3, 4, 5, 6];

/// The first day of the week containing [date].
DateTime startOfWeek(DateTime date, {required bool mondayFirst}) =>
    DateTime(date.year, date.month, date.day - (mondayFirst ? date.weekday - 1 : date.weekday % 7));
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

/// Whole days from [a] to [b] (negative when [b] is earlier), ignoring time of day and DST.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Calendar difference from [a] to [b] (a ≤ b) as years, months and days, e.g. 15/01 → 10/03 is 1 month 23 days.
({int years, int months, int days}) ymdBetween(DateTime a, DateTime b) {
  var years = b.year - a.year;
  var months = b.month - a.month;
  var days = b.day - a.day;
  if (days < 0) {
    months--;
    days += daysInMonth(b.year, b.month - 1);
  }
  if (months < 0) {
    years--;
    months += 12;
  }
  return (years: years, months: months, days: days);
}
