import 'package:flutter/material.dart';

import '../lunar/format.dart';
import '../lunar/holidays.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import '../widgets/day_sections.dart';
import '../widgets/hero_card.dart';
import '../widgets/month_calendar.dart';
import '../widgets/pickers.dart';

/// Page index of the current month in the month PageView; pages to the left are earlier months.
const _basePage = 12 * 300;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  final _today = today();
  final _pages = PageController(initialPage: _basePage);
  late DateTime _selected = _today;
  late final List<UpcomingHoliday> _upcoming = upcomingHolidays(_today);
  int _page = _basePage;

  DateTime get selected => _selected;

  DateTime _monthOf(int page) => DateTime(_today.year, _today.month + page - _basePage);

  int _pageOf(DateTime d) => _basePage + (d.year - _today.year) * 12 + d.month - _today.month;

  /// Selects [day] and turns the month grid to it (used by the other tabs' "show on calendar").
  void showDate(DateTime day) => _select(day);

  void _select(DateTime day) {
    setState(() => _selected = day);
    final page = _pageOf(day);
    if (page == _page) return;
    if ((page - _page).abs() > 1) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  /// Swiping to another month keeps the selection inside it: today in the current month, else the same day number.
  void _onPageChanged(int page) {
    final month = _monthOf(page);
    setState(() {
      _page = page;
      if (_selected.year != month.year || _selected.month != month.month) {
        _selected = page == _basePage
            ? _today
            : DateTime(month.year, month.month, _selected.day.clamp(1, daysInMonth(month.year, month.month)));
      }
    });
  }

  Future<void> _pickMonth() async {
    final month = await showMonthPicker(context, _monthOf(_page));
    if (month == null) return;
    _select(month.year == _today.year && month.month == _today.month ? _today : month);
  }

  Future<void> _convert() async {
    final date = await showLunarConverter(context, _selected);
    if (date != null) _select(date);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lunarToday = solarToLunar(_today);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 68,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 20,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lịch Vạn Niên', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    'Năm ${canChiYear(lunarToday.year)} ${yearAnimal(lunarToday.year)}',
                    style: TextStyle(color: context.lich.goodDay, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              actions: [
                IconButton.filledTonal(
                  tooltip: 'Đổi ngày âm sang dương',
                  onPressed: _convert,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Về hôm nay',
                  onPressed: sameDay(_selected, _today) ? null : () => _select(_today),
                  icon: const Icon(Icons.today_rounded),
                ),
                const SizedBox(width: 12),
              ],
            ),
            SliverPadding(
              // Bottom room so the add button never covers the last card.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList.list(
                children: [
                  HeroCard(
                    date: _selected,
                    isToday: sameDay(_selected, _today),
                    onPrev: () => _select(DateTime(_selected.year, _selected.month, _selected.day - 1)),
                    onNext: () => _select(DateTime(_selected.year, _selected.month, _selected.day + 1)),
                  ),
                  const SizedBox(height: 16),
                  MonthCalendar(
                    controller: _pages,
                    monthOf: _monthOf,
                    visibleMonth: _monthOf(_page),
                    selected: _selected,
                    today: _today,
                    onSelect: _select,
                    onPageChanged: _onPageChanged,
                    onPickMonth: _pickMonth,
                  ),
                  const SizedBox(height: 16),
                  DayEventsCard(date: _selected),
                  const SizedBox(height: 16),
                  LuckyHoursCard(date: _selected),
                  const SizedBox(height: 16),
                  UpcomingCard(items: _upcoming, onTap: _select),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
