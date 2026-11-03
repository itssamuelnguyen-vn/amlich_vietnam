import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../lunar/format.dart';

/// "yyyy-MM-dd", the key notes and to-dos are stored under.
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

class Todo {
  const Todo({this.id, required this.date, required this.text, this.done = false});

  final int? id;

  /// [dayKey] of the day it belongs to.
  final String date;
  final String text;
  final bool done;

  Todo copyWith({int? id, bool? done}) => Todo(id: id ?? this.id, date: date, text: text, done: done ?? this.done);

  Map<String, Object?> toMap() => {'id': id, 'date': date, 'text': text, 'done': done ? 1 : 0};

  factory Todo.fromMap(Map<String, Object?> m) =>
      Todo(id: m['id'] as int?, date: m['date'] as String, text: m['text'] as String, done: m['done'] == 1);
}

abstract class NotesBackend {
  Future<Map<String, String>> loadNotes();

  Future<List<Todo>> loadTodos();

  /// Empty [text] deletes the note.
  Future<void> saveNote(String date, String text);

  Future<int> insertTodo(Todo t);

  Future<void> updateTodo(Todo t);

  Future<void> deleteTodo(int id);
}

class SqliteNotesBackend implements NotesBackend {
  @override
  Future<Map<String, String>> loadNotes() async => {
    for (final r in await (await AppDatabase.instance).query('notes')) r['date'] as String: r['text'] as String,
  };

  @override
  Future<List<Todo>> loadTodos() async => [
    for (final r in await (await AppDatabase.instance).query('todos', orderBy: 'id')) Todo.fromMap(r),
  ];

  @override
  Future<void> saveNote(String date, String text) async {
    final db = await AppDatabase.instance;
    if (text.isEmpty) {
      await db.delete('notes', where: 'date = ?', whereArgs: [date]);
    } else {
      await db.insert('notes', {'date': date, 'text': text}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<int> insertTodo(Todo t) async => (await AppDatabase.instance).insert('todos', t.toMap()..remove('id'));

  @override
  Future<void> updateTodo(Todo t) async =>
      (await AppDatabase.instance).update('todos', t.toMap()..remove('id'), where: 'id = ?', whereArgs: [t.id]);

  @override
  Future<void> deleteTodo(int id) async =>
      (await AppDatabase.instance).delete('todos', where: 'id = ?', whereArgs: [id]);
}

class MemoryNotesBackend implements NotesBackend {
  final _notes = <String, String>{};
  final _todos = <int, Todo>{};
  var _nextId = 0;

  @override
  Future<Map<String, String>> loadNotes() async => Map.of(_notes);

  @override
  Future<List<Todo>> loadTodos() async => _todos.values.toList();

  @override
  Future<void> saveNote(String date, String text) async => text.isEmpty ? _notes.remove(date) : _notes[date] = text;

  @override
  Future<int> insertTodo(Todo t) async {
    _todos[++_nextId] = t.copyWith(id: _nextId);
    return _nextId;
  }

  @override
  Future<void> updateTodo(Todo t) async => _todos[t.id!] = t;

  @override
  Future<void> deleteTodo(int id) async => _todos.remove(id);
}

/// A note and a to-do list for any day.
class NotesStore extends ChangeNotifier {
  NotesStore(this._backend);

  final NotesBackend _backend;
  Map<String, String> _notes = {};
  List<Todo> _todos = [];

  Map<String, String> get notes => Map.unmodifiable(_notes);
  List<Todo> get todos => List.unmodifiable(_todos);

  Future<void> load() async {
    _notes = await _backend.loadNotes();
    _todos = await _backend.loadTodos();
    notifyListeners();
  }

  String noteOf(DateTime d) => _notes[dayKey(d)] ?? '';

  List<Todo> todosOf(DateTime d) => [
    for (final t in _todos)
      if (t.date == dayKey(d)) t,
  ];

  /// Whether [d] has a note or any to-do (for the calendar dot).
  bool hasContent(DateTime d) => _notes.containsKey(dayKey(d)) || _todos.any((t) => t.date == dayKey(d));

  Future<void> setNote(DateTime d, String text) async {
    final key = dayKey(d);
    final trimmed = text.trim();
    if ((_notes[key] ?? '') == trimmed) return;
    if (trimmed.isEmpty) {
      _notes.remove(key);
    } else {
      _notes[key] = trimmed;
    }
    notifyListeners();
    await _backend.saveNote(key, trimmed);
  }

  Future<void> addTodo(DateTime d, String text) async {
    if (text.trim().isEmpty) return;
    final t = Todo(date: dayKey(d), text: text.trim());
    _todos = [..._todos, t.copyWith(id: await _backend.insertTodo(t))];
    notifyListeners();
  }

  Future<void> toggle(Todo t) async {
    final updated = t.copyWith(done: !t.done);
    _todos = [for (final x in _todos) x.id == t.id ? updated : x];
    notifyListeners();
    await _backend.updateTodo(updated);
  }

  Future<void> removeTodo(Todo t) async {
    _todos = [
      for (final x in _todos)
        if (x.id != t.id) x,
    ];
    notifyListeners();
    await _backend.deleteTodo(t.id!);
  }

  /// Restores from a backup: notes are merged (a backup's note wins only on empty days unless [replace]); to-dos are
  /// added, skipping exact duplicates.
  Future<void> import(Map<String, String> notes, List<Todo> todos, {required bool replace}) async {
    if (replace) {
      for (final key in _notes.keys.toList()) {
        await _backend.saveNote(key, '');
      }
      for (final t in _todos) {
        await _backend.deleteTodo(t.id!);
      }
      _notes = {};
      _todos = [];
    }
    for (final e in notes.entries) {
      if (_notes.containsKey(e.key)) continue;
      _notes[e.key] = e.value;
      await _backend.saveNote(e.key, e.value);
    }
    final seen = {for (final t in _todos) '${t.date}|${t.text}'};
    for (final t in todos) {
      if (!seen.add('${t.date}|${t.text}')) continue;
      _todos.add(t.copyWith(id: await _backend.insertTodo(t)));
    }
    notifyListeners();
  }
}

class NotesScope extends InheritedNotifier<NotesStore> {
  const NotesScope({super.key, required NotesStore store, required super.child}) : super(notifier: store);

  static NotesStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<NotesScope>()!.notifier!;
}
