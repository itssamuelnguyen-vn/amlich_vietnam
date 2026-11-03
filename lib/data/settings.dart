import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Holiday groups that can be shown or hidden.
enum HolidayKind {
  lunar('Lễ âm lịch truyền thống', 'Tết, rằm tháng Giêng, Giỗ Tổ, Vu Lan, Trung thu…'),
  vietnam('Ngày lễ Việt Nam (dương lịch)', '1/1, 30/4, 1/5, 2/9, 20/10, 20/11, 22/12'),
  international('Ngày quốc tế', '14/2, 8/3, 1/6, 24/12');

  const HolidayKind(this.label, this.examples);

  final String label;
  final String examples;
}

class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
    this.weekStartsMonday = true,
    this.holidayKinds = const {...HolidayKind.values},
    this.reminderHour = 7,
    this.reminderMinute = 0,
    this.lunarReminders = false,
    this.countdownEventId,
    this.googleCalendarId,
    this.googleCalendarName = '',
  });

  final ThemeMode themeMode;

  /// Multiplies the system text size: 1.0, 1.15 or 1.3.
  final double textScale;
  final bool weekStartsMonday;
  final Set<HolidayKind> holidayKinds;

  /// Time of day reminders are shown.
  final int reminderHour;
  final int reminderMinute;

  /// Remind the day before every mùng 1 and rằm (15th).
  final bool lunarReminders;

  /// Event the countdown widget counts down to; null means the next Tết.
  final int? countdownEventId;

  /// Phone calendar (usually a Google one) the events are mirrored into; null when syncing is off.
  final int? googleCalendarId;

  /// "Name · account" of [googleCalendarId], for display.
  final String googleCalendarName;

  Settings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? weekStartsMonday,
    Set<HolidayKind>? holidayKinds,
    int? reminderHour,
    int? reminderMinute,
    bool? lunarReminders,
    int? Function()? countdownEventId,
    int? Function()? googleCalendarId,
    String? googleCalendarName,
  }) => Settings(
    themeMode: themeMode ?? this.themeMode,
    textScale: textScale ?? this.textScale,
    weekStartsMonday: weekStartsMonday ?? this.weekStartsMonday,
    holidayKinds: holidayKinds ?? this.holidayKinds,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    lunarReminders: lunarReminders ?? this.lunarReminders,
    countdownEventId: countdownEventId != null ? countdownEventId() : this.countdownEventId,
    googleCalendarId: googleCalendarId != null ? googleCalendarId() : this.googleCalendarId,
    googleCalendarName: googleCalendarName ?? this.googleCalendarName,
  );

  Map<String, String> toMap() => {
    'theme_mode': themeMode.name,
    'text_scale': '$textScale',
    'week_starts_monday': '$weekStartsMonday',
    'holiday_kinds': holidayKinds.map((k) => k.name).join(','),
    'reminder_hour': '$reminderHour',
    'reminder_minute': '$reminderMinute',
    'lunar_reminders': '$lunarReminders',
    'countdown_event_id': '${countdownEventId ?? ''}',
    'google_calendar_id': '${googleCalendarId ?? ''}',
    'google_calendar_name': googleCalendarName,
  };

  /// Unknown or missing keys fall back to the defaults, so old backups and new settings both load.
  factory Settings.fromMap(Map<String, String> m) {
    const d = Settings();
    return Settings(
      themeMode: ThemeMode.values.asNameMap()[m['theme_mode']] ?? d.themeMode,
      textScale: double.tryParse(m['text_scale'] ?? '') ?? d.textScale,
      weekStartsMonday: m['week_starts_monday'] == null ? d.weekStartsMonday : m['week_starts_monday'] == 'true',
      holidayKinds: m['holiday_kinds'] == null
          ? d.holidayKinds
          : {for (final n in m['holiday_kinds']!.split(',')) ?HolidayKind.values.asNameMap()[n]},
      reminderHour: int.tryParse(m['reminder_hour'] ?? '') ?? d.reminderHour,
      reminderMinute: int.tryParse(m['reminder_minute'] ?? '') ?? d.reminderMinute,
      lunarReminders: m['lunar_reminders'] == 'true',
      countdownEventId: int.tryParse(m['countdown_event_id'] ?? ''),
      googleCalendarId: int.tryParse(m['google_calendar_id'] ?? ''),
      googleCalendarName: m['google_calendar_name'] ?? '',
    );
  }
}

abstract class SettingsBackend {
  Future<Map<String, String>> load();

  Future<void> save(Map<String, String> values);
}

class SqliteSettingsBackend implements SettingsBackend {
  @override
  Future<Map<String, String>> load() async => {
    for (final row in await (await AppDatabase.instance).query('settings'))
      row['key'] as String: row['value'] as String,
  };

  @override
  Future<void> save(Map<String, String> values) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      for (final e in values.entries) {
        await txn.insert('settings', {'key': e.key, 'value': e.value}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}

class MemorySettingsBackend implements SettingsBackend {
  final _values = <String, String>{};

  @override
  Future<Map<String, String>> load() async => Map.of(_values);

  @override
  Future<void> save(Map<String, String> values) async => _values.addAll(values);
}

class SettingsStore extends ChangeNotifier {
  SettingsStore(this._backend);

  final SettingsBackend _backend;
  Settings _value = const Settings();

  Settings get value => _value;

  Future<void> load() async {
    _value = Settings.fromMap(await _backend.load());
    notifyListeners();
  }

  Future<void> update(Settings s) async {
    _value = s;
    notifyListeners();
    await _backend.save(s.toMap());
  }
}

class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({super.key, required SettingsStore store, required super.child}) : super(notifier: store);

  static SettingsStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
