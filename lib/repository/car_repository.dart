// Folder: lib/repository/
// File: car_repository.dart
// Version: v1.5
// Change summary:
// - Fixed CarStatusSummary parameter name mismatch.
// - Uses distanceSinceLastService consistently.
// - Aligned with quantity-based fuel model and current status summary model.

import 'package:sqflite/sqflite.dart';

import '../models/car_models.dart';
import 'database_helper.dart';

abstract class CarRepository {
  Future<List<CarLogEntry>> getAllEntries();
  Future<void> addEntry(CarLogEntry entry);
  Future<int> getLatestOdometer();
  Future<void> saveSettings(UserSettings settings);
  Future<UserSettings?> getSettings();
  Future<CarStatusSummary> getStatusSummary();
}

class SqliteCarRepository implements CarRepository {
  final DatabaseHelper _dbHelper;

  SqliteCarRepository({
    DatabaseHelper? databaseHelper,
  }) : _dbHelper = databaseHelper ?? DatabaseHelper.instance;

  @override
  Future<List<CarLogEntry>> getAllEntries() async {
    final Database db = await _dbHelper.database;

    final List<Map<String, Object?>> rows = await db.query(
      DatabaseHelper.tableEntries,
      orderBy: '${DatabaseHelper.columnDate} DESC',
    );

    return rows.map(_mapRowToEntry).toList();
  }

  @override
  Future<void> addEntry(CarLogEntry entry) async {
    final Database db = await _dbHelper.database;

    await db.insert(
      DatabaseHelper.tableEntries,
      _mapEntryToRow(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> getLatestOdometer() async {
    final Database db = await _dbHelper.database;

    final List<Map<String, Object?>> result = await db.rawQuery(
      'SELECT MAX(${DatabaseHelper.columnOdometer}) AS maxVal FROM ${DatabaseHelper.tableEntries}',
    );

    if (result.isEmpty) {
      return 0;
    }

    final Object? value = result.first['maxVal'];
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    final Database db = await _dbHelper.database;

    await db.insert(
      DatabaseHelper.tableSettings,
      <String, Object?>{
        DatabaseHelper.columnSettingsId: 1,
        DatabaseHelper.columnRegNumber: settings.regNumber,
        DatabaseHelper.columnOwnerName: settings.ownerName,
        DatabaseHelper.columnUnitType: settings.unitType.name,
        DatabaseHelper.columnCurrency: settings.currency,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<UserSettings?> getSettings() async {
    final Database db = await _dbHelper.database;

    final List<Map<String, Object?>> rows = await db.query(
      DatabaseHelper.tableSettings,
      where: '${DatabaseHelper.columnSettingsId} = ?',
      whereArgs: <Object>[1],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final Map<String, Object?> row = rows.first;
    final String unitName =
        (row[DatabaseHelper.columnUnitType] as String?) ?? DistanceUnit.mi.name;

    final DistanceUnit unitType = DistanceUnit.values.firstWhere(
          (DistanceUnit unit) => unit.name == unitName,
      orElse: () => DistanceUnit.mi,
    );

    return UserSettings(
      regNumber: (row[DatabaseHelper.columnRegNumber] as String?) ?? '',
      ownerName: (row[DatabaseHelper.columnOwnerName] as String?) ?? '',
      unitType: unitType,
      currency: (row[DatabaseHelper.columnCurrency] as String?) ?? 'USD',
    );
  }

  @override
  Future<CarStatusSummary> getStatusSummary() async {
    final List<CarLogEntry> entries = await getAllEntries();

    if (entries.isEmpty) {
      return const CarStatusSummary(
        currentOdometer: 0,
        costPerDistance: 0.0,
        maintenanceHealthPercent: null,
        distanceSinceLastService: 0,
        totalSpend: 0.0,
        needsCalibration: true,
        maintenanceMessage: 'Add more history',
      );
    }

    final List<CarLogEntry> sortedByOdometer = List<CarLogEntry>.of(entries)
      ..sort((a, b) => a.odometer.compareTo(b.odometer));

    final int currentOdometer = sortedByOdometer.last.odometer;
    final int startingOdometer = sortedByOdometer.first.odometer;
    final int distanceCovered =
    (currentOdometer - startingOdometer).clamp(0, 1 << 30);

    final double totalSpend = entries.fold<double>(
      0.0,
          (double sum, CarLogEntry entry) => sum + entry.cost,
    );

    final double costPerDistance =
    distanceCovered > 0 ? (totalSpend / distanceCovered).toDouble() : 0.0;

    final List<ServiceLogEntry> serviceEntries =
    entries.whereType<ServiceLogEntry>().toList()
      ..sort((a, b) => b.odometer.compareTo(a.odometer));

    if (serviceEntries.length < 2) {
      final int lastServiceOdometer =
      serviceEntries.isNotEmpty ? serviceEntries.first.odometer : 0;
      final int sinceLastService =
      serviceEntries.isNotEmpty ? currentOdometer - lastServiceOdometer : 0;

      return CarStatusSummary(
        currentOdometer: currentOdometer,
        costPerDistance: costPerDistance,
        maintenanceHealthPercent: null,
        distanceSinceLastService: sinceLastService,
        totalSpend: totalSpend,
        needsCalibration: true,
        maintenanceMessage:
        serviceEntries.isEmpty ? 'Add more history' : 'Calibration Required',
      );
    }

    final int lastServiceOdometer = serviceEntries[0].odometer;
    final int previousServiceOdometer = serviceEntries[1].odometer;
    final int interval = lastServiceOdometer - previousServiceOdometer;
    final int sinceLastService = currentOdometer - lastServiceOdometer;

    if (interval <= 0) {
      return CarStatusSummary(
        currentOdometer: currentOdometer,
        costPerDistance: costPerDistance,
        maintenanceHealthPercent: null,
        distanceSinceLastService: sinceLastService,
        totalSpend: totalSpend,
        needsCalibration: true,
        maintenanceMessage: 'Calibration Required',
      );
    }

    final double healthPercent =
    ((1 - (sinceLastService / interval)) * 100).clamp(0.0, 100.0).toDouble();

    return CarStatusSummary(
      currentOdometer: currentOdometer,
      costPerDistance: costPerDistance,
      maintenanceHealthPercent: healthPercent,
      distanceSinceLastService: sinceLastService,
      totalSpend: totalSpend,
      needsCalibration: false,
      maintenanceMessage: '${healthPercent.toStringAsFixed(0)}% healthy',
    );
  }

  Map<String, Object?> _mapEntryToRow(CarLogEntry entry) {
    return <String, Object?>{
      DatabaseHelper.columnId: entry.id,
      DatabaseHelper.columnType: entry.type.name,
      DatabaseHelper.columnOdometer: entry.odometer,
      DatabaseHelper.columnCost: entry.cost.toDouble(),
      DatabaseHelper.columnDate: entry.date.toIso8601String(),
      DatabaseHelper.columnNotes: entry.notes,
      DatabaseHelper.columnQuantity:
      entry is FuelLogEntry ? entry.quantity.toDouble() : null,
    };
  }

  CarLogEntry _mapRowToEntry(Map<String, Object?> row) {
    final String type =
        (row[DatabaseHelper.columnType] as String?) ?? LogType.service.name;

    final int odometer =
        (row[DatabaseHelper.columnOdometer] as num?)?.toInt() ?? 0;

    final double cost =
        (row[DatabaseHelper.columnCost] as num?)?.toDouble() ?? 0.0;

    final DateTime date = DateTime.parse(
      (row[DatabaseHelper.columnDate] as String?) ??
          DateTime.now().toIso8601String(),
    );

    final String notes = (row[DatabaseHelper.columnNotes] as String?) ?? '';
    final String id = (row[DatabaseHelper.columnId] as String?) ?? '';

    if (type == LogType.fuel.name) {
      final double quantity =
          (row[DatabaseHelper.columnQuantity] as num?)?.toDouble() ?? 0.0;

      return FuelLogEntry(
        id: id,
        date: date,
        odometer: odometer,
        cost: cost,
        quantity: quantity,
        notes: notes,
      );
    }

    return ServiceLogEntry(
      id: id,
      date: date,
      odometer: odometer,
      cost: cost,
      serviceType: ServiceType.other,
      notes: notes,
    );
  }
}