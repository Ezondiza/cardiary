// Folder: lib/repository/
// File: database_helper.dart
// Version: v1.5
// Change summary:
// - Adds quantity column to car_entries.
// - Keeps settings table.
// - Uses database version 2 and onUpgrade logic.

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  static const String databaseName = 'car_diary.db';
  static const int databaseVersion = 2;

  static const String tableEntries = 'car_entries';
  static const String columnId = 'id';
  static const String columnType = 'type';
  static const String columnOdometer = 'odometer';
  static const String columnCost = 'cost';
  static const String columnDate = 'date';
  static const String columnNotes = 'notes';
  static const String columnQuantity = 'quantity';

  static const String tableSettings = 'settings';
  static const String columnSettingsId = 'id';
  static const String columnRegNumber = 'regNumber';
  static const String columnOwnerName = 'ownerName';
  static const String columnUnitType = 'unitType';
  static const String columnCurrency = 'currency';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, databaseName);

    return openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableEntries (
        $columnId TEXT PRIMARY KEY,
        $columnType TEXT NOT NULL,
        $columnOdometer INTEGER NOT NULL,
        $columnCost REAL NOT NULL,
        $columnDate TEXT NOT NULL,
        $columnNotes TEXT,
        $columnQuantity REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        $columnSettingsId INTEGER PRIMARY KEY,
        $columnRegNumber TEXT NOT NULL,
        $columnOwnerName TEXT NOT NULL,
        $columnUnitType TEXT NOT NULL,
        $columnCurrency TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE $tableEntries ADD COLUMN $columnQuantity REAL',
        );
      } catch (_) {
        // Column may already exist on some local builds.
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSettings (
          $columnSettingsId INTEGER PRIMARY KEY,
          $columnRegNumber TEXT NOT NULL,
          $columnOwnerName TEXT NOT NULL,
          $columnUnitType TEXT NOT NULL,
          $columnCurrency TEXT NOT NULL
        )
      ''');
    }
  }
}