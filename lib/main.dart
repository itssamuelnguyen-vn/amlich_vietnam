import 'package:flutter/material.dart';

import 'screens/calendar_screen.dart';
import 'theme.dart';

void main() => runApp(const AmLichApp());

class AmLichApp extends StatelessWidget {
  const AmLichApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Âm lịch',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const CalendarScreen(),
    );
  }
}
