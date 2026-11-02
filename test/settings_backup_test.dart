import 'package:amlich_vietnam/data/backup.dart';
import 'package:amlich_vietnam/data/people.dart';
import 'package:amlich_vietnam/data/settings.dart';
import 'package:amlich_vietnam/events/event.dart';
import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/lunar/format.dart';
import 'package:amlich_vietnam/lunar/holidays.dart';
import 'package:amlich_vietnam/lunar/lunar_calendar.dart';
import 'package:amlich_vietnam/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _gio = Event(
  title: 'Giỗ ông',
  calendar: EventCalendar.lunar,
  day: 12,
  month: 10,
  year: 2010,
  repeat: Repeat.yearly,
  color: 4,
  remindDays: 1,
);

void main() {
  test('settings survive a round trip and fall back to defaults', () {
    const s = Settings(
      themeMode: ThemeMode.dark,
      textScale: 1.3,
      weekStartsMonday: false,
      holidayKinds: {HolidayKind.lunar},
      reminderHour: 20,
      reminderMinute: 30,
      lunarReminders: true,
      countdownEventId: 7,
    );
    expect(Settings.fromMap(s.toMap()).toMap(), s.toMap());
    final d = Settings.fromMap({'theme_mode': 'nonsense'});
    expect(d.themeMode, ThemeMode.system);
    expect(d.holidayKinds, HolidayKind.values.toSet());
    expect(d.countdownEventId, isNull);
  });

  test('holiday kinds filter holidays', () {
    final d = DateTime(2026, 12, 24);
    expect(holidaysOf(d, solarToLunar(d)), ['Giáng sinh']);
    expect(holidaysOf(d, solarToLunar(d), kinds: {HolidayKind.lunar, HolidayKind.vietnam}), isEmpty);
    final tet = DateTime(2026, 2, 17);
    expect(holidaysOf(tet, solarToLunar(tet), kinds: {HolidayKind.vietnam}), isEmpty);
    expect(nextTet(DateTime(2026, 11, 2)), DateTime(2027, 2, 6));
    expect(nextTet(DateTime(2026, 2, 17)), DateTime(2026, 2, 17));
  });

  test('week can start on Sunday', () {
    final wed = DateTime(2026, 11, 4);
    expect(startOfWeek(wed, mondayFirst: true), DateTime(2026, 11, 2));
    expect(startOfWeek(wed, mondayFirst: false), DateTime(2026, 11, 1));
    expect(startOfWeek(DateTime(2026, 11, 1), mondayFirst: false), DateTime(2026, 11, 1));
  });

  test('backup round trip, merge skips duplicates, replace clears', () async {
    final text = Backup.encode(
      const BackupData(
        events: [_gio],
        people: [Person(name: 'Bố', birthYear: 1960)],
        settings: Settings(textScale: 1.15),
      ),
    );
    final data = Backup.decode(text);
    expect(data.events.single.toMap()..remove('id'), _gio.toMap()..remove('id'));
    expect(data.people.single.name, 'Bố');
    expect(data.settings!.textScale, 1.15);

    final store = EventStore(MemoryEventBackend([_gio, _gio.copyWith(title: 'Khác')]));
    await store.load();
    expect(await store.import(data.events, replace: false, key: Backup.eventKey), 0);
    expect(store.events, hasLength(2));
    expect(await store.import(data.events, replace: true, key: Backup.eventKey), 1);
    expect(store.events.single.title, 'Giỗ ông');

    final people = PeopleStore(MemoryPeopleBackend());
    await people.load();
    await people.import(data.people, replace: false);
    await people.import(data.people, replace: false);
    expect(people.people, hasLength(1));
  });

  test('bad backup files are rejected with a readable message', () {
    expect(() => Backup.decode('hello'), throwsA(isA<FormatException>()));
    expect(() => Backup.decode('{"app": "other"}'), throwsA(isA<FormatException>()));
    expect(
      () => Backup.decode('{"app": "amlich_vietnam", "events": [{"title": 1}]}'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', 'File sao lưu bị hỏng')),
    );
  });

  testWidgets('settings tab changes week start, text size and theme', (tester) async {
    usePhoneScreen(tester);
    final app = await testApp();
    await tester.pumpWidget(app);
    await tester.tap(find.text('Cài đặt').last);
    await tester.pumpAndSettle();

    Finder inSettings(String text) => find.descendant(of: find.byType(SettingsScreen), matching: find.text(text));
    for (final label in ['Chủ Nhật', 'Rất lớn', 'Tối']) {
      await tester.ensureVisible(inSettings(label));
      await tester.pumpAndSettle();
      await tester.tap(inSettings(label));
      await tester.pumpAndSettle();
    }
    expect(app.settings.value.weekStartsMonday, isFalse);
    expect(app.settings.value.textScale, 1.3);
    expect(app.settings.value.themeMode, ThemeMode.dark);

    await tester.tap(find.text('Lịch').last);
    await tester.pumpAndSettle();
    // Sunday-first header: CN comes before T2.
    final cn = tester.getTopLeft(find.text('CN').first).dx;
    final t2 = tester.getTopLeft(find.text('T2').first).dx;
    expect(cn, lessThan(t2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab lays out with the largest text size', (tester) async {
    usePhoneScreen(tester);
    final app = await testApp(
      events: [
        _gio,
        _gio.copyWith(title: 'Một sự kiện có cái tên rất dài để thử xuống dòng', repeat: Repeat.monthly),
      ],
    );
    await app.settings.update(const Settings(textScale: 1.3));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    for (final tab in ['Sự kiện', 'Tiện ích', 'Cài đặt']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab, scroll $i');
      }
    }
    expect(tester.takeException(), isNull);
  });
}
