// Folder: lib/screens/
// File: log_screen.dart
// Version: v1.6
// Change summary:
// - Refactored to UI-only screen.
// - Removed all repository/database implementation code from this file.
// - Supports date picker, quantity field, dynamic units, and confirm-before-save dialog.

import 'package:flutter/material.dart';

import '../models/car_models.dart';
import '../repository/car_repository.dart';

class LogScreen extends StatefulWidget {
  final CarRepository repository;
  final VoidCallback onSaved;

  const LogScreen({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  LogType _selectedType = LogType.fuel;
  ServiceType _serviceType = ServiceType.oilChange;

  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int _latestOdometer = 0;
  DistanceUnit _unitType = DistanceUnit.mi;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final int latestOdometer = await widget.repository.getLatestOdometer();
      final UserSettings? settings = await widget.repository.getSettings();

      if (!mounted) return;

      setState(() {
        _latestOdometer = latestOdometer;
        _unitType = settings?.unitType ?? DistanceUnit.mi;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _latestOdometer = 0;
        _unitType = DistanceUnit.mi;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      });
    }
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final _PendingLogEntry pending = _buildPendingEntry();
    final bool confirmed = await _showConfirmDialog(pending);

    if (!confirmed) {
      return;
    }

    await _saveConfirmed(pending);
  }

  _PendingLogEntry _buildPendingEntry() {
    final int odometer = int.parse(_odometerController.text.trim());
    final double cost = double.parse(_costController.text.trim()).toDouble();
    final String notes = _notesController.text.trim();
    final String id = DateTime.now().microsecondsSinceEpoch.toString();

    late final CarLogEntry entry;

    if (_selectedType == LogType.fuel) {
      final double quantity =
      double.parse(_quantityController.text.trim()).toDouble();

      entry = FuelLogEntry(
        id: id,
        date: _selectedDate,
        odometer: odometer,
        cost: cost,
        quantity: quantity,
        notes: notes,
      );
    } else {
      entry = ServiceLogEntry(
        id: id,
        date: _selectedDate,
        odometer: odometer,
        cost: cost,
        serviceType: _serviceType,
        notes: notes,
      );
    }

    return _PendingLogEntry(
      entry: entry,
      warningMessage: _buildWarningMessage(entry),
    );
  }

  String? _buildWarningMessage(CarLogEntry entry) {
    if (entry.date.isAfter(DateTime.now())) {
      return 'The selected date is in the future.';
    }

    if (entry.odometer > (_latestOdometer + 5000) && _latestOdometer > 0) {
      return 'The odometer looks much higher than your latest saved value.';
    }

    if (entry.cost > 10000) {
      return 'The cost looks unusually high.';
    }

    if (entry is FuelLogEntry) {
      if (entry.quantity <= 0) {
        return 'Fuel quantity should be greater than zero.';
      }

      if (_unitType == DistanceUnit.km && entry.quantity > 150) {
        return 'The fuel quantity looks unusually high for liters.';
      }

      if (_unitType == DistanceUnit.mi && entry.quantity > 40) {
        return 'The fuel quantity looks unusually high for gallons.';
      }
    }

    return null;
  }

  Future<bool> _showConfirmDialog(_PendingLogEntry pending) async {
    final CarLogEntry entry = pending.entry;
    final bool isFuel = entry is FuelLogEntry;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (pending.warningMessage != null) ...<Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pending.warningMessage!,
                            style: TextStyle(color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _ConfirmRow(
                  label: 'Type',
                  value: isFuel ? 'Fuel' : 'Service',
                ),
                _ConfirmRow(
                  label: 'Date',
                  value: formatDate(entry.date),
                ),
                _ConfirmRow(
                  label: 'Odometer',
                  value: '${entry.odometer} ${_distanceLabel()}',
                ),
                _ConfirmRow(
                  label: 'Cost',
                  value: entry.cost.toStringAsFixed(2),
                ),
                if (isFuel)
                  _ConfirmRow(
                    label: 'Quantity',
                    value:
                    '${(entry as FuelLogEntry).quantity.toStringAsFixed(1)} ${_quantityLabel()}',
                  ),
                if (!isFuel)
                  _ConfirmRow(
                    label: 'Service Type',
                    value: (entry as ServiceLogEntry).serviceType.label,
                  ),
                if (entry.notes.isNotEmpty)
                  _ConfirmRow(
                    label: 'Notes',
                    value: entry.notes,
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Edit'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm Save'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _saveConfirmed(_PendingLogEntry pending) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.repository.addEntry(pending.entry);

      if (!mounted) return;

      _formKey.currentState!.reset();
      _odometerController.clear();
      _costController.clear();
      _quantityController.clear();
      _notesController.clear();

      setState(() {
        _selectedType = LogType.fuel;
        _serviceType = ServiceType.oilChange;
        _selectedDate = DateTime.now();
      });

      await _loadInitialData();
      widget.onSaved();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save entry: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _distanceLabel() => _unitType.label;

  String _quantityLabel() => _unitType.quantityLabel;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_latestOdometer > 0) ...<Widget>[
              Text(
                'Latest odometer: $_latestOdometer ${_distanceLabel()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            SegmentedButton<LogType>(
              segments: const <ButtonSegment<LogType>>[
                ButtonSegment<LogType>(
                  value: LogType.fuel,
                  label: Text('Fuel'),
                ),
                ButtonSegment<LogType>(
                  value: LogType.service,
                  label: Text('Service'),
                ),
              ],
              selected: <LogType>{_selectedType},
              onSelectionChanged: (Set<LogType> selection) {
                setState(() {
                  _selectedType = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Text(formatDate(_selectedDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _odometerController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Odometer (${_distanceLabel()})',
                border: const OutlineInputBorder(),
              ),
              validator: _validateOdometer,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost',
                border: OutlineInputBorder(),
              ),
              validator: _requiredDouble,
            ),
            const SizedBox(height: 12),
            if (_selectedType == LogType.fuel) ...<Widget>[
              TextFormField(
                controller: _quantityController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity (${_quantityLabel()})',
                  border: const OutlineInputBorder(),
                ),
                validator: _requiredDouble,
              ),
            ] else ...<Widget>[
              DropdownButtonFormField<ServiceType>(
                value: _serviceType,
                decoration: const InputDecoration(
                  labelText: 'Service Type',
                  border: OutlineInputBorder(),
                ),
                items: ServiceType.values
                    .map(
                      (ServiceType type) => DropdownMenuItem<ServiceType>(
                    value: type,
                    child: Text(type.label),
                  ),
                )
                    .toList(),
                onChanged: (ServiceType? value) {
                  if (value != null) {
                    setState(() {
                      _serviceType = value;
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _onSavePressed,
                icon: _isSaving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateOdometer(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a whole number';
    }

    if (parsed < _latestOdometer) {
      return 'Must be at least $_latestOdometer';
    }

    return null;
  }

  String? _requiredDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final double? parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number';
    }

    return null;
  }
}

class _PendingLogEntry {
  final CarLogEntry entry;
  final String? warningMessage;

  const _PendingLogEntry({
    required this.entry,
    required this.warningMessage,
  });
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}