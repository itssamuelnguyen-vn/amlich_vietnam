import 'package:amlich_vietnam/counters/counter.dart';
import 'package:amlich_vietnam/data/backup.dart';
import 'package:amlich_vietnam/data/settings.dart';
import 'package:amlich_vietnam/widget/widget_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _today = DateTime(2026, 11, 3);

void main() {
  test('counts days like love-day apps, or day 0, or down to a future date', () {
    final c = DayCounter(title: 'Bên nhau', date: DateTime(2026, 11, 1));
    expect(c.daysOn(DateTime(2026, 11, 1)), 1);
    expect(c.daysOn(_today), 3);
    expect(c.copyWith(firstDayIsOne: false).daysOn(_today), 2);
    final future = DayCounter(title: 'Cưới', date: DateTime(2026, 12, 25));
    expect(future.isFuture(_today), isTrue);
    expect(future.daysOn(_today), 52);
  });

  test('milestones: 100-day steps to 1000, then every 1000, and anniversaries', () {
    final c = DayCounter(title: 'Bên nhau', date: DateTime(2024, 2, 14));
    // 2026-11-03 is day 994 (14/02/2024 is day 1).
    expect(c.dayNumberOn(_today), 994);
    final m = c.upcomingMilestones(_today, limit: 4);
    expect(m.map((x) => x.label), ['1000 ngày', 'Kỷ niệm 3 năm', 'Kỷ niệm 4 năm', 'Kỷ niệm 5 năm']);
    // Day 2000 is 05/08/2029, between the 5th (02/2029) and 6th (02/2030) anniversaries.
    final six = c.upcomingMilestones(_today, limit: 6);
    expect(six[4].label, '2000 ngày');
    expect(six[4].date, DateTime(2029, 8, 5));
    expect(six[5].label, 'Kỷ niệm 6 năm');
    expect(m.first.date, DateTime(2026, 11, 9));
    expect(m[1].date, DateTime(2027, 2, 14));
    expect(c.dayNumberOn(m.first.date), 1000);

    final young = DayCounter(title: 'Bé', date: DateTime(2026, 10, 1));
    expect(young.upcomingMilestones(_today, limit: 2).map((x) => x.label), ['100 ngày', '200 ngày']);

    final leap = DayCounter(title: 'x', date: DateTime(2024, 2, 29));
    expect(leap.upcomingMilestones(_today).firstWhere((x) => x.isAnniversary).date, DateTime(2027, 2, 28));
  });

  test('formatting and storage round trip', () {
    expect(formatCount(7), '7');
    expect(formatCount(1234), '1.234');
    expect(formatCount(1234567), '1.234.567');
    final c = DayCounter(
      id: 3,
      title: 'A',
      date: DateTime(2020, 1, 2),
      emoji: '💍',
      color: 2,
      firstDayIsOne: false,
      photo: '/x.img',
    );
    expect(DayCounter.fromMap(c.toMap()).toMap(), c.toMap());
  });

  test('backup carries counters without photos; widget payload and milestone notifications', () async {
    final c = DayCounter(id: 1, title: 'Bên nhau', date: DateTime(2024, 2, 14), photo: '/p.img');
    final data = Backup.decode(Backup.encode(BackupData(events: const [], people: const [], counters: [c])));
    expect(data.counters.single.title, 'Bên nhau');
    expect(data.counters.single.photo, '');

    expect(WidgetBridge.counterJson([c], const Settings())['title'], 'Bên nhau');
    expect(WidgetBridge.counterJson(const [], const Settings()), isEmpty);
    final notes = WidgetBridge.milestonesJson([c, c.copyWith(id: 2, notify: false)], _today);
    expect(notes.first, {'t': '❤️ Bên nhau: 1000 ngày', 'd': '2026-11-09'});
    expect(notes.every((n) => n['t']!.contains('Bên nhau')), isTrue);
    expect(notes.where((n) => n['d']!.compareTo('2027-11-03') > 0), isEmpty);
  });

  testWidgets('create a counter from the tools tab and open it', (tester) async {
    usePhoneScreen(tester);
    final app = await testApp();
    await tester.pumpWidget(app);
    await tester.tap(find.text('Tiện ích').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bên nhau');
    await tester.tap(find.text('💍'));
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(app.counters.counters.single.emoji, '💍');
    expect(find.text('Bên nhau'), findsOneWidget);

    await tester.tap(find.text('Bên nhau'));
    await tester.pumpAndSettle();
    expect(find.text('NGÀY THỨ'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // today is day 1
    expect(find.text('CÁC MỐC SẮP TỚI'), findsOneWidget);
    await tester.tap(find.byTooltip('Hiện trên widget "Đếm ngày"'));
    await tester.pumpAndSettle();
    expect(app.settings.value.counterWidgetId, app.counters.counters.single.id);
    expect(tester.takeException(), isNull);
  });
}
