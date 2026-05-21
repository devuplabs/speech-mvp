import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/state/sona_app_state.dart';

class ParentReviewScreen extends StatefulWidget {
  const ParentReviewScreen({
    super.key,
    required this.state,
    required this.onBack,
    required this.onSubmit,
    this.busy = false,
  });

  final SonaAppState state;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool busy;

  @override
  State<ParentReviewScreen> createState() => _ParentReviewScreenState();
}

class _ParentReviewScreenState extends State<ParentReviewScreen> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ParentMobileScaffold(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
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
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              child: LinearProgressIndicator(value: 1, minHeight: 6, color: SonaColors.primary),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        children: [
          const Text('Review your answers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Edit anything before submitting. Your clinician sees this before your call.',
            style: TextStyle(fontSize: 14, color: SonaColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          _summaryCard('About Aria', [
            ('Name', state.childName),
            ('Age', '4y 2m'),
            ('School', "St Anne's Nursery"),
          ]),
          const SizedBox(height: 12),
          _summaryCard('Main concerns', [
            ('Speech sounds', 'Hard to understand R, S'),
            ('Eating', 'Fussy eater; saw dentist'),
            ('EHCP', 'No EHCP in place'),
          ]),
          const SizedBox(height: 12),
          _summaryCard('Strengths', [
            ('Loves', 'Singing, drawing'),
            ('Best with', '1-on-1 attention'),
          ]),
          const SizedBox(height: 12),
          _consentCard(state),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SonaButton(
          label: widget.busy ? 'Submitting…' : 'Submit & book call',
          onPressed: widget.busy ? null : widget.onSubmit,
        ),
      ),
    );
  }

  Widget _summaryCard(String title, List<(String, String)> rows) {
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
              Text('Edit', style: TextStyle(fontSize: 13, color: SonaColors.primary, fontWeight: FontWeight.w600)),
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
            "I'm Aria's parent/legal guardian and consent to sharing this with Monal Gajjar SLT.",
            state.consentGuardian,
            (v) => setState(() => state.consentGuardian = v ?? false),
          ),
          _check(
            'I agree to the privacy notice and UK data storage.',
            state.consentPrivacy,
            (v) => setState(() => state.consentPrivacy = v ?? false),
          ),
          _check(
            'I confirm the answers are accurate to the best of my knowledge.',
            state.consentAccurate,
            (v) => setState(() => state.consentAccurate = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _check(String text, bool value, ValueChanged<bool?> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
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
