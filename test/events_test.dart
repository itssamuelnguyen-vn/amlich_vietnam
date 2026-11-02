import 'package:amlich_vietnam/events/event.dart';
import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/lunar/format.dart';
import 'package:amlich_vietnam/lunar/lunar_calendar.dart';
import 'package:amlich_vietnam/main.dart';
import 'package:amlich_vietnam/screens/tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _on(Event e, DateTime d) => e.occursOn(d, solarToLunar(d));

Event _lunar(int day, int month, int year, {Repeat repeat = Repeat.yearly, bool leap = false}) =>
    Event(title: 't', calendar: EventCalendar.lunar, day: day, month: month, year: year, leap: leap, repeat: repeat);

Event _solar(int day, int month, int year, {Repeat repeat = Repeat.yearly}) =>
    Event(title: 't', calendar: EventCalendar.solar, day: day, month: month, year: year, repeat: repeat);

void main() {
  group('occurrences', () {
    test('yearly lunar date (death anniversary) moves with the lunar calendar', () {
      final e = _lunar(10, 3, 2020);
      expect(_on(e, DateTime(2024, 4, 18)), isTrue); // 10/3 Giáp Thìn
      expect(_on(e, DateTime(2025, 4, 7)), isTrue); // 10/3 Ất Tỵ
      expect(_on(e, DateTime(2019, 4, 14)), isFalse, reason: 'before the first occurrence');
      expect(e.nextOccurrence(DateTime(2024, 1, 1)), DateTime(2024, 4, 18));
      expect(e.nextOccurrence(DateTime(2024, 4, 19)), DateTime(2025, 4, 7));
    });

    test('yearly lunar events skip the leap month of the same number', () {
      final e = _lunar(15, 2, 2000);
      expect(_on(e, lunarToSolar(const LunarDate(15, 2, 2023))!), isTrue);
      expect(_on(e, lunarToSolar(const LunarDate(15, 2, 2023, isLeap: true))!), isFalse);
      // Monthly events do happen in leap months.
      final monthly = _lunar(15, 1, 2023, repeat: Repeat.monthly);
      expect(_on(monthly, lunarToSolar(const LunarDate(15, 2, 2023, isLeap: true))!), isTrue);
    });

    test('day 30 falls on the last day of a 29-day lunar month', () {
      final year = [for (var y = 2001; y < 2040; y++) y].firstWhere((y) => daysInLunarMonth(12, y) == 29);
      final e = _lunar(30, 12, 2000);
      expect(_on(e, lunarToSolar(LunarDate(29, 12, year))!), isTrue);
      expect(_on(e, lunarToSolar(LunarDate(28, 12, year))!), isFalse);
    });

    test('solar dates past the end of a month use its last day', () {
      final leapDay = _solar(29, 2, 2024);
      expect(_on(leapDay, DateTime(2025, 2, 28)), isTrue);
      expect(_on(leapDay, DateTime(2028, 2, 29)), isTrue);
      expect(_on(leapDay, DateTime(2028, 2, 28)), isFalse);
      final monthly = _solar(31, 1, 2026, repeat: Repeat.monthly);
      expect(_on(monthly, DateTime(2026, 11, 30)), isTrue);
      expect(monthly.nextOccurrence(DateTime(2026, 11, 2)), DateTime(2026, 11, 30));
    });

    test('one-off events', () {
      final e = _solar(5, 11, 2026, repeat: Repeat.none);
      expect(_on(e, DateTime(2026, 11, 5)), isTrue);
      expect(_on(e, DateTime(2027, 11, 5)), isFalse);
      expect(e.nextOccurrence(DateTime(2026, 11, 2)), DateTime(2026, 11, 5));
      expect(e.nextOccurrence(DateTime(2026, 11, 6)), isNull);
    });

    test('next lunar monthly occurrence (mùng 1 and rằm)', () {
      final ram = _lunar(15, 1, 2026, repeat: Repeat.monthly);
      final next = ram.nextOccurrence(DateTime(2026, 11, 2))!;
      expect(solarToLunar(next).day, 15);
      expect(daysBetween(DateTime(2026, 11, 2), next), lessThan(31));
    });

    test('describe and map round trip', () {
      final e = _lunar(10, 3, 2020).copyWith(id: 3, note: 'n', color: 2);
      expect(e.describe(), 'Hằng năm · 10/3 âm lịch');
      final back = Event.fromMap(e.toMap());
      expect(back.toMap(), e.toMap());
    });
  });

  test('store saves, updates, deletes and sorts upcoming events', () async {
    final store = EventStore(MemoryEventBackend());
    await store.load();
    final a = await store.save(_solar(20, 11, 2026, repeat: Repeat.none).copyWith(title: 'a'));
    await store.save(_solar(5, 11, 2026, repeat: Repeat.none).copyWith(title: 'b'));
    await store.save(_solar(1, 1, 2026, repeat: Repeat.none).copyWith(title: 'old'));
    expect(store.upcoming(DateTime(2026, 11, 2)).map((o) => o.event.title), ['b', 'a']);
    expect(store.past(DateTime(2026, 11, 2)).map((e) => e.title), ['old']);
    await store.save(a.copyWith(title: 'a2'));
    expect(store.events.map((e) => e.title), contains('a2'));
    await store.delete(a);
    expect(store.events, hasLength(2));
  });

  test('date tools', () {
    expect(ymdBetween(DateTime(2026, 1, 15), DateTime(2026, 3, 10)), (years: 0, months: 1, days: 23));
    expect(ymdBetween(DateTime(2000, 2, 29), DateTime(2026, 11, 2)), (years: 26, months: 8, days: 4));
    expect(workingDays(DateTime(2026, 11, 2), DateTime(2026, 11, 8)), 5); // Mon..Sun
    expect(workingDays(DateTime(2026, 11, 7), DateTime(2026, 11, 7)), 0); // a Saturday
  });

  testWidgets('add a lunar yearly event from the calendar and see it in the events tab', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = EventStore(MemoryEventBackend());
    await store.load();
    await tester.pumpWidget(AmLichApp(store: store));

    await tester.tap(find.byTooltip('Thêm sự kiện'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Giỗ ông');
    await tester.tap(find.text('Âm lịch'));
    await tester.tap(find.text('Hằng năm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(store.events.single.title, 'Giỗ ông');
    expect(store.events.single.calendar, EventCalendar.lunar);
    final lunar = solarToLunar(today());
    expect((store.events.single.day, store.events.single.month), (lunar.day, lunar.month));
    // Shown in "Sự kiện trong ngày", below the day page.
    await tester.dragUntilVisible(find.text('Giỗ ông'), find.byType(CustomScrollView), const Offset(0, -300));
    expect(find.text('Giỗ ông'), findsOneWidget);

    await tester.tap(find.text('Sự kiện').last);
    await tester.pumpAndSettle();
    expect(find.text('Giỗ ông'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);

    // Edit, then delete it.
    await tester.tap(find.text('Giỗ ông'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xoá'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
    await tester.pumpAndSettle();
    expect(store.events, isEmpty);
    expect(find.text('Chưa có sự kiện nào'), findsOneWidget);

    // The tools tab renders.
    await tester.tap(find.text('Tiện ích'));
    await tester.pumpAndSettle();
    expect(find.text('Khoảng cách giữa hai ngày'), findsOneWidget);
  });
}
