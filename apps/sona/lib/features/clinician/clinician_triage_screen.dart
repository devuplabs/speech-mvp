import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';

/// One of the 4 MVP triage outcomes (matches the API enum).
class TriageOutcome {
  const TriageOutcome(this.id, this.label, this.subtitle);
  final String id;
  final String label;
  final String subtitle;

  static const all = [
    TriageOutcome(
      'strategy_only',
      'Strategy only',
      'Parent-led carryover; no further sessions booked.',
    ),
    TriageOutcome(
      'short_block',
      'Short block',
      '4–6 sessions targeting one or two goals.',
    ),
    TriageOutcome(
      'full_assessment',
      'Full assessment',
      'Standardised assessment then formal plan.',
    ),
    TriageOutcome(
      'refer_out',
      'Refer onward',
      'Direct to NHS / OT / ENT / paediatrician with a written summary.',
    ),
  ];
}

/// Clinician triage capture.
///
/// Surfaces the 4 MVP triage outcomes from `docs/mvp-brief.md`:
/// strategy_only / short_block / full_assessment / refer_out.
///
/// Rehydrates from `caseDetail['triage']` so revisiting the case shows the
/// previously-recorded outcome + reason. Saving POSTs to
/// `/v1/cases/:id/triage`; the parent shell handles drafting the session
/// plan + advancing case status after a successful save.
class ClinicianTriageScreen extends StatefulWidget {
  const ClinicianTriageScreen({
    super.key,
    required this.onSaveTriage,
    required this.onPublishSummary,
    required this.onBackPrep,
    this.caseDetail,
    this.busy = false,
  });

  /// `{case: {...}, intake: {...}, drafts: [...], triage: [...]}`.
  final Map<String, dynamic>? caseDetail;
  final Future<void> Function({required String outcome, required String reason})
      onSaveTriage;
  final VoidCallback onPublishSummary;
  final VoidCallback onBackPrep;
  final bool busy;

  @override
  State<ClinicianTriageScreen> createState() => _ClinicianTriageScreenState();
}

class _ClinicianTriageScreenState extends State<ClinicianTriageScreen> {
  String _selectedOutcome = 'short_block';
  final TextEditingController _reason = TextEditingController();
  bool _initialized = false;

  @override
  void didUpdateWidget(ClinicianTriageScreen old) {
    super.didUpdateWidget(old);
    if (old.caseDetail != widget.caseDetail) _hydrateFromCase();
  }

  @override
  void initState() {
    super.initState();
    _hydrateFromCase();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Pull the latest triage row (if any) and pre-select it. The user can
  /// change the outcome / edit the reason and re-save — the route writes a
  /// fresh row so the audit trail keeps each clinician decision.
  void _hydrateFromCase() {
    if (_initialized) return;
    final triage = (widget.caseDetail?['triage'] as List?)?.cast<Map<String, dynamic>>();
    if (triage == null || triage.isEmpty) {
      _initialized = true;
      return;
    }
    final latest = triage.reduce((a, b) {
      final aAt = a['recordedAt'] as String? ?? '';
      final bAt = b['recordedAt'] as String? ?? '';
      return aAt.compareTo(bAt) > 0 ? a : b;
    });
    setState(() {
      _selectedOutcome = (latest['outcome'] as String?) ?? _selectedOutcome;
      _reason.text = (latest['reason'] as String?) ?? '';
      _initialized = true;
    });
  }

  String? get _childName {
    final c = widget.caseDetail?['case'] as Map<String, dynamic>?;
    final name = (c?['childDisplayName'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final answers = widget.caseDetail?['intake']?['answers'] as Map<String, dynamic>?;
    return (answers?['childName'] as String?)?.trim();
  }

  bool get _alreadyRecorded {
    final triage = (widget.caseDetail?['triage'] as List?)?.cast<Map<String, dynamic>>();
    return triage != null && triage.isNotEmpty;
  }

  Future<void> _save() async {
    if (widget.busy) return;
    await widget.onSaveTriage(
      outcome: _selectedOutcome,
      reason: _reason.text.trim(),
    );
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
              TextButton(onPressed: widget.onBackPrep, child: const Text('← Consult prep')),
              Text(
                _childName == null
                    ? 'Free consultation complete'
                    : '$_childName · Free consultation complete',
                style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
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
                    _outcomePicker(),
                    const SizedBox(height: 16),
                    _reasonCard(),
                  ],
                );
                final aside = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _nextStepCard(),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: widget.busy ? null : _save,
                      child: Text(widget.busy
                          ? 'Saving…'
                          : _alreadyRecorded
                              ? 'Update triage'
                              : 'Save triage'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: widget.busy || !_alreadyRecorded
                          ? null
                          : widget.onPublishSummary,
                      child: const Text('Continue to session plan →'),
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

  Widget _outcomePicker() {
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
          const Text('Triage outcome',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Pick one. Recorded against the case for funnel analytics.',
            style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
          ),
          const SizedBox(height: 12),
          ...TriageOutcome.all.map(_outcomeCard),
        ],
      ),
    );
  }

  Widget _outcomeCard(TriageOutcome opt) {
    final selected = _selectedOutcome == opt.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: widget.busy ? null : () => setState(() => _selectedOutcome = opt.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? SonaColors.heroTint : SonaColors.background,
            border: Border.all(
              color: selected ? SonaColors.primary : SonaColors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? SonaColors.primary : SonaColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? SonaColors.primaryDark : SonaColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(opt.subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: SonaColors.textSecondary, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reasonCard() {
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
          const Text('Reason / notes (internal)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Why this outcome. Not shared with parent. Captured for funnel + audit.',
            style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            maxLines: 4,
            enabled: !widget.busy,
            decoration: const InputDecoration(
              hintText:
                  'Articulation assessment recommended; monitor feeding alongside short block…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextStepCard() {
    final msg = _alreadyRecorded
        ? 'Triage saved. AI-drafted session plan ready in the next step.'
        : 'Pick an outcome and save. The session-plan draft is generated on save.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Next step', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            msg,
            style: const TextStyle(
                fontSize: 13, color: SonaColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
