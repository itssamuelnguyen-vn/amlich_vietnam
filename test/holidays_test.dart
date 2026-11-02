import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/lunar/format.dart';
import 'package:amlich_vietnam/lunar/holidays.dart';
import 'package:amlich_vietnam/lunar/lunar_calendar.dart';
import 'package:amlich_vietnam/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _on(DateTime d) => holidaysOf(d, solarToLunar(d));

void main() {
  test('holidays', () {
    expect(_on(DateTime(2026, 2, 17)), ['Tết Nguyên đán']);
    expect(_on(DateTime(2026, 2, 16)), ['Giao thừa']);
    expect(_on(DateTime(2025, 9, 2)), ['Quốc khánh']);
    expect(_on(DateTime(2024, 9, 17)), ['Tết Trung thu']);
    expect(_on(DateTime(2026, 3, 3)), ['Rằm tháng Giêng']);
    expect(_on(DateTime(2026, 3, 4)), isEmpty);
  });

  test('upcoming holidays count down from the given day', () {
    final list = upcomingHolidays(DateTime(2026, 11, 2), count: 3);
    expect(list.map((e) => e.name), ['Nhà giáo Việt Nam', 'Quân đội Nhân dân', 'Giáng sinh']);
    expect(list.first.daysLeft, 18);
  });

  test('day stars: Thanh Long on Rat days in the 1st month, about half the days are auspicious', () {
    // 10/02/2024 is the first day of Tết, a Dragon (Thìn) day: Tý→Thìn is 4 steps, Kim Quỹ.
    final tet = DateTime(2024, 2, 10);
    final star = dayStarOf(tet, solarToLunar(tet));
    expect(star.name, 'Kim Quỹ');
    expect(star.isGood, isTrue);
    var good = 0;
    for (var i = 0; i < 360; i++) {
      final d = DateTime(2024, 1, 1 + i);
      if (dayStarOf(d, solarToLunar(d)).isGood) good++;
    }
    expect(good, closeTo(180, 10));
  });

  for (final brightness in Brightness.values) {
    testWidgets('calendar screen on a phone (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(AmLichApp(store: EventStore(MemoryEventBackend())));
      final now = today();
      expect(find.text('HÔM NAY'), findsOneWidget);
      expect(find.text('Tháng ${now.month}, ${now.year}'), findsOneWidget);
      expect(find.text(weekdayNames[now.weekday - 1]), findsWidgets);

      // Next day by swiping the hero card.
      await tester.fling(find.text('HÔM NAY'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('HÔM NAY'), findsNothing);

      // Back to today with the toolbar button.
      await tester.tap(find.byTooltip('Về hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('HÔM NAY'), findsOneWidget);

      // Scroll down to the lower cards.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(find.text('Ngày lễ sắp tới'), findsOneWidget);

      // Converter sheet and month picker open without layout errors.
      await tester.tap(find.byTooltip('Đổi ngày âm sang dương'));
      await tester.pumpAndSettle();
      expect(find.text('Xem trên lịch'), findsOneWidget);
      await tester.tap(find.text('Xem trên lịch'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tháng ${now.month}, ${now.year}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Th 1'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 1, ${now.year}'), findsOneWidget);
    });
  }
}
