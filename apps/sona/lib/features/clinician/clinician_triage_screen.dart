import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/ai_draft_badge.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';

/// One selectable triage outcome (the canonical DEV-10 vocabulary the clinical
/// loop records). [value] is what we POST to `/triage`; [label] / [blurb] are
/// the clinician-facing copy.
class TriageOutcomeOption {
  const TriageOutcomeOption(this.value, this.label, this.blurb);
  final String value;
  final String label;
  final String blurb;
}

/// The four outcomes a clinician can record after the free consultation.
const List<TriageOutcomeOption> kTriageOutcomes = [
  TriageOutcomeOption(
    'strategy_only',
    'Strategies only',
    'Share home strategies; no further sessions needed right now.',
  ),
  TriageOutcomeOption(
    'short_block',
    'Short therapy block',
    'A focused block of sessions to target a specific goal.',
  ),
  TriageOutcomeOption(
    'full_assessment',
    'Full assessment',
    'Book a formal assessment before planning therapy.',
  ),
  TriageOutcomeOption(
    'refer_out',
    'Refer onward',
    'Outside our scope — refer to another service.',
  ),
];

/// Outcomes where a written rationale is mandatory before publishing.
const Set<String> _rationaleRequiredFor = {'full_assessment', 'refer_out'};

class ClinicianTriageScreen extends StatefulWidget {
  const ClinicianTriageScreen({
    super.key,
    required this.onPublishSummary,
    required this.onBackPrep,
    this.caseDetail,
    this.busy = false,
  });

  /// `{case: {...}, intake: {...}, drafts: [...]}` — the case the clinician
  /// clicked on Today / Clients. Header reads the child's display name from
  /// this rather than hardcoding a persona.
  final Map<String, dynamic>? caseDetail;

  /// Fired with the clinician-chosen outcome + rationale when the clinician
  /// publishes the parent summary. The host wires this through
  /// `recordTriage(outcome:, reason:)`.
  final void Function(String outcome, String reason) onPublishSummary;
  final VoidCallback onBackPrep;
  final bool busy;

  @override
  State<ClinicianTriageScreen> createState() => _ClinicianTriageScreenState();
}

class _ClinicianTriageScreenState extends State<ClinicianTriageScreen> {
  /// No outcome is pre-selected — the clinician must make the call.
  String? _outcome;
  final TextEditingController _rationale = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rationale.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _rationale.dispose();
    super.dispose();
  }

  String get _childName {
    final caseMap = widget.caseDetail?['case'] as Map<String, dynamic>?;
    final fromCase = (caseMap?['childDisplayName'] as String?)?.trim();
    if (fromCase != null && fromCase.isNotEmpty) return fromCase;
    final answers =
        widget.caseDetail?['intake']?['answers'] as Map<String, dynamic>?;
    final fromIntake = (answers?['childName'] as String?)?.trim();
    if (fromIntake != null && fromIntake.isNotEmpty) return fromIntake;
    return 'Client';
  }

  bool get _rationaleRequired =>
      _outcome != null && _rationaleRequiredFor.contains(_outcome);

  /// Publish is enabled once an outcome is chosen and — when the outcome
  /// requires it — a non-empty rationale has been entered.
  bool get _canPublish {
    if (_outcome == null) return false;
    if (_rationaleRequired && _rationale.text.trim().isEmpty) return false;
    return true;
  }

  void _publish() {
    final outcome = _outcome;
    if (outcome == null) return;
    widget.onPublishSummary(outcome, _rationale.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
          decoration: const BoxDecoration(
            color: SonaColors.surface,
            border: Border(bottom: BorderSide(color: SonaColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                  onPressed: widget.onBackPrep,
                  child: const Text('← Consult prep')),
              Text(
                '$_childName · Free consultation complete',
                style:
                    const TextStyle(fontSize: 12, color: SonaColors.textMuted),
              ),
              const SonaPageTitle('Triage & session plan',
                  style: SonaTypography.clinicianTitle),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final main = Column(
                  children: [
                    _triageCard(),
                    const SizedBox(height: 16),
                    _planCard(),
                  ],
                );
                final aside = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SonaColors.surface,
                        border: Border.all(color: SonaColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next step',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text(
                            'Record the triage decision, then publish a '
                            'parent-friendly summary to the secure portal. '
                            'No clinical detail in email.',
                            style: TextStyle(
                                fontSize: 13,
                                color: SonaColors.textSecondary,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          (widget.busy || !_canPublish) ? null : _publish,
                      child: Text(
                          widget.busy ? 'Publishing…' : 'Publish parent summary'),
                    ),
                    if (_outcome == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Choose a triage outcome to continue.',
                          style: TextStyle(
                              fontSize: 12, color: SonaColors.textMuted),
                        ),
                      )
                    else if (_rationaleRequired &&
                        _rationale.text.trim().isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'A rationale is required for this outcome.',
                          style: TextStyle(
                              fontSize: 12, color: SonaColors.warningText),
                        ),
                      ),
                  ],
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [main, const SizedBox(height: 24), aside],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: main),
                    const SizedBox(width: 24),
                    Expanded(child: aside),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _triageCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Triage outcome',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Spacer(),
              AiDraftBadge(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          ...kTriageOutcomes.map(_outcomeCard),
          const SizedBox(height: 14),
          TextField(
            controller: _rationale,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _rationaleRequired
                  ? 'Clinical rationale (required)'
                  : 'Clinical rationale',
              hintText:
                  'Why this outcome? e.g. articulation assessment recommended…',
            ),
          ),
        ],
      ),
    );
  }

  Widget _outcomeCard(TriageOutcomeOption option) {
    final selected = _outcome == option.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _outcome = option.value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? SonaColors.navActiveBg : SonaColors.background,
            border: Border.all(
              color: selected ? SonaColors.primary : SonaColors.chipBorder,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color:
                    selected ? SonaColors.primary : SonaColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? SonaColors.primaryDark
                            : SonaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.blurb,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SonaColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Session plan (draft)',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Spacer(),
              AiDraftBadge(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            'Formal assessment — speech sounds (DEAP)',
            'Parent strategies — carry-over at home',
            'Review in 4 weeks',
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: true,
                    onChanged: (_) {},
                    activeColor: SonaColors.primary,
                    semanticLabel: item,
                  ),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
