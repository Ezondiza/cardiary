// Folder: lib/screens/
// File: status_screen.dart
// Version: v1.6
// Change summary:
// - Replaced passive status chip text with actionable "Know your vehicle" CTA.
// - Added tappable insights dialog with fuel cost per distance, service cost per distance,
//   and maintenance calibration status.
// - Keeps dynamic unit labels from UserSettings.
// - Preserves professional vehicle hero header.

import 'package:flutter/material.dart';

import '../models/car_models.dart';
import '../repository/car_repository.dart';

class StatusScreen extends StatelessWidget {
  final CarRepository repository;

  const StatusScreen({
    super.key,
    required this.repository,
  });

  Future<_StatusViewData> _load() async {
    final List<CarLogEntry> entries = await repository.getAllEntries();
    final UserSettings? settings = await repository.getSettings();

    final DistanceUnit unitType = settings?.unitType ?? DistanceUnit.mi;

    if (entries.isEmpty) {
      return _StatusViewData(
        summary: const CarStatusSummary(
          currentOdometer: 0,
          costPerDistance: 0.0,
          maintenanceHealthPercent: null,
          distanceSinceLastService: 0,
          totalSpend: 0.0,
          needsCalibration: true,
          maintenanceMessage: 'Add more history',
        ),
        settings: settings,
        unitType: unitType,
        entries: entries,
      );
    }

    final List<CarLogEntry> sortedByOdometer = List<CarLogEntry>.of(entries)
      ..sort((a, b) => a.odometer.compareTo(b.odometer));

    final int firstOdometer = sortedByOdometer.first.odometer;
    final int lastOdometer = sortedByOdometer.last.odometer;
    final int distanceCovered = (lastOdometer - firstOdometer).clamp(0, 1 << 30);

    final double totalSpend = entries.fold<double>(
      0.0,
          (double sum, CarLogEntry entry) => sum + entry.cost,
    );

    final double costPerDistance =
    distanceCovered > 0 ? (totalSpend / distanceCovered).toDouble() : 0.0;

    final List<ServiceLogEntry> services = entries.whereType<ServiceLogEntry>().toList()
      ..sort((a, b) => b.odometer.compareTo(a.odometer));

    late final CarStatusSummary summary;

    if (services.length < 2) {
      final int sinceLastService =
      services.isNotEmpty ? lastOdometer - services.first.odometer : 0;

      summary = CarStatusSummary(
        currentOdometer: lastOdometer,
        costPerDistance: costPerDistance,
        maintenanceHealthPercent: null,
        distanceSinceLastService: sinceLastService,
        totalSpend: totalSpend,
        needsCalibration: true,
        maintenanceMessage:
        services.isEmpty ? 'Add more history' : 'Calibration Required',
      );
    } else {
      final int lastServiceOdometer = services[0].odometer;
      final int previousServiceOdometer = services[1].odometer;
      final int interval = lastServiceOdometer - previousServiceOdometer;
      final int sinceLastService = lastOdometer - lastServiceOdometer;

      if (interval <= 0) {
        summary = CarStatusSummary(
          currentOdometer: lastOdometer,
          costPerDistance: costPerDistance,
          maintenanceHealthPercent: null,
          distanceSinceLastService: sinceLastService,
          totalSpend: totalSpend,
          needsCalibration: true,
          maintenanceMessage: 'Calibration Required',
        );
      } else {
        final double healthPercent =
        ((1 - (sinceLastService / interval)) * 100).clamp(0.0, 100.0).toDouble();

        summary = CarStatusSummary(
          currentOdometer: lastOdometer,
          costPerDistance: costPerDistance,
          maintenanceHealthPercent: healthPercent,
          distanceSinceLastService: sinceLastService,
          totalSpend: totalSpend,
          needsCalibration: false,
          maintenanceMessage: '${healthPercent.toStringAsFixed(0)}% healthy',
        );
      }
    }

    return _StatusViewData(
      summary: summary,
      settings: settings,
      unitType: unitType,
      entries: entries,
    );
  }

  void _showInsightsDialog(
      BuildContext context,
      _StatusViewData data,
      ) {
    final _VehicleInsights insights = _buildInsights(data);

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Vehicle Insights'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _InsightSection(
                    title: 'Fuel',
                    rows: <_InsightRowData>[
                      _InsightRowData(
                        label: 'Fuel cost per ${data.unitType.label}',
                        value: insights.fuelCostPerDistance.toStringAsFixed(2),
                      ),
                      _InsightRowData(
                        label: 'Fuel records',
                        value: insights.fuelEntryCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InsightSection(
                    title: 'Service',
                    rows: <_InsightRowData>[
                      _InsightRowData(
                        label: 'Service cost per ${data.unitType.label}',
                        value: insights.serviceCostPerDistance.toStringAsFixed(2),
                      ),
                      _InsightRowData(
                        label: 'Service records',
                        value: insights.serviceEntryCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InsightSection(
                    title: 'Maintenance',
                    rows: <_InsightRowData>[
                      _InsightRowData(
                        label: 'Calibration status',
                        value: insights.calibrationStatus,
                      ),
                      _InsightRowData(
                        label: 'Health',
                        value: insights.healthDisplay,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    insights.helperText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  _VehicleInsights _buildInsights(_StatusViewData data) {
    final List<CarLogEntry> entries = data.entries;
    final List<FuelLogEntry> fuelEntries = entries.whereType<FuelLogEntry>().toList();
    final List<ServiceLogEntry> serviceEntries = entries.whereType<ServiceLogEntry>().toList();

    double fuelCostPerDistance = 0.0;
    double serviceCostPerDistance = 0.0;

    if (fuelEntries.isNotEmpty) {
      final List<FuelLogEntry> sortedFuel = List<FuelLogEntry>.of(fuelEntries)
        ..sort((a, b) => a.odometer.compareTo(b.odometer));

      final int firstFuelOdometer = sortedFuel.first.odometer;
      final int lastFuelOdometer = sortedFuel.last.odometer;
      final int fuelDistance = (lastFuelOdometer - firstFuelOdometer).clamp(0, 1 << 30);
      final double totalFuelCost =
      fuelEntries.fold<double>(0.0, (double sum, FuelLogEntry e) => sum + e.cost);

      fuelCostPerDistance =
      fuelDistance > 0 ? (totalFuelCost / fuelDistance).toDouble() : 0.0;
    }

    if (serviceEntries.isNotEmpty) {
      final List<ServiceLogEntry> sortedServices = List<ServiceLogEntry>.of(serviceEntries)
        ..sort((a, b) => a.odometer.compareTo(b.odometer));

      final int firstServiceOdometer = sortedServices.first.odometer;
      final int lastServiceOdometer = sortedServices.last.odometer;
      final int serviceDistance =
      (lastServiceOdometer - firstServiceOdometer).clamp(0, 1 << 30);
      final double totalServiceCost =
      serviceEntries.fold<double>(0.0, (double sum, ServiceLogEntry e) => sum + e.cost);

      serviceCostPerDistance =
      serviceDistance > 0 ? (totalServiceCost / serviceDistance).toDouble() : 0.0;
    }

    final bool calibrated = serviceEntries.length >= 2 && !data.summary.needsCalibration;

    return _VehicleInsights(
      fuelCostPerDistance: fuelCostPerDistance,
      serviceCostPerDistance: serviceCostPerDistance,
      fuelEntryCount: fuelEntries.length,
      serviceEntryCount: serviceEntries.length,
      calibrationStatus: calibrated ? 'Calibrated' : 'Needs more service history',
      healthDisplay: calibrated
          ? '${(data.summary.maintenanceHealthPercent ?? 0.0).toStringAsFixed(0)}%'
          : 'Calibration Required',
      helperText: calibrated
          ? 'Maintenance health is based on your observed service interval history.'
          : 'Add at least 2 service records to calibrate maintenance health accurately.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatusViewData>(
      future: _load(),
      builder: (BuildContext context, AsyncSnapshot<_StatusViewData> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading status: ${snapshot.error}'),
          );
        }

        final _StatusViewData data = snapshot.data ??
            _StatusViewData(
              summary: const CarStatusSummary(
                currentOdometer: 0,
                costPerDistance: 0.0,
                maintenanceHealthPercent: null,
                distanceSinceLastService: 0,
                totalSpend: 0.0,
                needsCalibration: true,
                maintenanceMessage: 'Add more history',
              ),
              settings: null,
              unitType: DistanceUnit.mi,
              entries: const <CarLogEntry>[],
            );

        final CarStatusSummary summary = data.summary;
        final UserSettings? settings = data.settings;
        final String distanceUnit = data.unitType.label;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _VehicleHeaderCard(
              regNumber:
              settings?.regNumber.isNotEmpty == true ? settings!.regNumber : 'Your Vehicle',
              ownerName:
              settings?.ownerName.isNotEmpty == true ? settings!.ownerName : 'Owner not set',
              odometerText: '${summary.currentOdometer} $distanceUnit',
              actionText: 'Know your vehicle',
              actionIcon: Icons.insights_rounded,
              onActionTap: () => _showInsightsDialog(context, data),
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Cost per $distanceUnit',
              value: summary.costPerDistance.toStringAsFixed(2),
              icon: Icons.calculate,
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Total Spend',
              value: summary.totalSpend.toStringAsFixed(2),
              icon: Icons.receipt_long,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: summary.needsCalibration
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Maintenance Health',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Calibration Required',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add more service history to calibrate maintenance health.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Maintenance Health',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: ((summary.maintenanceHealthPercent ?? 0.0) / 100.0)
                          .clamp(0.0, 1.0),
                      minHeight: 14,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      summary.maintenanceMessage,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.distanceSinceLastService} $distanceUnit since last service',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VehicleHeaderCard extends StatelessWidget {
  final String regNumber;
  final String ownerName;
  final String odometerText;
  final String actionText;
  final IconData actionIcon;
  final VoidCallback onActionTap;

  const _VehicleHeaderCard({
    required this.regNumber,
    required this.ownerName,
    required this.odometerText,
    required this.actionText,
    required this.actionIcon,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            Colors.blueGrey.shade50,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    size: 28,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        regNumber,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ownerName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.speed_rounded,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        odometerText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onActionTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.insights_rounded,
                          size: 18,
                          color: Color(0xFFB26A00),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actionText,
                          style: const TextStyle(
                            color: Color(0xFFB26A00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  final String title;
  final List<_InsightRowData> rows;

  const _InsightSection({
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...rows.map(
              (_InsightRowData row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(row.label),
                ),
                const SizedBox(width: 12),
                Text(
                  row.value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusViewData {
  final CarStatusSummary summary;
  final UserSettings? settings;
  final DistanceUnit unitType;
  final List<CarLogEntry> entries;

  const _StatusViewData({
    required this.summary,
    required this.settings,
    required this.unitType,
    required this.entries,
  });
}

class _VehicleInsights {
  final double fuelCostPerDistance;
  final double serviceCostPerDistance;
  final int fuelEntryCount;
  final int serviceEntryCount;
  final String calibrationStatus;
  final String healthDisplay;
  final String helperText;

  const _VehicleInsights({
    required this.fuelCostPerDistance,
    required this.serviceCostPerDistance,
    required this.fuelEntryCount,
    required this.serviceEntryCount,
    required this.calibrationStatus,
    required this.healthDisplay,
    required this.helperText,
  });
}

class _InsightRowData {
  final String label;
  final String value;

  const _InsightRowData({
    required this.label,
    required this.value,
  });
}