// Folder: lib/
// File: main.dart
// Version: v1.3
// Change summary:
// - Fixed CarDiaryApp repository field wiring.
// - First-time users land on SetupScreen.
// - Returning users land in the main app shell.
// - Uses SqliteCarRepository consistently.

import 'package:flutter/material.dart';

import 'models/car_models.dart';
import 'repository/car_repository.dart';
import 'screens/history_screen.dart';
import 'screens/log_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/status_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final CarRepository repository = SqliteCarRepository();
  final UserSettings? settings = await repository.getSettings();

  runApp(
    CarDiaryApp(
      repository: repository,
      hasSettings: settings != null,
    ),
  );
}

class CarDiaryApp extends StatefulWidget {
  final CarRepository repository;
  final bool hasSettings;

  const CarDiaryApp({
    super.key,
    required this.repository,
    required this.hasSettings,
  });

  @override
  State<CarDiaryApp> createState() => _CarDiaryAppState();
}

class _CarDiaryAppState extends State<CarDiaryApp> {
  late bool _hasSettings;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _hasSettings = widget.hasSettings;
  }

  void _refresh() {
    setState(() {});
  }

  void _completeSetup() {
    setState(() {
      _hasSettings = true;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = <Widget>[
      StatusScreen(repository: widget.repository),
      LogScreen(
        repository: widget.repository,
        onSaved: _refresh,
      ),
      HistoryScreen(repository: widget.repository),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Car Diary',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _hasSettings
          ? Scaffold(
        appBar: AppBar(
          title: const Text('Car Diary'),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.speed),
              label: 'Status',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add),
              label: 'Log',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
          ],
        ),
      )
          : SetupScreen(
        repository: widget.repository,
        onSaved: _completeSetup,
      ),
    );
  }
}