import 'package:flutter/material.dart';

import '../events/event.dart';
import '../events/event_store.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
import 'event_editor.dart';

/// All events: upcoming ones soonest first, then past one-off events.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.onShowDate});

  final ValueChanged<DateTime> onShowDate;

  @override
  Widget build(BuildContext context) {
    final store = EventScope.of(context);
    final now = today();
    final upcoming = store.upcoming(now);
    final past = store.past(now);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sự kiện', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-event-list',
        onPressed: () => openEventEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm sự kiện'),
      ),
      body: store.events.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _Header('Sắp tới'),
                  for (final o in upcoming)
                    EventTile(event: o.event, date: o.date, daysLeft: daysBetween(now, o.date), onShowDate: onShowDate),
                ],
                if (past.isNotEmpty) ...[
                  const _Header('Đã qua'),
                  for (final e in past) EventTile(event: e, date: e.start, onShowDate: onShowDate),
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// One event as a card: date badge in the event colour, title, date rule, and a countdown when [daysLeft] is given.
/// Tapping edits it; long-pressing shows its date on the calendar.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, required this.date, this.daysLeft, this.onShowDate});

  final Event event;
  final DateTime date;
  final int? daysLeft;
  final ValueChanged<DateTime>? onShowDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = event.colorValue;
    final lunar = solarToLunar(date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => openEventEditor(context, event: event),
          onLongPress: onShowDate == null ? null : () => onShowDate!(date),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1,
                        ),
                      ),
                      Text('Th ${date.month}', style: TextStyle(fontSize: 11, color: color)),
                      Text(
                        '${lunar.day}/${lunar.month} âm',
                        style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(
                              event.isLunar ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              event.describe(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      if (event.note.isNotEmpty)
                        Text(
                          event.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                if (daysLeft != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: daysLeft == 0 ? color : scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      daysLeft == 0 ? 'Hôm nay' : 'còn $daysLeft ngày',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: daysLeft == 0 ? Colors.white : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.event_note_rounded, size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có sự kiện nào',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Ghi lại ngày giỗ, sinh nhật âm lịch, ngày kỷ niệm…\nSự kiện lặp hằng năm theo âm lịch sẽ tự tính sang dương lịch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
