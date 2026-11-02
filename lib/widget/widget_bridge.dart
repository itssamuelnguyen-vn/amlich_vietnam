import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../events/event_store.dart';
import '../lunar/format.dart';

/// Talks to the Android home-screen widgets over the "amlich/widget" channel (see MainActivity.kt).
///
/// The widgets compute lunar dates natively, so they only need the event occurrences from here; they are pushed on
/// start-up and whenever events change.
class WidgetBridge {
  WidgetBridge._();

  static const _channel = MethodChannel('amlich/widget');

  /// Pushes occurrences now and after every change to [store].
  static void attach(EventStore store) {
    _push(store);
    store.addListener(() => _push(store));
  }

  /// Calls [onShowDate] with the date a widget tap opened the app on, now (cold start) and later (app running).
  static Future<void> listenForDates(ValueChanged<DateTime> onShowDate) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'showDate') return;
      if (DateTime.tryParse(call.arguments as String) case final d?) onShowDate(d);
    });
    try {
      final launch = await _channel.invokeMethod<String>('takeLaunchDate');
      if (DateTime.tryParse(launch ?? '') case final d?) onShowDate(d);
    } on MissingPluginException {
      // Not on Android (tests).
    }
  }

  static Future<void> _push(EventStore store) async {
    try {
      await _channel.invokeMethod('updateWidgets', {'occurrences': jsonEncode(occurrencesJson(store, today()))});
    } on MissingPluginException {
      // Not on Android (tests).
    }
  }

  /// Occurrences from the first day of last month to a year after [today], soonest first, as
  /// `{"t": title, "d": "yyyy-MM-dd", "c": ARGB colour}`; the month widget shows dots for them.
  @visibleForTesting
  static List<Map<String, Object>> occurrencesJson(EventStore store, DateTime today) {
    final from = DateTime(today.year, today.month - 1, 1);
    final until = DateTime(today.year + 1, today.month, today.day);
    final list = <({String title, DateTime date, int color})>[];
    for (final e in store.events) {
      var next = e.nextOccurrence(from);
      for (var n = 0; next != null && !next.isAfter(until) && n < 40; n++) {
        list.add((title: e.title, date: next, color: e.colorValue.toARGB32()));
        next = e.nextOccurrence(DateTime(next.year, next.month, next.day + 1));
      }
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return [
      for (final o in list.take(500))
        {'t': o.title, 'd': '${o.date.year}-${two(o.date.month)}-${two(o.date.day)}', 'c': o.color},
    ];
  }
}
