import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'counters/counter.dart';
import 'data/app_database.dart';
import 'data/people.dart';
import 'data/settings.dart';
import 'events/event_store.dart';
import 'notes/day_notes.dart';
import 'screens/home_screen.dart';
import 'sync/google_sync.dart';
import 'theme.dart';
import 'widget/widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  final events = EventStore(SqliteEventBackend());
  final settings = SettingsStore(SqliteSettingsBackend());
  final people = PeopleStore(SqlitePeopleBackend());
  final counters = CounterStore(SqliteCounterBackend());
  final notes = NotesStore(SqliteNotesBackend());
  await Future.wait([events.load(), settings.load(), people.load(), counters.load(), notes.load()]);
  WidgetBridge.attach(events, settings, counters);
  final googleSync = GoogleSync(events, settings)..attach();
  runApp(
    AmLichApp(
      events: events,
      settings: settings,
      people: people,
      counters: counters,
      notes: notes,
      googleSync: googleSync,
    ),
  );
}

class AmLichApp extends StatelessWidget {
  const AmLichApp({
    super.key,
    required this.events,
    required this.settings,
    required this.people,
    required this.counters,
    required this.notes,
    required this.googleSync,
  });

  final EventStore events;
  final SettingsStore settings;
  final PeopleStore people;
  final CounterStore counters;
  final NotesStore notes;
  final GoogleSync googleSync;

  @override
  Widget build(BuildContext context) {
    Widget app = ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Âm lịch',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.value.themeMode,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // "Cỡ chữ" scales on top of the phone's own text size.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * settings.value.textScale)),
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
    app = GoogleSyncScope(sync: googleSync, child: app);
    app = SettingsScope(store: settings, child: app);
    app = CounterScope(store: counters, child: app);
    app = NotesScope(store: notes, child: app);
    app = PeopleScope(store: people, child: app);
    return EventScope(store: events, child: app);
  }
}
