import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's SQLite database, opened once.
///
/// Version 1: events. Version 2: events.remind_days, settings (key/value) and people (family ages).
class AppDatabase {
  AppDatabase._();

  static Future<Database>? _db;

  static Future<Database> get instance => _db ??= openDatabase(
    p.join(_path ?? '', 'amlich.db'),
    version: 2,
    onCreate: (db, version) async {
      await db.execute(_events);
      await _createV2(db);
    },
    onUpgrade: (db, from, to) async {
      if (from < 2) {
        await db.execute('ALTER TABLE events ADD COLUMN remind_days INTEGER NOT NULL DEFAULT -1');
        await _createV2(db);
      }
    },
  );

  static String? _path;

  /// Must run before [instance] is first used.
  static Future<void> init() async => _path = await getDatabasesPath();

  static const _events = '''
    CREATE TABLE events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      calendar TEXT NOT NULL,
      day INTEGER NOT NULL,
      month INTEGER NOT NULL,
      year INTEGER NOT NULL,
      leap INTEGER NOT NULL DEFAULT 0,
      repeat TEXT NOT NULL,
      color INTEGER NOT NULL DEFAULT 0,
      remind_days INTEGER NOT NULL DEFAULT -1
    )''';

  static Future<void> _createV2(Database db) async {
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute(
      'CREATE TABLE people(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, birth_year INTEGER NOT NULL)',
    );
  }
}
