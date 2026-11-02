import 'package:flutter/material.dart';

import '../lunar/format.dart';
import '../widget/widget_bridge.dart';
import 'calendar_screen.dart';
import 'event_editor.dart';
import 'events_screen.dart';
import 'tools_screen.dart';

/// The three tabs: calendar, events, tools.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _calendar = GlobalKey<CalendarScreenState>();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // A tap on a home-screen widget day opens the calendar on that day.
    WidgetsBinding.instance.addPostFrameCallback((_) => WidgetBridge.listenForDates(_showDate));
  }

  void _showDate(DateTime date) {
    setState(() => _tab = 0);
    _calendar.currentState?.showDate(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          CalendarScreen(key: _calendar),
          EventsScreen(onShowDate: _showDate),
          ToolsScreen(onShowDate: _showDate),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              heroTag: 'add-event-calendar',
              tooltip: 'Thêm sự kiện',
              onPressed: () => openEventEditor(context, date: _calendar.currentState?.selected ?? today()),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Sự kiện',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Tiện ích',
          ),
        ],
      ),
    );
  }
}
