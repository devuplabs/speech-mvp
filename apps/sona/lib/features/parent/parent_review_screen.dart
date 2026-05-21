import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';
import 'package:sona/design_system/widgets/sona_step_progress.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/parent/intake/intake_review_summary.dart';
import 'package:sona/state/sona_app_state.dart';

class ParentReviewScreen extends StatefulWidget {
  const ParentReviewScreen({
    super.key,
    required this.state,
    required this.onBack,
    required this.onSubmit,
    required this.onEditStep,
    this.busy = false,
  });

  final SonaAppState state;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final void Function(int step) onEditStep;
  final bool busy;

  @override
  State<ParentReviewScreen> createState() => _ParentReviewScreenState();
}

class _ParentReviewScreenState extends State<ParentReviewScreen> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final d = state.intake;
    return ParentMobileScaffold(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.busy ? null : widget.onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(side: const BorderSide(color: SonaColors.border)),
                ),
                const Expanded(
                  child: Text(
                    'Almost done',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            const SonaStepProgress(currentStep: 8, totalSteps: 8),
          ],
        ),
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: Scrollbar(
          thumbVisibility: true,
          interactive: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            children: [
          const SonaPageTitle('Review your answers', style: SonaTypography.sectionTitle),
          const SizedBox(height: 8),
          const Text(
            'Edit anything before submitting. Your clinician sees this before your call.',
            style: SonaTypography.body,
          ),
          const SizedBox(height: 20),
          _summaryCard('Contact & child', IntakeReviewSummary.contactRows(d), onEdit: () => widget.onEditStep(1)),
          const SizedBox(height: 12),
          _summaryCard('Referral & development', IntakeReviewSummary.referralRows(d), onEdit: () => widget.onEditStep(2)),
          const SizedBox(height: 12),
          _summaryCard('Health & background', IntakeReviewSummary.healthRows(d), onEdit: () => widget.onEditStep(4)),
          const SizedBox(height: 12),
          _consentCard(state),
            ],
          ),
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SonaButton(
          label: widget.busy ? 'Submitting…' : 'Submit',
          onPressed: widget.busy ? null : widget.onSubmit,
        ),
      ),
    );
  }

  Widget _summaryCard(String title, List<(String, String)> rows, {required VoidCallback onEdit}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Edit $title',
                child: TextButton(
                  onPressed: widget.busy ? null : onEdit,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 13, color: SonaColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(r.$1, style: const TextStyle(fontSize: 12, color: SonaColors.textMuted)),
                    ),
                    Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _consentCard(SonaAppState state) {
    final name = state.childName;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Before you submit', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _check(
            "I'm $name's parent/legal guardian and consent to sharing this with Monal Gajjar SLT.",
            state.consentGuardian,
            (v) => setState(() {
              state.consentGuardian = v ?? false;
              state.markDraftDirty();
            }),
          ),
          _check(
            'I agree to the privacy notice and UK data storage.',
            state.consentPrivacy,
            (v) => setState(() {
              state.consentPrivacy = v ?? false;
              state.markDraftDirty();
            }),
          ),
          _check(
            'I confirm the answers are accurate to the best of my knowledge.',
            state.consentAccurate,
            (v) => setState(() {
              state.consentAccurate = v ?? false;
              state.markDraftDirty();
            }),
          ),
        ],
      ),
    );
  }

  Widget _check(String text, bool value, ValueChanged<bool?> onChanged) {
    return InkWell(
      onTap: widget.busy ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: widget.busy ? null : onChanged,
              activeColor: SonaColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(text, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
