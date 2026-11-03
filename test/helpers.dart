import 'package:amlich_vietnam/counters/counter.dart';
import 'package:amlich_vietnam/data/people.dart';
import 'package:amlich_vietnam/data/settings.dart';
import 'package:amlich_vietnam/events/event.dart';
import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/main.dart';
import 'package:amlich_vietnam/notes/day_notes.dart';
import 'package:amlich_vietnam/sync/google_sync.dart';
import 'package:amlich_vietnam/weather/weather.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole app on in-memory stores.
Future<AmLichApp> testApp({
  List<Event> events = const [],
  List<Person> people = const [],
  List<DayCounter> counters = const [],
}) async {
  final eventStore = EventStore(MemoryEventBackend(events));
  final settings = SettingsStore(MemorySettingsBackend());
  final peopleStore = PeopleStore(MemoryPeopleBackend());
  final counterStore = CounterStore(MemoryCounterBackend(counters));
  final notes = NotesStore(MemoryNotesBackend());
  await Future.wait([eventStore.load(), settings.load(), peopleStore.load(), counterStore.load(), notes.load()]);
  for (final p in people) {
    await peopleStore.add(p);
  }
  return AmLichApp(
    events: eventStore,
    settings: settings,
    people: peopleStore,
    counters: counterStore,
    notes: notes,
    // No network in tests: the weather card shows its retry state.
    weather: WeatherService(fetch: (_) async => throw const SocketException('offline')),
    googleSync: GoogleSync(eventStore, settings),
  );
}

/// A 360×780 dp phone screen.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
