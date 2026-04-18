// Folder: lib/models/
// File: car_models.dart
// Version: v1.5
// Change summary:
// - FuelLogEntry now uses quantity (double).
// - CarLogEntry uses a real DateTime field.
// - Includes UserSettings and shared enums/helpers.
// - CarStatusSummary supports calibration-aware maintenance state.

enum LogType { fuel, service }

enum ServiceType { oilChange, tireRotation, inspection, repair, other }

enum DistanceUnit { km, mi }

abstract class CarLogEntry {
  final String id;
  final DateTime date;
  final int odometer;
  final double cost;
  final String notes;

  const CarLogEntry({
    required this.id,
    required this.date,
    required this.odometer,
    required this.cost,
    this.notes = '',
  });

  LogType get type;
}

class FuelLogEntry extends CarLogEntry {
  final double quantity;

  const FuelLogEntry({
    required super.id,
    required super.date,
    required super.odometer,
    required super.cost,
    required this.quantity,
    super.notes,
  });

  @override
  LogType get type => LogType.fuel;
}

class ServiceLogEntry extends CarLogEntry {
  final ServiceType serviceType;

  const ServiceLogEntry({
    required super.id,
    required super.date,
    required super.odometer,
    required super.cost,
    required this.serviceType,
    super.notes,
  });

  @override
  LogType get type => LogType.service;
}

class CarStatusSummary {
  final int currentOdometer;
  final double costPerDistance;
  final double? maintenanceHealthPercent;
  final int distanceSinceLastService;
  final double totalSpend;
  final bool needsCalibration;
  final String maintenanceMessage;

  const CarStatusSummary({
    required this.currentOdometer,
    required this.costPerDistance,
    required this.maintenanceHealthPercent,
    required this.distanceSinceLastService,
    required this.totalSpend,
    required this.needsCalibration,
    required this.maintenanceMessage,
  });
}

class UserSettings {
  final String regNumber;
  final String ownerName;
  final DistanceUnit unitType;
  final String currency;

  const UserSettings({
    required this.regNumber,
    required this.ownerName,
    required this.unitType,
    required this.currency,
  });
}

extension ServiceTypeLabel on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.oilChange:
        return 'Oil Change';
      case ServiceType.tireRotation:
        return 'Tire Rotation';
      case ServiceType.inspection:
        return 'Inspection';
      case ServiceType.repair:
        return 'Repair';
      case ServiceType.other:
        return 'Other';
    }
  }
}

extension DistanceUnitLabel on DistanceUnit {
  String get label {
    switch (this) {
      case DistanceUnit.km:
        return 'km';
      case DistanceUnit.mi:
        return 'mi';
    }
  }

  String get quantityLabel {
    switch (this) {
      case DistanceUnit.km:
        return 'Liters';
      case DistanceUnit.mi:
        return 'Gallons';
    }
  }
}

String formatDate(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}