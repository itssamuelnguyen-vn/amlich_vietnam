import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_database.dart';
import 'data/people.dart';
import 'data/settings.dart';
import 'events/event_store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
import 'widget/widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  final events = EventStore(SqliteEventBackend());
  final settings = SettingsStore(SqliteSettingsBackend());
  final people = PeopleStore(SqlitePeopleBackend());
  await Future.wait([events.load(), settings.load(), people.load()]);
  WidgetBridge.attach(events, settings);
  runApp(AmLichApp(events: events, settings: settings, people: people));
}

class AmLichApp extends StatelessWidget {
  const AmLichApp({super.key, required this.events, required this.settings, required this.people});

  final EventStore events;
  final SettingsStore settings;
  final PeopleStore people;

  @override
  Widget build(BuildContext context) {
    return EventScope(
      store: events,
      child: PeopleScope(
        store: people,
        child: SettingsScope(
          store: settings,
          child: ListenableBuilder(
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
          ),
        ),
      ),
    );
  }
}
