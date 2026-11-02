import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';

/// Which calendar an event's date is written in.
enum EventCalendar { solar, lunar }

enum Repeat { none, monthly, yearly }

/// Colours an event can be tagged with; [Event.color] indexes this list.
const eventColors = [
  Color(0xFFE53935),
  Color(0xFFFB8C00),
  Color(0xFF43A047),
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
  Color(0xFF6D4C41),
];

/// A note on a date, optionally repeating every month or year of the solar or lunar calendar.
///
/// For a lunar event on day 30, months with only 29 days use their last day, as is customary for death anniversaries.
/// Yearly lunar events fall in the regular month only, never in a leap month of the same number.
class Event {
  const Event({
    this.id,
    required this.title,
    this.note = '',
    required this.calendar,
    required this.day,
    required this.month,
    required this.year,
    this.leap = false,
    this.repeat = Repeat.none,
    this.color = 0,
    this.remindDays = noReminder,
  });

  static const noReminder = -1;

  final int? id;
  final String title;
  final String note;
  final EventCalendar calendar;
  final int day;
  final int month;
  final int year;

  /// Lunar events only: the date is in the leap month.
  final bool leap;
  final Repeat repeat;
  final int color;

  /// Days before an occurrence to remind (0 = on the day), or [noReminder].
  final int remindDays;

  bool get isLunar => calendar == EventCalendar.lunar;

  Color get colorValue => eventColors[color.clamp(0, eventColors.length - 1)];

  /// Solar date of the first occurrence.
  DateTime get start {
    if (!isLunar) return DateTime(year, month, math.min(day, daysInMonth(year, month)));
    final length = daysInLunarMonth(month, year, isLeap: leap);
    // A leap month that does not exist (bad data) falls back to the regular month.
    if (length == 0) return lunarToSolar(LunarDate(math.min(day, daysInLunarMonth(month, year)), month, year))!;
    return lunarToSolar(LunarDate(math.min(day, length), month, year, isLeap: leap))!;
  }

  /// Whether the event falls on [date]; [lunar] must be `solarToLunar(date)`.
  bool occursOn(DateTime date, LunarDate lunar) {
    final first = start;
    if (date.isBefore(first)) return false;
    if (repeat == Repeat.none) return sameDay(date, first);
    if (!isLunar) {
      if (repeat == Repeat.yearly && date.month != month) return false;
      return date.day == math.min(day, daysInMonth(date.year, date.month));
    }
    if (repeat == Repeat.yearly && (lunar.month != month || lunar.isLeap)) return false;
    if (lunar.day == day) return true;
    return day == 30 && lunar.day == 29 && daysInLunarMonth(lunar.month, lunar.year, isLeap: lunar.isLeap) == 29;
  }

  /// The first occurrence on or after [from], or null when there is none (a past one-off event).
  DateTime? nextOccurrence(DateTime from) {
    final first = start;
    if (!first.isBefore(from)) return first;
    switch (repeat) {
      case Repeat.none:
        return null;
      case Repeat.yearly when !isLunar:
        for (var y = from.year; y <= from.year + 1; y++) {
          final d = DateTime(y, month, math.min(day, daysInMonth(y, month)));
          if (!d.isBefore(from)) return d;
        }
      case Repeat.yearly:
        final lunarYear = solarToLunar(from).year;
        for (var y = lunarYear - 1; y <= lunarYear + 1; y++) {
          final d = lunarToSolar(LunarDate(math.min(day, daysInLunarMonth(month, y)), month, y))!;
          if (!d.isBefore(from)) return d;
        }
      case Repeat.monthly when !isLunar:
        for (var m = 0; m <= 1; m++) {
          final ym = DateTime(from.year, from.month + m);
          final d = DateTime(ym.year, ym.month, math.min(day, daysInMonth(ym.year, ym.month)));
          if (!d.isBefore(from)) return d;
        }
      case Repeat.monthly:
        for (var i = 0; i < 62; i++) {
          final d = DateTime(from.year, from.month, from.day + i);
          if (occursOn(d, solarToLunar(d))) return d;
        }
    }
    return null;
  }

  /// Short description of the date rule, e.g. "Hằng năm · 10/3 âm lịch".
  String describe() {
    final date = isLunar ? '$day/$month${leap ? ' nhuận' : ''} âm lịch' : '${two(day)}/${two(month)}';
    return switch (repeat) {
      Repeat.none => isLunar ? '$day/$month${leap ? ' nhuận' : ''}/$year âm lịch' : '${two(day)}/${two(month)}/$year',
      Repeat.yearly => 'Hằng năm · $date',
      Repeat.monthly => 'Hằng tháng · ngày $day${isLunar ? ' âm lịch' : ''}',
    };
  }

  Event copyWith({
    int? id,
    String? title,
    String? note,
    EventCalendar? calendar,
    int? day,
    int? month,
    int? year,
    bool? leap,
    Repeat? repeat,
    int? color,
    int? remindDays,
  }) => Event(
    id: id ?? this.id,
    title: title ?? this.title,
    note: note ?? this.note,
    calendar: calendar ?? this.calendar,
    day: day ?? this.day,
    month: month ?? this.month,
    year: year ?? this.year,
    leap: leap ?? this.leap,
    repeat: repeat ?? this.repeat,
    color: color ?? this.color,
    remindDays: remindDays ?? this.remindDays,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'note': note,
    'calendar': calendar.name,
    'day': day,
    'month': month,
    'year': year,
    'leap': leap ? 1 : 0,
    'repeat': repeat.name,
    'color': color,
    'remind_days': remindDays,
  };

  factory Event.fromMap(Map<String, Object?> m) => Event(
    id: m['id'] as int?,
    title: m['title'] as String,
    note: (m['note'] as String?) ?? '',
    calendar: EventCalendar.values.byName(m['calendar'] as String),
    day: m['day'] as int,
    month: m['month'] as int,
    year: m['year'] as int,
    leap: m['leap'] == 1,
    repeat: Repeat.values.byName(m['repeat'] as String),
    color: (m['color'] as int?) ?? 0,
    remindDays: (m['remind_days'] as int?) ?? noReminder,
  );
}
