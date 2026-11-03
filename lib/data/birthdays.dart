import '../events/event.dart';
import '../events/event_store.dart';
import 'people.dart';

/// Title of the yearly event mirroring [name]'s birthday.
String birthdayTitle(String name) => '🎂 Sinh nhật $name';

/// Saves [person] and keeps their birthday event in step: created, updated (name or date changed) or deleted.
Future<Person> saveWithBirthday(PeopleStore people, EventStore events, Person person) async {
  // Reuse an event linked earlier, or one with the expected title (e.g. after a restore dropped the link).
  final existing =
      events.events.where((e) => e.id == person.eventId).firstOrNull ??
      events.events.where((e) => e.title == birthdayTitle(person.name)).firstOrNull;

  int? eventId;
  if (person.hasBirthday) {
    final event = Event(
      id: existing?.id,
      title: birthdayTitle(person.name),
      calendar: person.birthLunar ? EventCalendar.lunar : EventCalendar.solar,
      day: person.birthDay!,
      month: person.birthMonth!,
      year: person.birthLunar ? person.birthYear : person.solarBirthYear,
      repeat: Repeat.yearly,
      color: 1,
      remindDays: existing?.remindDays ?? 1,
      note: existing?.note ?? '',
    );
    eventId = (await events.save(event)).id;
  } else if (existing != null) {
    await events.delete(existing);
  }
  final linked = person.copyWith(eventId: () => eventId);
  if (person.id == null) return people.add(linked);
  await people.update(linked);
  return linked;
}

/// Removes [person] and their birthday event.
Future<void> removeWithBirthday(PeopleStore people, EventStore events, Person person) async {
  final event = events.events.where((e) => e.id == person.eventId).firstOrNull;
  if (event != null) await events.delete(event);
  await people.remove(person);
}

/// Next birthday of [person] on or after [today], with the age they turn; null without a birthday.
({DateTime date, int age})? nextBirthday(Person person, EventStore events, DateTime today) {
  final event = events.events.where((e) => e.id == person.eventId).firstOrNull;
  final date = event?.nextOccurrence(today);
  if (date == null) return null;
  return (date: date, age: person.ageOnBirthday(date));
}
