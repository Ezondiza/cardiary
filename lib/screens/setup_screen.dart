// Folder: lib/screens/
// File: setup_screen.dart
// Version: v1.4
// Change summary:
// - Added footer with clickable "Ghanshyam Acharya" link.
// - Uses url_launcher for external navigation.
// - Keeps layout responsive and scroll-safe.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/car_models.dart';
import '../repository/car_repository.dart';

class SetupScreen extends StatefulWidget {
  final CarRepository repository;
  final VoidCallback onSaved;

  const SetupScreen({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();

  DistanceUnit _selectedUnit = DistanceUnit.mi;
  String _selectedCurrency = 'USD';
  bool _isSaving = false;

  static const List<String> _currencies = <String>[
    'USD',
    'EUR',
    'GBP',
    'INR',
    'NPR',
  ];

  @override
  void dispose() {
    _regNumberController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    final Uri url = Uri.parse('https://app.gsachayr.com');
    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.repository.saveSettings(
        UserSettings(
          regNumber: _regNumberController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          unitType: _selectedUnit,
          currency: _selectedCurrency,
        ),
      );

      if (!mounted) return;
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Car Diary',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up your vehicle details before continuing.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),

                      // Vehicle Reg
                      TextFormField(
                        controller: _regNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Reg Number',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // Owner Name
                      TextFormField(
                        controller: _ownerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Owner Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // Distance Unit
                      Text(
                        'Distance Unit',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<DistanceUnit>(
                        segments: const [
                          ButtonSegment(
                            value: DistanceUnit.km,
                            label: Text('Km'),
                          ),
                          ButtonSegment(
                            value: DistanceUnit.mi,
                            label: Text('Mi'),
                          ),
                        ],
                        selected: {_selectedUnit},
                        onSelectionChanged: (selection) {
                          setState(() => _selectedUnit = selection.first);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Currency
                      DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                        items: _currencies
                            .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCurrency = value);
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          child:
                          Text(_isSaving ? 'Saving...' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Footer
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                    children: [
                      const TextSpan(text: 'A project of '),
                      TextSpan(
                        text: 'Ghanshyam Acharya',
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _openLink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}