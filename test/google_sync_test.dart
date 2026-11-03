import 'package:amlich_vietnam/data/settings.dart';
import 'package:amlich_vietnam/events/event.dart';
import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/lunar/format.dart';
import 'package:amlich_vietnam/lunar/lunar_calendar.dart';
import 'package:amlich_vietnam/sync/google_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('sync items cover two years of occurrences with stable keys and a descriptive note', () async {
    final store = EventStore(
      MemoryEventBackend([
        const Event(
          title: 'Giỗ ông',
          note: 'Về quê',
          calendar: EventCalendar.lunar,
          day: 12,
          month: 10,
          year: 2010,
          repeat: Repeat.yearly,
        ),
        const Event(title: 'Họp', calendar: EventCalendar.solar, day: 15, month: 11, year: 2026),
        const Event(title: 'Cũ', calendar: EventCalendar.solar, day: 1, month: 1, year: 2020),
      ]),
    );
    await store.load();
    final items = GoogleSync.items(store, DateTime(2026, 11, 3));
    final gio = items.where((i) => i['t'] == 'Giỗ ông').toList();
    // One per lunar year whose 12/10 falls between today and two years ahead.
    final expected = [for (var y = 2026; y <= 2028; y++) lunarToSolar(LunarDate(12, 10, y))!]
        .where((d) => !d.isBefore(DateTime(2026, 11, 3)) && !d.isAfter(DateTime(2028, 11, 3)));
    expect(gio.map((i) => i['d']), [for (final d in expected) '${d.year}-${two(d.month)}-${two(d.day)}']);
    expect(gio.first['k'], '1|2026-11-20');
    expect(gio.first['n'], contains('Hằng năm · 12/10 âm lịch'));
    expect(gio.first['n'], contains('Về quê'));
    expect(items.where((i) => i['t'] == 'Họp').single['d'], '2026-11-15');
    expect(items.where((i) => i['t'] == 'Cũ'), isEmpty);
  });

  test('settings keep the chosen calendar', () {
    const s = Settings(googleCalendarId: 3, googleCalendarName: 'Lịch · a@gmail.com');
    final back = Settings.fromMap(s.toMap());
    expect(back.googleCalendarId, 3);
    expect(back.googleCalendarName, 'Lịch · a@gmail.com');
    expect(back.copyWith(googleCalendarId: () => null).googleCalendarId, isNull);
  });

  testWidgets('settings show the Google sync card, and its state when enabled', (tester) async {
    usePhoneScreen(tester);
    final app = await testApp();
    await tester.pumpWidget(app);
    await tester.tap(find.text('Cài đặt').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Bật đồng bộ'), find.byType(ListView).last, const Offset(0, -300));
    expect(find.text('Đồng bộ Google Calendar'), findsOneWidget);
    expect(find.text('Bật đồng bộ'), findsOneWidget);

    await app.settings.update(app.settings.value.copyWith(googleCalendarId: () => 7, googleCalendarName: 'Cá nhân'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Cá nhân'), find.byType(ListView).last, const Offset(0, 200));
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.text('Tắt đồng bộ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
