import 'dart:convert';

import 'package:flutter/services.dart';

import '../counters/counter.dart';
import '../events/event.dart';
import 'people.dart';
import 'settings.dart';

/// Contents of a backup file.
class BackupData {
  const BackupData({required this.events, required this.people, this.counters = const [], this.settings});

  final List<Event> events;
  final List<Person> people;
  final List<DayCounter> counters;
  final Settings? settings;
}

/// Backup files are JSON: `{"app": "amlich_vietnam", "version": 1, "events": [...], "people": [...],
/// "counters": [...], "settings": {...}}`.
class Backup {
  Backup._();

  static const _app = 'amlich_vietnam';

  static String encode(BackupData data, {DateTime? now}) => const JsonEncoder.withIndent('  ').convert({
    'app': _app,
    'version': 1,
    'exported_at': (now ?? DateTime.now()).toIso8601String(),
    'events': [for (final e in data.events) e.toMap()..remove('id')],
    'people': [for (final p in data.people) p.toMap()..remove('id')],
    // Photos stay on the phone; only their absence travels.
    'counters': [
      for (final c in data.counters)
        c.toMap()
          ..remove('id')
          ..remove('photo'),
    ],
    'settings': ?data.settings?.toMap(),
  });

  /// Throws [FormatException] when [text] is not a backup of this app.
  static BackupData decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('File không phải JSON');
    }
    if (json is! Map<String, Object?> || json['app'] != _app) {
      throw const FormatException('File không phải bản sao lưu của app Âm lịch');
    }
    try {
      return BackupData(
        events: [for (final m in json['events'] as List? ?? []) Event.fromMap(Map<String, Object?>.from(m as Map))],
        people: [for (final m in json['people'] as List? ?? []) Person.fromMap(Map<String, Object?>.from(m as Map))],
        counters: [
          for (final m in json['counters'] as List? ?? []) DayCounter.fromMap(Map<String, Object?>.from(m as Map)),
        ],
        settings: json['settings'] is Map
            ? Settings.fromMap({for (final e in (json['settings'] as Map).entries) '${e.key}': '${e.value}'})
            : null,
      );
    } on Object {
      throw const FormatException('File sao lưu bị hỏng');
    }
  }

  /// Key used to skip events that already exist when merging a backup.
  static String eventKey(Event e) =>
      [e.title, e.calendar.name, e.day, e.month, e.year, e.leap, e.repeat.name].join('|');
}

/// Saves and opens files through Android's document picker (MainActivity.kt, channel "amlich/files"), so the user
/// can pick Google Drive, Downloads and so on.
class FilePicker {
  FilePicker._();

  static const _channel = MethodChannel('amlich/files');

  /// Returns false when the user cancels.
  static Future<bool> saveText(String fileName, String text) async =>
      await _channel.invokeMethod<bool>('saveText', {'name': fileName, 'text': text}) ?? false;

  /// Returns null when the user cancels.
  static Future<String?> openText() => _channel.invokeMethod<String>('openText');

  /// Lets the user pick a photo, copies it into the app's storage and returns its path; null when cancelled.
  static Future<String?> pickImage() => _channel.invokeMethod<String>('pickImage');
}
