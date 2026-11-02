import 'dart:convert';

import 'package:amlich_vietnam/data/settings.dart';
import 'package:amlich_vietnam/events/event.dart';
import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/lunar/holidays.dart';
import 'package:amlich_vietnam/widget/widget_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget occurrences span last month to a year ahead, sorted, with colours', () async {
    final store = EventStore(
      MemoryEventBackend([
        const Event(title: 'Rằm', calendar: EventCalendar.lunar, day: 15, month: 1, year: 2026, repeat: Repeat.monthly),
        const Event(title: 'Họp', calendar: EventCalendar.solar, day: 5, month: 11, year: 2026, color: 3),
        const Event(title: 'Cũ', calendar: EventCalendar.solar, day: 1, month: 1, year: 2020),
      ]),
    );
    await store.load();
    final list = WidgetBridge.occurrencesJson(store, DateTime(2026, 11, 2));

    final dates = [for (final o in list) o['d'] as String];
    expect(dates, orderedEquals([...dates]..sort()));
    expect(dates.first.compareTo('2026-10-01'), greaterThanOrEqualTo(0)); // from the start of last month
    expect(dates.last.compareTo('2027-11-02'), lessThanOrEqualTo(0));
    expect(list.where((o) => o['t'] == 'Rằm'), hasLength(inInclusiveRange(13, 15)));
    expect(list.singleWhere((o) => o['t'] == 'Họp'), {'t': 'Họp', 'd': '2026-11-05', 'c': eventColors[3].toARGB32(), 'r': -1});
    expect(list.where((o) => o['t'] == 'Cũ'), isEmpty);
  });

  test('countdown defaults to the next two Tết dates, or follows the chosen event', () async {
    final store = EventStore(
      MemoryEventBackend([
        const Event(title: 'Giỗ', calendar: EventCalendar.lunar, day: 10, month: 3, year: 2000, repeat: Repeat.yearly),
      ]),
    );
    await store.load();
    final today = DateTime(2026, 11, 2);
    final tet = WidgetBridge.countdownJson(store, const Settings(), today);
    expect(tet['title'], 'Tết Đinh Mùi');
    expect((tet['dates'] as List).first, '2027-02-06');
    expect((tet['dates'] as List).last, '${nextTet(DateTime(2027, 2, 7)).year}-01-26');

    final id = store.events.single.id;
    final anniversary = WidgetBridge.countdownJson(store, Settings(countdownEventId: id), today);
    expect(anniversary['title'], 'Giỗ');
    expect((anniversary['dates'] as List).first, '2027-04-16'); // 10/3 Đinh Mùi
    expect(anniversary['dates'] as List, hasLength(24));

    final payload = WidgetBridge.syncPayload(store, const Settings(weekStartsMonday: false), today);
    expect(jsonDecode(payload['settings']!)['weekStartsMonday'], isFalse);
    expect(payload.keys, containsAll(['occurrences', 'settings', 'countdown']));
  });
}
