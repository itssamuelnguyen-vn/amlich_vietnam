import 'package:flutter/widgets.dart';

import 'app_database.dart';

/// A family member, for "this day clashes with Bố's age" hints. [birthYear] is the lunar birth year.
class Person {
  const Person({this.id, required this.name, required this.birthYear});

  final int? id;
  final String name;
  final int birthYear;

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'birth_year': birthYear};

  factory Person.fromMap(Map<String, Object?> m) =>
      Person(id: m['id'] as int?, name: m['name'] as String, birthYear: m['birth_year'] as int);
}

abstract class PeopleBackend {
  Future<List<Person>> loadAll();

  Future<int> insert(Person p);

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
  Future<void> delete(int id) async => (await AppDatabase.instance).delete('people', where: 'id = ?', whereArgs: [id]);
}

class MemoryPeopleBackend implements PeopleBackend {
  final _rows = <int, Person>{};
  var _nextId = 0;

  @override
  Future<List<Person>> loadAll() async => _rows.values.toList();

  @override
  Future<int> insert(Person p) async {
    _rows[++_nextId] = Person(id: _nextId, name: p.name, birthYear: p.birthYear);
    return _nextId;
  }

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

  Future<void> add(Person p) async {
    final id = await _backend.insert(p);
    _people = [..._people, Person(id: id, name: p.name, birthYear: p.birthYear)]
      ..sort((a, b) => a.birthYear.compareTo(b.birthYear));
    notifyListeners();
  }

  /// Adds people from a backup; with [replace] the current list is cleared first. Same name and year are skipped.
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
      _people.add(Person(id: await _backend.insert(p), name: p.name, birthYear: p.birthYear));
    }
    _people.sort((a, b) => a.birthYear.compareTo(b.birthYear));
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
