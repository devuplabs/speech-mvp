import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_select_chip.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';
import 'package:sona/features/auth/widgets/onboarding_steps.dart';
import 'package:sona/services/api_client.dart';

/// Screen 03 — Practice Config (Auth·09, Figma node 3:91).
///
/// Name, UK location and a specialties multi-select, persisted via
/// `PATCH /v1/practices/:id`, then advances to Invite Clinicians (screen 04).
class PracticeConfigScreen extends StatefulWidget {
  const PracticeConfigScreen({
    super.key,
    required this.apiClient,
    required this.practiceId,
    required this.onContinue,
    this.initialPracticeName = '',
    this.initialLocation = '',
    this.initialSpecialties = const [],
  });

  final SonaApiClient apiClient;
  final String practiceId;
  final VoidCallback onContinue;
  final String initialPracticeName;
  final String initialLocation;
  final List<String> initialSpecialties;

  static const specialtyOptions = [
    'Paediatric',
    'Adult',
    'Stammering',
    'Dysphagia',
    'Voice',
    'Aphasia',
  ];

  @override
  State<PracticeConfigScreen> createState() => _PracticeConfigScreenState();
}

class _PracticeConfigScreenState extends State<PracticeConfigScreen> {
  late String _practiceName = widget.initialPracticeName;
  late String _location = widget.initialLocation;
  late final Set<String> _specialties = {...widget.initialSpecialties};
  bool _busy = false;
  String? _nameError;
  String? _error;

  /// Selected specialties in canonical option order (stable payload).
  List<String> get _selectedSpecialties => PracticeConfigScreen.specialtyOptions
      .where(_specialties.contains)
      .toList();

  void _toggleSpecialty(String value, bool selected) {
    setState(() {
      if (selected) {
        _specialties.add(value);
      } else {
        _specialties.remove(value);
      }
    });
  }

  Future<void> _continue() async {
    final nameError = _practiceName.trim().isEmpty ? 'Enter your practice name' : null;
    setState(() {
      _nameError = nameError;
      _error = null;
    });
    if (nameError != null) return;

    setState(() => _busy = true);
    try {
      final location = _location.trim();
      await widget.apiClient.updatePracticeConfig(
        widget.practiceId,
        practiceName: _practiceName.trim(),
        location: location.isEmpty ? null : location,
        specialties: _selectedSpecialties,
      );
      if (!mounted) return;
      widget.onContinue();
    } on SonaApiException {
      setState(() => _error = 'Could not save your practice. Please try again.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: Column(
        children: [
          const OnboardingHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _card(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      decoration: BoxDecoration(
        color: SonaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SonaColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F141F29), // rgba(20,31,41,0.06)
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingSteps(currentStep: 3),
          const SizedBox(height: 18),
          const Text(
            'Configure your practice',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'These details appear across clinician dashboards.',
            style: TextStyle(fontSize: 14, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 18),
          SonaTextField(
            label: 'Practice name',
            value: _practiceName,
            hint: 'Whitfield Speech & Language',
            errorText: _nameError,
            onChanged: (v) => _practiceName = v,
          ),
          SonaTextField(
            label: 'Location (UK)',
            value: _location,
            hint: 'Manchester, England',
            onChanged: (v) => _location = v,
          ),
          const SizedBox(height: 4),
          const Text(
            'Specialties',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: SonaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in PracticeConfigScreen.specialtyOptions)
                SonaSelectChip(
                  label: option,
                  pill: true,
                  selected: _specialties.contains(option),
                  onChanged: (sel) => _toggleSpecialty(option, sel),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _gdprBanner(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBanner(_error!),
          ],
          const SizedBox(height: 18),
          SonaButton(
            label: _busy ? 'Saving…' : 'Continue to add clinicians',
            onPressed: _busy ? null : _continue,
          ),
        ],
      ),
    );
  }

  Widget _gdprBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SonaColors.heroTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ℹ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: SonaColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Patient & clinician data import is a separate, GDPR-reviewed step after setup.',
              style: TextStyle(fontSize: 12, color: SonaColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SonaColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: SonaColors.dangerText),
      ),
    );
  }
}
