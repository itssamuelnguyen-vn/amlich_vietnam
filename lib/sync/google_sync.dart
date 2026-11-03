import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/settings.dart';
import '../events/event.dart';
import '../events/event_store.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';

/// A writable calendar on the phone.
class PhoneCalendar {
  const PhoneCalendar({
    required this.id,
    required this.name,
    required this.account,
    required this.color,
    required this.isGoogle,
  });

  final int id;
  final String name;
  final String account;
  final int color;
  final bool isGoogle;

  String get label => account.isEmpty || account == name ? name : '$name · $account';
}

/// Mirrors the app's events into a calendar on the phone (normally the user's Google calendar) through the
/// "amlich/calendar" channel; see GoogleCalendarSync.kt. One-way: the app is the source of truth.
class GoogleSync extends ChangeNotifier {
  GoogleSync(this._events, this._settings);

  static const _channel = MethodChannel('amlich/calendar');

  /// Occurrences this far ahead are written; lunar recurrences cannot be expressed as calendar repeat rules.
  static const horizonYears = 2;

  final EventStore _events;
  final SettingsStore _settings;
  Timer? _debounce;
  int? _lastCalendarId;

  bool syncing = false;
  DateTime? lastSync;
  String? lastError;
  ({int added, int changed, int removed})? lastResult;

  bool get enabled => _settings.value.googleCalendarId != null;

  /// Syncs now if enabled, then after every event change and when the chosen calendar changes.
  void attach() {
    _lastCalendarId = _settings.value.googleCalendarId;
    _events.addListener(_schedule);
    _settings.addListener(() {
      if (_settings.value.googleCalendarId == _lastCalendarId) return;
      _lastCalendarId = _settings.value.googleCalendarId;
      _schedule();
    });
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      if (enabled) syncNow();
    });
  }

  Future<bool> requestPermission() async => await _invoke<bool>('requestPermission') ?? false;

  Future<List<PhoneCalendar>> calendars() async {
    final list = await _invoke<List<Object?>>('calendars') ?? [];
    return [
      for (final m in list.cast<Map<Object?, Object?>>())
        PhoneCalendar(
          id: (m['id']! as num).toInt(),
          name: m['name']! as String,
          account: m['account']! as String,
          color: (m['color']! as num).toInt(),
          isGoogle: m['google']! as bool,
        ),
    ];
  }

  Future<void> syncNow() async {
    final calendarId = _settings.value.googleCalendarId;
    if (calendarId == null || syncing) return;
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      final r = await _invoke<Map<Object?, Object?>>('sync', {
        'calendarId': calendarId,
        'items': jsonEncode(items(_events, today())),
      });
      if (r != null) {
        lastResult = (added: r['added']! as int, changed: r['changed']! as int, removed: r['removed']! as int);
        lastSync = DateTime.now();
      }
    } on PlatformException catch (e) {
      lastError = e.message ?? e.code;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Turns syncing off; with [removeEvents] the app's events are also deleted from the calendar.
  Future<void> disable({required bool removeEvents}) async {
    if (removeEvents) await _invoke<int>('clear');
    lastResult = null;
    lastSync = null;
    await _settings.update(_settings.value.copyWith(googleCalendarId: () => null, googleCalendarName: ''));
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null; // Not on Android (tests).
    }
  }

  /// Every occurrence from [today] to [horizonYears] ahead as `{"k": "<event id>|<date>", "t", "d", "n"}`.
  static List<Map<String, String>> items(EventStore store, DateTime today) {
    final until = DateTime(today.year + horizonYears, today.month, today.day);
    return [
      for (final e in store.events)
        for (final d in _occurrences(e, today, until))
          {'k': '${e.id}|${_iso(d)}', 't': e.title, 'd': _iso(d), 'n': describe(e, d)},
    ];
  }

  static Iterable<DateTime> _occurrences(Event e, DateTime from, DateTime until) sync* {
    var next = e.nextOccurrence(from);
    while (next != null && !next.isAfter(until)) {
      yield next;
      next = e.nextOccurrence(DateTime(next.year, next.month, next.day + 1));
    }
  }

  /// Calendar event description: the date rule, the lunar date, the note, and where to edit it.
  static String describe(Event e, DateTime date) {
    final lunar = solarToLunar(date);
    return [
      e.describe(),
      'Âm lịch: ${lunar.day}/${lunar.month}${lunar.isLeap ? ' nhuận' : ''} năm ${canChiYear(lunar.year)}',
      if (e.note.isNotEmpty) e.note,
      '— Tạo bởi app Âm lịch. Sửa hoặc xoá trong app; thay đổi ở đây sẽ bị ghi đè.',
    ].join('\n');
  }

  static String _iso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
}

class GoogleSyncScope extends InheritedNotifier<GoogleSync> {
  const GoogleSyncScope({super.key, required GoogleSync sync, required super.child}) : super(notifier: sync);

  static GoogleSync of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GoogleSyncScope>()!.notifier!;
}
