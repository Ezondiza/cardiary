// Folder: lib/screens/
// File: history_screen.dart
// Version: v1.5
// Change summary:
// - Displays fuel quantity using dynamic Liters/Gallons label.
// - Uses dynamic distance unit from UserSettings.
// - Keeps async loading via FutureBuilder.

import 'package:flutter/material.dart';

import '../models/car_models.dart';
import '../repository/car_repository.dart';

class HistoryScreen extends StatelessWidget {
  final CarRepository repository;

  const HistoryScreen({
    super.key,
    required this.repository,
  });

  Future<_HistoryViewData> _load() async {
    final List<CarLogEntry> entries = await repository.getAllEntries();
    final UserSettings? settings = await repository.getSettings();

    return _HistoryViewData(
      entries: entries,
      unitType: settings?.unitType ?? DistanceUnit.mi,
      currency: settings?.currency ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HistoryViewData>(
      future: _load(),
      builder: (BuildContext context, AsyncSnapshot<_HistoryViewData> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading history: ${snapshot.error}'),
          );
        }

        final _HistoryViewData data = snapshot.data ??
            _HistoryViewData(
              entries: const <CarLogEntry>[],
              unitType: DistanceUnit.mi,
              currency: '',
            );

        final List<CarLogEntry> entries = data.entries;
        final String distanceUnit = data.unitType.label;
        final String quantityLabel = data.unitType.quantityLabel;

        if (entries.isEmpty) {
          return const Center(
            child: Text('No entries yet'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            final CarLogEntry entry = entries[index];

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    entry.type == LogType.fuel
                        ? Icons.local_gas_station
                        : Icons.build,
                  ),
                ),
                title: Text(_title(entry)),
                subtitle: Text(
                  '${formatDate(entry.date)} • ${entry.odometer} $distanceUnit\n${_subtitle(entry, quantityLabel)}',
                ),
                isThreeLine: true,
                trailing: Text(entry.cost.toStringAsFixed(2)),
              ),
            );
          },
        );
      },
    );
  }

  String _title(CarLogEntry entry) {
    if (entry is FuelLogEntry) return 'Fuel';
    if (entry is ServiceLogEntry) return entry.serviceType.label;
    return 'Entry';
  }

  String _subtitle(CarLogEntry entry, String quantityLabel) {
    if (entry is FuelLogEntry) {
      return '${entry.quantity.toStringAsFixed(1)} $quantityLabel'
          '${entry.notes.isNotEmpty ? ' • ${entry.notes}' : ''}';
    }
    if (entry is ServiceLogEntry) {
      return entry.notes.isNotEmpty ? entry.notes : 'Service logged';
    }
    return '';
  }
}

class _HistoryViewData {
  final List<CarLogEntry> entries;
  final DistanceUnit unitType;
  final String currency;

  const _HistoryViewData({
    required this.entries,
    required this.unitType,
    required this.currency,
  });
}