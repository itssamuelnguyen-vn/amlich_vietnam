import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../lunar/lunar_calendar.dart';
import 'event.dart';

/// Persistence behind [EventStore], so tests can swap SQLite for memory.
abstract class EventBackend {
  Future<List<Event>> loadAll();

  /// Returns the new row id.
  Future<int> insert(Event e);

  Future<void> update(Event e);

  Future<void> delete(int id);
}

class SqliteEventBackend implements EventBackend {
  Future<Database> get _database => AppDatabase.instance;

  @override
  Future<List<Event>> loadAll() async => [
    for (final row in await (await _database).query('events')) Event.fromMap(row),
  ];

  @override
  Future<int> insert(Event e) async => (await _database).insert('events', e.toMap()..remove('id'));

  @override
  Future<void> update(Event e) async =>
      (await _database).update('events', e.toMap()..remove('id'), where: 'id = ?', whereArgs: [e.id]);

  @override
  Future<void> delete(int id) async => (await _database).delete('events', where: 'id = ?', whereArgs: [id]);
}

class MemoryEventBackend implements EventBackend {
  MemoryEventBackend([List<Event> initial = const []]) {
    for (final e in initial) {
      _rows[++_nextId] = e.copyWith(id: _nextId);
    }
  }

  final _rows = <int, Event>{};
  var _nextId = 0;

  @override
  Future<List<Event>> loadAll() async => _rows.values.toList();

  @override
  Future<int> insert(Event e) async {
    _rows[++_nextId] = e.copyWith(id: _nextId);
    return _nextId;
  }

  @override
  Future<void> update(Event e) async => _rows[e.id!] = e;

  @override
  Future<void> delete(int id) async => _rows.remove(id);
}

/// An event with the date it next happens on.
typedef Occurrence = ({Event event, DateTime date});

/// All events, kept in memory (a personal calendar holds a few hundred at most) and written through to the backend.
class EventStore extends ChangeNotifier {
  EventStore(this._backend);

  final EventBackend _backend;
  List<Event> _events = [];

  List<Event> get events => List.unmodifiable(_events);

  Future<void> load() async {
    _events = await _backend.loadAll();
    notifyListeners();
  }

  /// Inserts [e] when it has no id yet, otherwise updates it.
  Future<Event> save(Event e) async {
    if (e.id == null) {
      final saved = e.copyWith(id: await _backend.insert(e));
      _events = [..._events, saved];
      notifyListeners();
      return saved;
    }
    await _backend.update(e);
    _events = [for (final x in _events) x.id == e.id ? e : x];
    notifyListeners();
    return e;
  }

  Future<void> delete(Event e) async {
    await _backend.delete(e.id!);
    _events = [
      for (final x in _events)
        if (x.id != e.id) x,
    ];
    notifyListeners();
  }

  /// Adds [incoming] (from a backup). With [replace] every current event is deleted first; otherwise events equal
  /// to an existing one (same [key]) are skipped. Returns how many were added.
  Future<int> import(List<Event> incoming, {required bool replace, required String Function(Event) key}) async {
    if (replace) {
      for (final e in _events) {
        await _backend.delete(e.id!);
      }
      _events = [];
    }
    final seen = {for (final e in _events) key(e)};
    final added = <Event>[];
    for (final e in incoming) {
      if (!seen.add(key(e))) continue;
      added.add(e.copyWith(id: await _backend.insert(e)));
    }
    _events = [..._events, ...added];
    notifyListeners();
    return added.length;
  }

  /// Events falling on [date]; [lunar] must be `solarToLunar(date)`.
  List<Event> on(DateTime date, LunarDate lunar) => [
    for (final e in _events)
      if (e.occursOn(date, lunar)) e,
  ];

  /// Events with an occurrence on or after [from], soonest first.
  List<Occurrence> upcoming(DateTime from) {
    final list = <Occurrence>[
      for (final e in _events)
        if (e.nextOccurrence(from) case final d?) (event: e, date: d),
    ];
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// One-off events that are over, latest first.
  List<Event> past(DateTime from) {
    final list = [
      for (final e in _events)
        if (e.repeat == Repeat.none && e.start.isBefore(from)) e,
    ];
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }
}

/// Gives the widget tree access to the [EventStore] and rebuilds dependents when it changes.
class EventScope extends InheritedNotifier<EventStore> {
  const EventScope({super.key, required EventStore store, required super.child}) : super(notifier: store);

  static EventStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EventScope>()!.notifier!;
}
