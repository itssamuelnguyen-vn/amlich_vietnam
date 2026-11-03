import 'package:amlich_vietnam/data/settings.dart';
import 'package:amlich_vietnam/pregnancy/pregnancy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('gestational age, trimester and due date (Naegele: +280 days)', () {
    final p = Pregnancy(DateTime(2026, 5, 1));
    expect(p.due, DateTime(2027, 2, 5));
    expect(p.ageOn(DateTime(2026, 11, 3)), (26, 4)); // 186 days
    expect(p.trimesterOn(DateTime(2026, 11, 3)), 2);
    expect(p.trimesterOn(DateTime(2026, 6, 1)), 1);
    expect(p.weekStart(20), DateTime(2026, 9, 18));
  });

  test('the start date survives settings storage', () {
    final s = Settings(pregnancyStart: DateTime(2026, 5, 1));
    expect(Settings.fromMap(s.toMap()).pregnancyStart, DateTime(2026, 5, 1));
    expect(Settings.fromMap(const Settings().toMap()).pregnancyStart, isNull);
  });

  testWidgets('pregnancy card shows the week and adds check-ups to the calendar', (tester) async {
    usePhoneScreen(tester);
    final app = await testApp();
    final now = DateTime.now();
    await app.settings.update(Settings(pregnancyStart: DateTime(now.year, now.month, now.day - 100)));
    await tester.pumpWidget(app);
    await tester.tap(find.text('Tiện ích').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Thêm các mốc khám vào lịch'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.text('14 tuần 2 ngày'), findsOneWidget);
    await tester.ensureVisible(find.text('Thêm các mốc khám vào lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm các mốc khám vào lịch'));
    await tester.pumpAndSettle();
    // Week 11 is already past at day 100; the five later check-ups are added.
    expect(app.events.events.where((e) => e.title.startsWith('🤰')), hasLength(5));
    expect(tester.takeException(), isNull);
  });
}
