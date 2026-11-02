import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/settings.dart';
import '../events/event.dart';
import '../events/event_store.dart';
import '../lunar/format.dart';
import '../lunar/holidays.dart';
import '../lunar/lunar_calendar.dart';

/// Talks to the Android side over the "amlich/widget" channel (see MainActivity.kt).
///
/// The home-screen widgets and reminders compute lunar dates natively; from here they only need the event
/// occurrences, a few settings and the countdown target, pushed on start-up and whenever events or settings change.
class WidgetBridge {
  WidgetBridge._();

  static const _channel = MethodChannel('amlich/widget');

  /// Pushes now and after every change to [events] or [settings].
  static void attach(EventStore events, SettingsStore settings) {
    void push() => _invoke('sync', syncPayload(events, settings.value, today()));
    push();
    events.addListener(push);
    settings.addListener(push);
  }

  /// Calls [onShowDate] with the date a widget or notification tap opened the app on, now (cold start) and later.
  static Future<void> listenForDates(ValueChanged<DateTime> onShowDate) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'showDate') return;
      if (DateTime.tryParse(call.arguments as String) case final d?) onShowDate(d);
    });
    if (DateTime.tryParse(await _invoke<String>('takeLaunchDate') ?? '') case final d?) onShowDate(d);
  }

  /// Asks for the notification permission (Android 13+); true when notifications can be shown.
  static Future<bool> requestNotificationPermission() async =>
      await _invoke<bool>('requestNotificationPermission') ?? true;

  static Future<bool> notificationsEnabled() async => await _invoke<bool>('notificationsEnabled') ?? true;

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null; // Not on Android (tests).
    }
  }

  @visibleForTesting
  static Map<String, String> syncPayload(EventStore events, Settings settings, DateTime today) => {
    'occurrences': jsonEncode(occurrencesJson(events, today)),
    'settings': jsonEncode({
      'weekStartsMonday': settings.weekStartsMonday,
      'holidayKinds': [for (final k in settings.holidayKinds) k.name],
      'reminderHour': settings.reminderHour,
      'reminderMinute': settings.reminderMinute,
      'lunarReminders': settings.lunarReminders,
    }),
    'countdown': jsonEncode(countdownJson(events, settings, today)),
  };

  /// Occurrences from the first day of last month to a year after [today], soonest first, as
  /// `{"t": title, "d": "yyyy-MM-dd", "c": ARGB colour, "r": days before to remind or -1}`.
  @visibleForTesting
  static List<Map<String, Object>> occurrencesJson(EventStore store, DateTime today) {
    final from = DateTime(today.year, today.month - 1, 1);
    final until = DateTime(today.year + 1, today.month, today.day);
    final list = <({Event event, DateTime date})>[];
    for (final e in store.events) {
      var next = e.nextOccurrence(from);
      for (var n = 0; next != null && !next.isAfter(until) && n < 40; n++) {
        list.add((event: e, date: next));
        next = e.nextOccurrence(DateTime(next.year, next.month, next.day + 1));
      }
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return [
      for (final o in list.take(500))
        {'t': o.event.title, 'd': _iso(o.date), 'c': o.event.colorValue.toARGB32(), 'r': o.event.remindDays},
    ];
  }

  /// What the countdown widget counts to: the chosen event, or the next Tết. Several dates so the widget can move on
  /// to the next occurrence by itself after the first one passes.
  @visibleForTesting
  static Map<String, Object> countdownJson(EventStore store, Settings settings, DateTime today) {
    final event = store.events.where((e) => e.id == settings.countdownEventId).firstOrNull;
    if (event == null) {
      final tet = nextTet(today);
      final following = nextTet(DateTime(tet.year, tet.month, tet.day + 1));
      return {
        'title': 'Tết ${canChiYear(solarToLunar(tet).year)}',
        'dates': [_iso(tet), _iso(following)],
      };
    }
    final dates = <String>[];
    var next = event.nextOccurrence(today);
    while (next != null && dates.length < 24) {
      dates.add(_iso(next));
      next = event.nextOccurrence(DateTime(next.year, next.month, next.day + 1));
    }
    return {'title': event.title, 'dates': dates};
  }

  static String _iso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
}
