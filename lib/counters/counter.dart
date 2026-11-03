import 'package:flutter/widgets.dart';

import '../data/app_database.dart';
import '../lunar/format.dart';

/// Emoji offered for a counter.
const counterEmoji = ['❤️', '💑', '💍', '👶', '🎂', '🎓', '🏠', '💼', '🐶', '✈️', '🚭', '💪', '🙏', '⭐'];

/// Day counter, like "together for 1,234 days": counts days since [date], or down to it when it is in the future.
class DayCounter {
  const DayCounter({
    this.id,
    required this.title,
    required this.date,
    this.emoji = '❤️',
    this.color = 0,
    this.firstDayIsOne = true,
    this.notify = true,
    this.photo = '',
  });

  final int? id;
  final String title;
  final DateTime date;
  final String emoji;

  /// Index into eventColors.
  final int color;

  /// Love-day apps count the starting day as day 1; otherwise it is day 0.
  final bool firstDayIsOne;

  /// Notify on milestone days.
  final bool notify;

  /// Path of a background photo in the app's storage, or empty.
  final String photo;

  bool isFuture(DateTime today) => date.isAfter(today);

  /// Days counted on [today]: since [date] (with [firstDayIsOne]) or, for a future date, days left.
  int daysOn(DateTime today) {
    final d = daysBetween(date, today);
    return d < 0 ? -d : d + (firstDayIsOne ? 1 : 0);
  }

  /// The day number shown on [day] (only meaningful on or after [date]).
  int dayNumberOn(DateTime day) => daysBetween(date, day) + (firstDayIsOne ? 1 : 0);

  /// The date that shows day number [n].
  DateTime dateOfDay(int n) => DateTime(date.year, date.month, date.day + n - (firstDayIsOne ? 1 : 0));

  /// Milestones after [today] (exclusive) up to [limit] of them, soonest first: day 100, 200 … 1000, every 1000 after,
  /// and each yearly anniversary of [date].
  List<Milestone> upcomingMilestones(DateTime today, {int limit = 6}) {
    if (isFuture(today)) return [];
    final found = <Milestone>[];
    final current = dayNumberOn(today);
    for (var n = 100; found.length < limit * 2 && n <= current + 40000; n += n < 1000 ? 100 : 1000) {
      if (n > current) found.add(Milestone(dateOfDay(n), '$n ngày'));
    }
    for (var y = 1; y <= 120 && found.where((m) => m.isAnniversary).length < limit; y++) {
      final d = _anniversary(y);
      if (d.isAfter(today)) found.add(Milestone(d, 'Kỷ niệm $y năm', isAnniversary: true));
    }
    found.sort((a, b) => a.date.compareTo(b.date));
    return found.take(limit).toList();
  }

  /// The [years]-th anniversary; 29/02 falls on 28/02 in common years.
  DateTime _anniversary(int years) {
    final y = date.year + years;
    return DateTime(y, date.month, date.day.clamp(1, daysInMonth(y, date.month)));
  }

  DayCounter copyWith({
    int? id,
    String? title,
    DateTime? date,
    String? emoji,
    int? color,
    bool? firstDayIsOne,
    bool? notify,
    String? photo,
  }) => DayCounter(
    id: id ?? this.id,
    title: title ?? this.title,
    date: date ?? this.date,
    emoji: emoji ?? this.emoji,
    color: color ?? this.color,
    firstDayIsOne: firstDayIsOne ?? this.firstDayIsOne,
    notify: notify ?? this.notify,
    photo: photo ?? this.photo,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'date': '${date.year}-${two(date.month)}-${two(date.day)}',
    'emoji': emoji,
    'color': color,
    'first_day_is_one': firstDayIsOne ? 1 : 0,
    'notify': notify ? 1 : 0,
    'photo': photo,
  };

  factory DayCounter.fromMap(Map<String, Object?> m) {
    final date = DateTime.parse(m['date'] as String);
    return DayCounter(
      id: m['id'] as int?,
      title: m['title'] as String,
      date: DateTime(date.year, date.month, date.day),
      emoji: (m['emoji'] as String?) ?? '❤️',
      color: (m['color'] as int?) ?? 0,
      firstDayIsOne: m['first_day_is_one'] != 0,
      notify: m['notify'] != 0,
      photo: (m['photo'] as String?) ?? '',
    );
  }
}

class Milestone {
  const Milestone(this.date, this.label, {this.isAnniversary = false});

  final DateTime date;
  final String label;
  final bool isAnniversary;
}

/// "1.234" with Vietnamese thousands separators.
String formatCount(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

abstract class CounterBackend {
  Future<List<DayCounter>> loadAll();

  Future<int> insert(DayCounter c);

  Future<void> update(DayCounter c);

  Future<void> delete(int id);
}

class SqliteCounterBackend implements CounterBackend {
  @override
  Future<List<DayCounter>> loadAll() async => [
    for (final row in await (await AppDatabase.instance).query('counters', orderBy: 'id')) DayCounter.fromMap(row),
  ];

  @override
  Future<int> insert(DayCounter c) async => (await AppDatabase.instance).insert('counters', c.toMap()..remove('id'));

  @override
  Future<void> update(DayCounter c) async =>
      (await AppDatabase.instance).update('counters', c.toMap()..remove('id'), where: 'id = ?', whereArgs: [c.id]);

  @override
  Future<void> delete(int id) async =>
      (await AppDatabase.instance).delete('counters', where: 'id = ?', whereArgs: [id]);
}

class MemoryCounterBackend implements CounterBackend {
  MemoryCounterBackend([List<DayCounter> initial = const []]) {
    for (final c in initial) {
      _rows[++_nextId] = c.copyWith(id: _nextId);
    }
  }

  final _rows = <int, DayCounter>{};
  var _nextId = 0;

  @override
  Future<List<DayCounter>> loadAll() async => _rows.values.toList();

  @override
  Future<int> insert(DayCounter c) async {
    _rows[++_nextId] = c.copyWith(id: _nextId);
    return _nextId;
  }

  @override
  Future<void> update(DayCounter c) async => _rows[c.id!] = c;

  @override
  Future<void> delete(int id) async => _rows.remove(id);
}

class CounterStore extends ChangeNotifier {
  CounterStore(this._backend);

  final CounterBackend _backend;
  List<DayCounter> _counters = [];

  List<DayCounter> get counters => List.unmodifiable(_counters);

  DayCounter? byId(int? id) => _counters.where((c) => c.id == id).firstOrNull;

  Future<void> load() async {
    _counters = await _backend.loadAll();
    notifyListeners();
  }

  Future<DayCounter> save(DayCounter c) async {
    if (c.id == null) {
      final saved = c.copyWith(id: await _backend.insert(c));
      _counters = [..._counters, saved];
      notifyListeners();
      return saved;
    }
    await _backend.update(c);
    _counters = [for (final x in _counters) x.id == c.id ? c : x];
    notifyListeners();
    return c;
  }

  Future<void> delete(DayCounter c) async {
    await _backend.delete(c.id!);
    _counters = [
      for (final x in _counters)
        if (x.id != c.id) x,
    ];
    notifyListeners();
  }

  /// Adds counters from a backup (without photos, which stay on the old phone); [replace] clears the list first.
  Future<void> import(List<DayCounter> incoming, {required bool replace}) async {
    if (replace) {
      for (final c in _counters) {
        await _backend.delete(c.id!);
      }
      _counters = [];
    }
    final seen = {for (final c in _counters) '${c.title}|${c.date}'};
    for (final c in incoming) {
      if (!seen.add('${c.title}|${c.date}')) continue;
      final fresh = c.copyWith(photo: '');
      _counters.add(fresh.copyWith(id: await _backend.insert(fresh)));
    }
    notifyListeners();
  }
}

class CounterScope extends InheritedNotifier<CounterStore> {
  const CounterScope({super.key, required CounterStore store, required super.child}) : super(notifier: store);

  static CounterStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CounterScope>()!.notifier!;
}
