import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';
import 'package:sona/services/api_client.dart';

/// Screen 05 — Practice Live (Auth·11, Figma node 4:74).
///
/// Success confirmation with real summary stats (admin / clinicians invited /
/// seats), the dashboard CTA, and a gated patient-import link.
class PracticeLiveScreen extends StatefulWidget {
  const PracticeLiveScreen({
    super.key,
    required this.apiClient,
    required this.practiceId,
    required this.practiceName,
    required this.seats,
    required this.onGoToDashboard,
    this.onImportPatients,
  });

  final SonaApiClient apiClient;
  final String practiceId;
  final String practiceName;
  final int seats;

  /// Role-based routing to the admin dashboard (wired in Auth·14).
  final VoidCallback onGoToDashboard;

  /// Patient-import flow, gated behind GDPR review (Auth·17). When null, the
  /// link explains it's coming.
  final VoidCallback? onImportPatients;

  @override
  State<PracticeLiveScreen> createState() => _PracticeLiveScreenState();
}

class _PracticeLiveScreenState extends State<PracticeLiveScreen> {
  int _adminCount = 0;
  int _cliniciansInvited = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.apiClient.listPracticeClinicians(widget.practiceId);
      final list = (res['clinicians'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _adminCount = list.where((c) => c['role'] == 'admin').length;
        _cliniciansInvited = list.where((c) => c['role'] == 'clinician').length;
        _loading = false;
      });
    } catch (_) {
      // Terminal success screen — fall back to the known admin if the roster
      // can't be fetched rather than blocking the user.
      setState(() {
        _adminCount = _adminCount == 0 ? 1 : _adminCount;
        _loading = false;
      });
    }
  }

  void _onImport() {
    if (widget.onImportPatients != null) {
      widget.onImportPatients!();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient import requires GDPR review — coming soon.'),
      ),
    );
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
                  constraints: const BoxConstraints(maxWidth: 480),
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
            color: Color(0x0F141F29),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: SonaColors.successBg,
                borderRadius: BorderRadius.circular(32),
              ),
              alignment: Alignment.center,
              child: const Text(
                '✓',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: SonaColors.successText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your practice is live',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.practiceName} is set up with ${widget.seats} seats. '
            'Invited clinicians have received an email to set their password and log in.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _statsRow(),
          const SizedBox(height: 18),
          SonaButton(
            label: 'Go to admin dashboard',
            onPressed: widget.onGoToDashboard,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _onImport,
              child: const Text(
                'Import patient data (GDPR review required)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SonaColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: SonaColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _stat(_loading ? '—' : '$_adminCount', 'Admin')),
          Expanded(
              child: _stat(_loading ? '—' : '$_cliniciansInvited', 'Clinicians invited')),
          Expanded(child: _stat('${widget.seats}', 'Seats')),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: SonaColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: SonaColors.textMuted),
        ),
      ],
    );
  }
}
