import 'package:flutter/material.dart';

import '../events/event_store.dart';
import '../lunar/format.dart';
import '../screens/event_editor.dart';
import '../screens/events_screen.dart';
import '../lunar/holidays.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';

/// A titled card section.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.icon, required this.title, this.trailing, required this.child});

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// The six auspicious hours (giờ hoàng đạo) of [date], the current one highlighted when [date] is today.
class LuckyHoursCard extends StatelessWidget {
  const LuckyHoursCard({super.key, required this.date});

  final DateTime date;

  bool _isNow(LuckyHour h) {
    final now = DateTime.now();
    if (!sameDay(date, now)) return false;
    // The Rat hour (giờ Tý) spans midnight (23h–1h).
    return h.startHour < h.endHour
        ? now.hour >= h.startHour && now.hour < h.endHour
        : now.hour >= h.startHour || now.hour < h.endHour;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final hours = gioHoangDao(date);
    return SectionCard(
      icon: Icons.schedule_rounded,
      title: 'Giờ hoàng đạo',
      trailing: Text('Giờ Tý: ${canChiHourTy(date)}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.55,
        children: [
          for (final h in hours)
            Builder(
              builder: (context) {
                final now = _isNow(h);
                return Container(
                  decoration: BoxDecoration(
                    color: now ? lich.goodDay.withValues(alpha: 0.18) : scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: now ? Border.all(color: lich.goodDay, width: 1.5) : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(conGiap[chi.indexOf(h.branch)], style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.branch, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(
                              '${h.startHour}h–${h.endHour}h',
                              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Countdown to the next holidays; tapping one shows it on the calendar.
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({super.key, required this.items, required this.onTap});

  final List<UpcomingHoliday> items;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lich = context.lich;
    return SectionCard(
      icon: Icons.event_available_rounded,
      title: 'Ngày lễ sắp tới',
      child: Column(
        children: [
          for (final (i, e) in items.indexed) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(e.date),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: lich.holiday.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${e.date.day}',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: lich.holiday,
                              height: 1,
                            ),
                          ),
                          Text('Th ${e.date.month}', style: TextStyle(fontSize: 10.5, color: lich.holiday)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(
                            '${weekdayNames[e.date.weekday - 1]} · ${_lunarShort(e.date)}',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: e.daysLeft == 0 ? lich.holiday : scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        e.daysLeft == 0 ? 'Hôm nay' : 'còn ${e.daysLeft} ngày',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: e.daysLeft == 0 ? lich.onHero : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _lunarShort(DateTime d) {
    final l = solarToLunar(d);
    return '${l.day}/${l.month}${l.isLeap ? ' nhuận' : ''} âm';
  }
}

/// Events on [date], with a button to add one.
class DayEventsCard extends StatelessWidget {
  const DayEventsCard({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final events = EventScope.of(context).on(date, solarToLunar(date));
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.event_note_rounded,
      title: 'Sự kiện trong ngày',
      trailing: TextButton.icon(
        onPressed: () => openEventEditor(context, date: date),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Thêm'),
      ),
      child: events.isEmpty
          ? Text('Chưa có sự kiện nào trong ngày này.', style: TextStyle(color: scheme.onSurfaceVariant))
          : Column(
              children: [for (final e in events) EventTile(event: e, date: date)],
            ),
    );
  }
}
