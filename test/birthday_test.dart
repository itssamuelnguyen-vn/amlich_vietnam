import 'package:amlich_vietnam/data/birthdays.dart';
import 'package:amlich_vietnam/data/people.dart';
import 'package:amlich_vietnam/events/event.dart';
import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/lunar/lunar_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('a birthday becomes a yearly event that follows renames and removal', () async {
    final people = PeopleStore(MemoryPeopleBackend());
    final events = EventStore(MemoryEventBackend());
    await Future.wait([people.load(), events.load()]);

    var mom = await saveWithBirthday(
      people,
      events,
      const Person(name: 'Mẹ', birthYear: 1966, birthDay: 12, birthMonth: 10, birthLunar: true),
    );
    final event = events.events.single;
    expect(event.title, '🎂 Sinh nhật Mẹ');
    expect((event.calendar, event.day, event.month, event.repeat), (EventCalendar.lunar, 12, 10, Repeat.yearly));
    expect(event.remindDays, 1);
    expect(mom.eventId, event.id);

    // 12/10 Bính Ngọ (2026) is her 60th lunar birthday.
    final next = nextBirthday(mom, events, DateTime(2026, 11, 3))!;
    expect(next.date, lunarToSolar(const LunarDate(12, 10, 2026)));
    expect(next.age, 60);

    mom = await saveWithBirthday(people, events, mom.copyWith(name: 'Mẹ Hoa'));
    expect(events.events.single.title, '🎂 Sinh nhật Mẹ Hoa');

    mom = await saveWithBirthday(people, events, mom.copyWith(birthDay: () => null, birthMonth: () => null));
    expect(events.events, isEmpty);
    expect(mom.eventId, isNull);

    mom = await saveWithBirthday(people, events, mom.copyWith(birthDay: () => 1, birthMonth: () => 2));
    await removeWithBirthday(people, events, mom);
    expect(events.events, isEmpty);
    expect(people.people, isEmpty);
  });

  test('solar birthdays before Tết belong to the next solar year', () {
    const early = Person(name: 'A', birthYear: 1990, birthDay: 15, birthMonth: 1);
    expect(early.solarBirthYear, 1991); // 15/01/1991 is still lunar year 1990
    const late = Person(name: 'B', birthYear: 1990, birthDay: 15, birthMonth: 6);
    expect(late.solarBirthYear, 1990);
    expect(late.ageOnBirthday(DateTime(2026, 6, 15)), 36);
  });

  testWidgets('add a family member with a lunar birthday from the tools tab', (tester) async {
    usePhoneScreen(tester);
    final app = await testApp();
    await tester.pumpWidget(app);
    await tester.tap(find.text('Tiện ích').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Cả nhà'), find.byType(ListView).last, const Offset(0, -300));
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Bố');
    await tester.tap(find.text('Nhớ sinh nhật'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Âm lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu').last);
    await tester.pumpAndSettle();

    final dad = app.people.people.single;
    expect(dad.name, 'Bố');
    expect(dad.birthLunar, isTrue);
    expect(app.events.events.single.title, '🎂 Sinh nhật Bố');
    expect(find.textContaining('🎂 1/1 âm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
