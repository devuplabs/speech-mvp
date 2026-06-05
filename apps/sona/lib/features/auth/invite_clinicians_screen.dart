import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';
import 'package:sona/features/auth/widgets/onboarding_steps.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/utils/intake_validation.dart';

/// Parses pasted CSV (`email[,fullName[,role]]` per line) into invite rows.
/// Skips blank lines, header rows, and anything without an `@`. Pure — testable.
List<Map<String, dynamic>> parseCliniciansCsv(String text) {
  final rows = <Map<String, dynamic>>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final parts = line.split(',').map((p) => p.trim()).toList();
    final email = parts.isNotEmpty ? parts[0] : '';
    if (!email.contains('@')) continue;
    final fullName = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    final role =
        parts.length > 2 && parts[2].toLowerCase() == 'admin' ? 'admin' : 'clinician';
    rows.add({
      'email': email,
      'fullName': ?fullName,
      'role': role,
    });
  }
  return rows;
}

/// Screen 04 — Invite Clinicians (Auth·10, Figma node 4:2).
class InviteCliniciansScreen extends StatefulWidget {
  const InviteCliniciansScreen({
    super.key,
    required this.apiClient,
    required this.practiceId,
    required this.totalSeats,
    required this.onFinish,
  });

  final SonaApiClient apiClient;
  final String practiceId;
  final int totalSeats;

  /// Advance to Practice Live (screen 05).
  final VoidCallback onFinish;

  @override
  State<InviteCliniciansScreen> createState() => _InviteCliniciansScreenState();
}

class _InviteCliniciansScreenState extends State<InviteCliniciansScreen> {
  final _emailCtrl = TextEditingController();
  List<Map<String, dynamic>> _clinicians = [];
  int _seatsUsed = 0;
  bool _loading = true;
  bool _inviting = false;
  bool _activating = false;
  String? _emailError;
  String? _error;

  bool get _seatsAvailable => _seatsUsed < widget.totalSeats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await widget.apiClient.listPracticeClinicians(widget.practiceId);
      final list = (res['clinicians'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _clinicians = list;
        _seatsUsed = res['seatsUsed'] as int? ??
            list.where((c) => c['status'] != 'disabled').length;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not load your clinicians. Please try again.';
      });
    }
  }

  Future<void> _invite() async {
    final email = _emailCtrl.text.trim();
    if (!IntakeValidation.isEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }
    if (!_seatsAvailable) {
      setState(() => _error = 'No seats left — increase seats to invite more.');
      return;
    }
    setState(() {
      _inviting = true;
      _emailError = null;
      _error = null;
    });
    try {
      await widget.apiClient.inviteClinician(widget.practiceId, email: email);
      _emailCtrl.clear();
      await _load();
    } on SonaApiException catch (e) {
      setState(() => _error = _inviteErrorMessage(e));
    } catch (_) {
      setState(() => _error = 'Could not send the invite. Please try again.');
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  String _inviteErrorMessage(SonaApiException e) {
    if (e.statusCode == 409) return 'That email is already part of this practice.';
    if (e.statusCode == 422) return 'No seats left — increase seats to invite more.';
    return 'Could not send the invite. Please try again.';
  }

  Future<void> _finish() async {
    setState(() {
      _activating = true;
      _error = null;
    });
    try {
      await widget.apiClient.activatePractice(widget.practiceId);
      if (!mounted) return;
      widget.onFinish();
    } on SonaApiException {
      setState(() => _error = 'Could not finish setup. Please try again.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _activating = false);
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
                  constraints: const BoxConstraints(maxWidth: 580),
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingSteps(currentStep: 4, showChecks: true),
          const SizedBox(height: 16),
          const Text(
            'Add your clinicians',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Each gets a Firebase email invite to set their password. '
            'Clinicians share patient access.',
            style: TextStyle(fontSize: 14, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _seatsRow(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            for (final c in _clinicians) ...[
              _ClinicianRow(
                name: (c['fullName'] as String?)?.isNotEmpty == true
                    ? c['fullName'] as String
                    : (c['email'] as String? ?? ''),
                email: (c['fullName'] as String?)?.isNotEmpty == true
                    ? (c['email'] as String?)
                    : null,
                role: c['role'] as String? ?? 'clinician',
                status: c['status'] as String? ?? 'invited',
              ),
              const SizedBox(height: 10),
            ],
            _inviteRow(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBanner(_error!),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SonaButton(
                  label: 'Import from CSV',
                  variant: SonaButtonVariant.secondary,
                  onPressed: _runCsvImport,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SonaButton(
                  label: _activating ? 'Finishing…' : 'Finish setup',
                  onPressed: _activating ? null : _finish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seatsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SonaColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Seats used',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: SonaColors.textSecondary,
            ),
          ),
          Text(
            '$_seatsUsed of ${widget.totalSeats}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SonaColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _invite(),
                decoration: InputDecoration(
                  hintText: 'name@practice.co.uk',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: SonaColors.border),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: SonaColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _InviteButton(
              busy: _inviting,
              onTap: _inviting ? null : _invite,
            ),
          ],
        ),
        if (_emailError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _emailError!,
              style: const TextStyle(fontSize: 12, color: SonaColors.dangerText),
            ),
          ),
      ],
    );
  }

  Future<void> _runCsvImport() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from CSV'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste one clinician per line: email, full name, role',
                style: TextStyle(fontSize: 12, color: SonaColors.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'james@practice.co.uk, James Okafor, clinician',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SonaColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (confirmed != true) return;

    final rows = parseCliniciansCsv(text);
    if (rows.isEmpty) {
      _snack('No valid rows found in the CSV.');
      return;
    }
    try {
      final result =
          await widget.apiClient.importClinicians(widget.practiceId, rows);
      final invited = (result['invited'] as List?)?.length ?? rows.length;
      await _load();
      _snack('Imported $invited clinician(s).');
    } on SonaApiException catch (e) {
      _snack(e.statusCode == 422
          ? 'Not enough seats for that many clinicians.'
          : 'Could not import. Please try again.');
    } catch (_) {
      _snack('Could not import. Please try again.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

class _ClinicianRow extends StatelessWidget {
  const _ClinicianRow({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  final String name;
  final String? email;
  final String role;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SonaColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SonaColors.textPrimary,
                  ),
                ),
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _roleBadge(role),
          const SizedBox(width: 8),
          _statusBadge(status),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final isAdmin = role == 'admin';
    return _Badge(
      label: isAdmin ? 'Admin' : 'Clinician',
      bg: isAdmin ? SonaColors.primary : SonaColors.navActiveBg,
      fg: isAdmin ? Colors.white : SonaColors.primary,
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'active':
        return const _Badge(
          label: 'Active',
          bg: SonaColors.successBg,
          fg: SonaColors.successText,
        );
      case 'disabled':
        return const _Badge(
          label: 'Disabled',
          bg: SonaColors.dangerBg,
          fg: SonaColors.dangerText,
        );
      default:
        return const _Badge(
          label: 'Invited',
          bg: SonaColors.warningBg,
          fg: SonaColors.warningText,
        );
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: SonaColors.heroTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          busy ? 'Inviting…' : '+ Invite',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SonaColors.primary,
          ),
        ),
      ),
    );
  }
}
