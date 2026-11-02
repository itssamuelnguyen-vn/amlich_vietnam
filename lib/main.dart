import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'events/event_store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
import 'widget/widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = EventStore(SqliteEventBackend());
  await store.load();
  WidgetBridge.attach(store);
  runApp(AmLichApp(store: store));
}

class AmLichApp extends StatelessWidget {
  const AmLichApp({super.key, required this.store});

  final EventStore store;

  @override
  Widget build(BuildContext context) {
    return EventScope(
      store: store,
      child: MaterialApp(
        title: 'Âm lịch',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeScreen(),
      ),
    );
  }
}
