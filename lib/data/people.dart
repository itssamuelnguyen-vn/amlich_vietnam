import 'package:flutter/widgets.dart';

import '../lunar/lunar_calendar.dart';
import 'app_database.dart';

/// A family member: their lunar birth year (for ages and clashes) and optionally a birthday, solar or lunar.
/// A birthday is mirrored as a yearly event ([eventId]) so it gets calendar dots, reminders, widgets and sync.
class Person {
  const Person({
    this.id,
    required this.name,
    required this.birthYear,
    this.birthDay,
    this.birthMonth,
    this.birthLunar = false,
    this.eventId,
  });

  final int? id;
  final String name;

  /// Lunar birth year.
  final int birthYear;
  final int? birthDay;
  final int? birthMonth;
  final bool birthLunar;
  final int? eventId;

  bool get hasBirthday => birthDay != null && birthMonth != null;

  /// Solar year of birth: the lunar year, or the next one for a solar birthday before Tết.
  int get solarBirthYear {
    if (!hasBirthday || birthLunar) return birthYear;
    final d = DateTime(birthYear, birthMonth!, birthDay!);
    return solarToLunar(d).year == birthYear ? birthYear : birthYear + 1;
  }

  /// Age reached on the birthday that falls on [birthday] (solar or lunar years, matching the birthday's calendar).
  int ageOnBirthday(DateTime birthday) =>
      birthLunar ? solarToLunar(birthday).year - birthYear : birthday.year - solarBirthYear;

  Person copyWith({
    int? id,
    String? name,
    int? birthYear,
    int? Function()? birthDay,
    int? Function()? birthMonth,
    bool? birthLunar,
    int? Function()? eventId,
  }) => Person(
    id: id ?? this.id,
    name: name ?? this.name,
    birthYear: birthYear ?? this.birthYear,
    birthDay: birthDay != null ? birthDay() : this.birthDay,
    birthMonth: birthMonth != null ? birthMonth() : this.birthMonth,
    birthLunar: birthLunar ?? this.birthLunar,
    eventId: eventId != null ? eventId() : this.eventId,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'birth_year': birthYear,
    'birth_day': birthDay,
    'birth_month': birthMonth,
    'birth_lunar': birthLunar ? 1 : 0,
    'event_id': eventId,
  };

  factory Person.fromMap(Map<String, Object?> m) => Person(
    id: m['id'] as int?,
    name: m['name'] as String,
    birthYear: m['birth_year'] as int,
    birthDay: m['birth_day'] as int?,
    birthMonth: m['birth_month'] as int?,
    birthLunar: m['birth_lunar'] == 1,
    eventId: m['event_id'] as int?,
  );
}

abstract class PeopleBackend {
  Future<List<Person>> loadAll();

  Future<int> insert(Person p);

  Future<void> update(Person p);

  Future<void> delete(int id);
}

class SqlitePeopleBackend implements PeopleBackend {
  @override
  Future<List<Person>> loadAll() async => [
    for (final row in await (await AppDatabase.instance).query('people', orderBy: 'birth_year')) Person.fromMap(row),
  ];

  @override
  Future<int> insert(Person p) async => (await AppDatabase.instance).insert('people', p.toMap()..remove('id'));

  @override
  Future<void> update(Person p) async =>
      (await AppDatabase.instance).update('people', p.toMap()..remove('id'), where: 'id = ?', whereArgs: [p.id]);

  @override
  Future<void> delete(int id) async => (await AppDatabase.instance).delete('people', where: 'id = ?', whereArgs: [id]);
}

class MemoryPeopleBackend implements PeopleBackend {
  final _rows = <int, Person>{};
  var _nextId = 0;

  @override
  Future<List<Person>> loadAll() async => _rows.values.toList();

  @override
  Future<int> insert(Person p) async {
    _rows[++_nextId] = p.copyWith(id: _nextId);
    return _nextId;
  }

  @override
  Future<void> update(Person p) async => _rows[p.id!] = p;

  @override
  Future<void> delete(int id) async => _rows.remove(id);
}

class PeopleStore extends ChangeNotifier {
  PeopleStore(this._backend);

  final PeopleBackend _backend;
  List<Person> _people = [];

  List<Person> get people => List.unmodifiable(_people);

  Future<void> load() async {
    _people = await _backend.loadAll();
    notifyListeners();
  }

  void _sort() => _people.sort((a, b) => a.birthYear.compareTo(b.birthYear));

  Future<Person> add(Person p) async {
    final saved = p.copyWith(id: await _backend.insert(p));
    _people = [..._people, saved];
    _sort();
    notifyListeners();
    return saved;
  }

  Future<void> update(Person p) async {
    await _backend.update(p);
    _people = [for (final x in _people) x.id == p.id ? p : x];
    _sort();
    notifyListeners();
  }

  /// Adds people from a backup; with [replace] the current list is cleared first. Same name and year are skipped.
  /// Links to birthday events are dropped (event ids differ after a restore); the events come back on their own.
  Future<void> import(List<Person> incoming, {required bool replace}) async {
    if (replace) {
      for (final p in _people) {
        await _backend.delete(p.id!);
      }
      _people = [];
    }
    final seen = {for (final p in _people) '${p.name}|${p.birthYear}'};
    for (final p in incoming) {
      if (!seen.add('${p.name}|${p.birthYear}')) continue;
      final fresh = p.copyWith(eventId: () => null);
      _people.add(fresh.copyWith(id: await _backend.insert(fresh)));
    }
    _sort();
    notifyListeners();
  }

  Future<void> remove(Person p) async {
    await _backend.delete(p.id!);
    _people = [
      for (final x in _people)
        if (x.id != p.id) x,
    ];
    notifyListeners();
  }
}

class PeopleScope extends InheritedNotifier<PeopleStore> {
  const PeopleScope({super.key, required PeopleStore store, required super.child}) : super(notifier: store);

  static PeopleStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PeopleScope>()!.notifier!;
}
