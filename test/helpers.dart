import 'package:amlich_vietnam/data/people.dart';
import 'package:amlich_vietnam/data/settings.dart';
import 'package:amlich_vietnam/events/event.dart';
import 'package:amlich_vietnam/events/event_store.dart';
import 'package:amlich_vietnam/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole app on in-memory stores.
Future<AmLichApp> testApp({List<Event> events = const [], List<Person> people = const []}) async {
  final eventStore = EventStore(MemoryEventBackend(events));
  final settings = SettingsStore(MemorySettingsBackend());
  final peopleStore = PeopleStore(MemoryPeopleBackend());
  await Future.wait([eventStore.load(), settings.load(), peopleStore.load()]);
  for (final p in people) {
    await peopleStore.add(p);
  }
  return AmLichApp(events: eventStore, settings: settings, people: peopleStore);
}

/// A 360×780 dp phone screen.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
