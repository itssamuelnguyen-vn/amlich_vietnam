import 'package:flutter/material.dart';

import '../lunar/format.dart';
import '../lunar/holidays.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';

const _rowHeight = 56.0;

/// Month grid card: a header naming the solar and lunar months, then a swipeable 6-week grid.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.controller,
    required this.monthOf,
    required this.visibleMonth,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.onPageChanged,
    required this.onPickMonth,
  });

  final PageController controller;
  final DateTime Function(int page) monthOf;
  final DateTime visibleMonth;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPickMonth;

  void _turn(int delta) => controller.animateToPage(
    controller.page!.round() + delta,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(onPressed: () => _turn(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onPickMonth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Tháng ${visibleMonth.month}, ${visibleMonth.year}',
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurfaceVariant),
                            ],
                          ),
                          Text(
                            _lunarSubtitle(visibleMonth),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(onPressed: () => _turn(1), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      weekdayShort[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 6 ? context.lich.holiday : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6 * _rowHeight,
              child: PageView.builder(
                controller: controller,
                onPageChanged: onPageChanged,
                itemBuilder: (context, page) =>
                    _MonthGrid(month: monthOf(page), selected: selected, today: today, onTap: onSelect),
              ),
            ),
            const SizedBox(height: 6),
            const _Legend(),
          ],
        ),
      ),
    );
  }

  /// The lunar months and year the solar [month] spans, e.g. "Tháng Chín – tháng Mười âm lịch · Bính Ngọ".
  static String _lunarSubtitle(DateTime month) {
    final first = solarToLunar(month);
    final last = solarToLunar(DateTime(month.year, month.month, daysInMonth(month.year, month.month)));
    final firstName = lunarMonthName(first);
    final range = first.month == last.month && first.isLeap == last.isLeap
        ? firstName
        : '$firstName – ${lunarMonthName(last)}';
    final years = first.year == last.year
        ? canChiYear(last.year)
        : '${canChiYear(first.year)} – ${canChiYear(last.year)}';
    return '${range[0].toUpperCase()}${range.substring(1)} âm lịch · $years';
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget item(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(t, style: style),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [item(context.lich.goodDay, 'Ngày hoàng đạo'), item(context.lich.holiday, 'Ngày lễ')],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selected, required this.today, required this.onTap});

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    // Starts on the Monday on or before the 1st and always shows 6 weeks.
    final first = DateTime(month.year, month.month, 1 - (DateTime(month.year, month.month).weekday - 1));
    return Column(
      children: [
        for (var w = 0; w < 6; w++)
          Expanded(
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(child: _cell(DateTime(first.year, first.month, first.day + w * 7 + d))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(DateTime date) => _DayCell(
    date: date,
    inMonth: date.month == month.month,
    isToday: sameDay(date, today),
    isSelected: sameDay(date, selected),
    onTap: onTap,
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final lunar = solarToLunar(date);
    final holiday = holidaysOf(date, lunar).isNotEmpty;
    final good = dayStarOf(date, lunar).isGood;
    final special = lunar.day == 1 || lunar.day == 15;

    var solarColor = date.weekday == DateTime.sunday || holiday ? lich.holiday : scheme.onSurface;
    var lunarColor = special ? lich.holiday : scheme.onSurfaceVariant;
    if (isSelected) {
      solarColor = lich.onHero;
      lunarColor = lich.onHero.withValues(alpha: 0.85);
    }
    final opacity = inMonth || isSelected ? 1.0 : 0.3;

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Opacity(
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [lich.heroTop, lich.heroBottom],
                  )
                : null,
            color: isSelected ? null : (isToday ? scheme.primary.withValues(alpha: 0.12) : null),
            border: isToday && !isSelected ? Border.all(color: scheme.primary, width: 1.5) : null,
            boxShadow: isSelected
                ? [BoxShadow(color: lich.heroBottom.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onTap(date),
              child: Stack(
                children: [
                  if (good)
                    Positioned(
                      top: 5,
                      right: 6,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: isSelected ? lich.gold : lich.goodDay, shape: BoxShape.circle),
                      ),
                    ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: solarColor, height: 1.1),
                          ),
                          Text(
                            lunar.day == 1 ? '1/${lunar.month}${lunar.isLeap ? 'N' : ''}' : '${lunar.day}',
                            style: TextStyle(
                              fontSize: 11,
                              color: lunarColor,
                              fontWeight: special ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: holiday ? (isSelected ? lich.gold : lich.holiday) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
