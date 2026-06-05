import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';
import 'package:sona/features/auth/widgets/onboarding_steps.dart';
import 'package:sona/services/api_client.dart';

enum PracticeMode { single, group }

/// Screen 02 — Plan & Seats (Auth·08, Figma node 3:38).
///
/// Single-clinician vs Group-practice selection with a live-priced seat stepper,
/// persisted via `PATCH /v1/practices/:id/plan`.
class PlanSeatsScreen extends StatefulWidget {
  const PlanSeatsScreen({
    super.key,
    required this.apiClient,
    required this.practiceId,
    required this.onContinue,
    this.initialMode = PracticeMode.group,
    this.initialSeats = 5,
  });

  final SonaApiClient apiClient;
  final String practiceId;

  /// Advance to Practice setup (screen 03).
  final VoidCallback onContinue;

  final PracticeMode initialMode;
  final int initialSeats;

  static const int pricePerSeat = 29;
  static const int minGroupSeats = 2;
  static const int maxGroupSeats = 50;

  @override
  State<PlanSeatsScreen> createState() => _PlanSeatsScreenState();
}

class _PlanSeatsScreenState extends State<PlanSeatsScreen> {
  late PracticeMode _mode = widget.initialMode;
  late int _groupSeats = widget.initialSeats
      .clamp(PlanSeatsScreen.minGroupSeats, PlanSeatsScreen.maxGroupSeats);
  bool _busy = false;
  String? _error;

  int get _seats => _mode == PracticeMode.single ? 1 : _groupSeats;
  int get _total => _seats * PlanSeatsScreen.pricePerSeat;
  String get _seatsLabel => _seats == 1 ? '1 seat' : '$_seats seats';

  void _setMode(PracticeMode mode) => setState(() => _mode = mode);

  void _changeSeats(int delta) {
    setState(() {
      _groupSeats = (_groupSeats + delta)
          .clamp(PlanSeatsScreen.minGroupSeats, PlanSeatsScreen.maxGroupSeats);
    });
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.apiClient.updatePlan(
        widget.practiceId,
        mode: _mode == PracticeMode.single ? 'single' : 'group',
        seats: _seats,
      );
      if (!mounted) return;
      widget.onContinue();
    } on SonaApiException {
      setState(() => _error = 'Could not save your plan. Please try again.');
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
          const OnboardingSteps(currentStep: 2),
          const SizedBox(height: 20),
          const Text(
            'Choose your plan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Billing is per seat — one seat per clinician.',
            style: TextStyle(fontSize: 14, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PlanCard(
                    title: 'Single clinician',
                    subtitle: 'Just you, for now.',
                    selected: _mode == PracticeMode.single,
                    onTap: () => _setMode(PracticeMode.single),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlanCard(
                    title: 'Group practice',
                    subtitle: 'Multiple clinicians, shared patients.',
                    selected: _mode == PracticeMode.group,
                    onTap: () => _setMode(PracticeMode.group),
                  ),
                ),
              ],
            ),
          ),
          if (_mode == PracticeMode.group) ...[
            const SizedBox(height: 20),
            _seatStepper(),
          ],
          const SizedBox(height: 20),
          _priceSummary(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBanner(_error!),
          ],
          const SizedBox(height: 20),
          SonaButton(
            label: _busy ? 'Saving…' : 'Continue to practice setup',
            onPressed: _busy ? null : _continue,
          ),
        ],
      ),
    );
  }

  Widget _seatStepper() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number of seats (clinicians)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SonaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: SonaColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SonaColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepperButton(
                key: const ValueKey('seat-decrement'),
                symbol: '−',
                onTap: _groupSeats > PlanSeatsScreen.minGroupSeats
                    ? () => _changeSeats(-1)
                    : null,
              ),
              Text(
                _seatsLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SonaColors.textPrimary,
                ),
              ),
              _stepperButton(
                key: const ValueKey('seat-increment'),
                symbol: '+',
                onTap: _groupSeats < PlanSeatsScreen.maxGroupSeats
                    ? () => _changeSeats(1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required Key key,
    required String symbol,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: SonaColors.heroTint,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            symbol,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: SonaColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _priceSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: SonaColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_seatsLabel × £${PlanSeatsScreen.pricePerSeat} / mo',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: SonaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Billed monthly · cancel anytime',
                  style: TextStyle(fontSize: 11, color: SonaColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '£$_total / mo',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: SonaColors.primary,
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? SonaColors.heroTint : SonaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? SonaColors.primary : SonaColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: SonaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: SonaColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
