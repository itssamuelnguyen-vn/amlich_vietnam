import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../events/event_store.dart';
import '../lunar/format.dart';
import '../lunar/holidays.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';

/// Opens the year view; returns the month the user tapped (its first day), or null.
Future<DateTime?> openYearView(BuildContext context, int year) =>
    Navigator.of(context).push<DateTime>(MaterialPageRoute(builder: (_) => YearScreen(initialYear: year)));

/// Twelve small months of one year; swipe for the next or previous year.
class YearScreen extends StatefulWidget {
  const YearScreen({super.key, required this.initialYear});

  final int initialYear;

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  static const _base = 1000;
  late final _pages = PageController(initialPage: _base);
  late int _year = widget.initialYear;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _turn(int delta) => _pages.animateToPage(
    _pages.page!.round() + delta,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Năm $_year', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              // The lunar year that starts at this year's Tết.
              '${yearAnimal(_year)} ${canChiYear(_year)}',
              style: TextStyle(fontSize: 14, color: context.lich.goodDay, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Năm trước', onPressed: () => _turn(-1), icon: const Icon(Icons.chevron_left_rounded)),
          IconButton(tooltip: 'Năm sau', onPressed: () => _turn(1), icon: const Icon(Icons.chevron_right_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        onPageChanged: (p) => setState(() => _year = widget.initialYear + p - _base),
        itemBuilder: (context, page) => _YearGrid(year: widget.initialYear + page - _base),
      ),
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    Widget legend(Color color, String text, {bool filled = true}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: filled ? color : null,
            border: filled ? null : Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
          children: [
            for (var m = 1; m <= 12; m++)
              _MiniMonth(month: DateTime(year, m), onTap: () => Navigator.pop(context, DateTime(year, m))),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 4,
          children: [
            legend(lich.heroTop, 'Hôm nay'),
            legend(lich.holiday, 'Ngày lễ, Chủ nhật', filled: false),
            legend(scheme.primary.withValues(alpha: 0.25), 'Có sự kiện'),
          ],
        ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.month, required this.onTap});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final settings = SettingsScope.of(context).value;
    final events = EventScope.of(context);
    final now = today();
    final isCurrent = month.year == now.year && month.month == now.month;
    final first = startOfWeek(month, mondayFirst: settings.weekStartsMonday);
    final order = weekdayOrder(mondayFirst: settings.weekStartsMonday);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 7 * 15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tháng ${month.month}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isCurrent ? lich.holiday : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final wd in order)
                        SizedBox(
                          width: 15,
                          child: Text(
                            wd == DateTime.sunday ? 'C' : '${wd + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: wd == DateTime.sunday ? lich.holiday : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var w = 0; w < 6; w++)
                    Row(
                      children: [
                        for (var d = 0; d < 7; d++)
                          _cell(
                            context,
                            DateTime(first.year, first.month, first.day + w * 7 + d),
                            now,
                            settings,
                            events,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, DateTime date, DateTime now, Settings settings, EventStore events) {
    if (date.month != month.month) return const SizedBox(width: 15, height: 15);
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final lunar = solarToLunar(date);
    final red = date.weekday == DateTime.sunday || holidaysOf(date, lunar, kinds: settings.holidayKinds).isNotEmpty;
    final isToday = sameDay(date, now);
    final hasEvents = events.on(date, lunar).isNotEmpty;
    return Container(
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday ? lich.heroTop : (hasEvents ? scheme.primary.withValues(alpha: 0.25) : null),
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: red || isToday ? FontWeight.w800 : FontWeight.w500,
          color: isToday ? lich.onHero : (red ? lich.holiday : scheme.onSurface),
        ),
      ),
    );
  }
}
