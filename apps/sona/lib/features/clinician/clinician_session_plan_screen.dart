import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/ai_draft_badge.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';

/// AI-drafted first-session plan editor.
///
/// Renders the 5 MVP plan sections — goals, activities, home practice,
/// materials, parent goals — sourced from the `session_plan` draft on the
/// loaded case. Every section is freely editable (add/remove/edit bullets);
/// "Save draft" persists edits; "Save as final" persists + advances the
/// reviewStatus so the parent summary can publish.
///
/// Every clinician artifact carries the "AI-drafted · clinician-reviewed"
/// badge per docs/mvp-brief.md.
class ClinicianSessionPlanScreen extends StatefulWidget {
  const ClinicianSessionPlanScreen({
    super.key,
    required this.onBackTriage,
    required this.onSavePlan,
    required this.onPublishSummary,
    this.caseDetail,
    this.busy = false,
  });

  final Map<String, dynamic>? caseDetail;
  final VoidCallback onBackTriage;
  final VoidCallback onPublishSummary;
  final Future<void> Function({
    required Map<String, List<String>> sections,
    required String reviewStatus,
  }) onSavePlan;
  final bool busy;

  @override
  State<ClinicianSessionPlanScreen> createState() =>
      _ClinicianSessionPlanScreenState();
}

class _ClinicianSessionPlanScreenState
    extends State<ClinicianSessionPlanScreen> {
  Map<String, List<TextEditingController>> _controllers = {};
  String _reviewStatus = 'draft';
  bool _initialized = false;

  static const _orderedSections = [
    _Section('goals', 'Goals'),
    _Section('activities', 'Activities'),
    _Section('homePractice', 'Home practice'),
    _Section('materials', 'Materials'),
    _Section('parentGoals', 'Parent goals'),
  ];

  @override
  void didUpdateWidget(ClinicianSessionPlanScreen old) {
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
    for (final list in _controllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _hydrateFromCase() {
    if (_initialized) return;
    final plan = _planContent();
    final sections = plan?['sections'] as Map<String, dynamic>?;
    final ns = <String, List<TextEditingController>>{};
    for (final s in _orderedSections) {
      final raw = (sections?[s.key] as List?)?.cast<String>() ?? <String>[];
      ns[s.key] = raw.map((v) => TextEditingController(text: v)).toList();
    }
    _controllers = ns;
    _reviewStatus = (plan?['reviewStatus'] as String?) ?? 'draft';
    _initialized = true;
    setState(() {});
  }

  Map<String, dynamic>? _planContent() {
    final drafts = (widget.caseDetail?['drafts'] as List?)?.cast<Map<String, dynamic>>();
    if (drafts == null) return null;
    for (final d in drafts) {
      if (d['kind'] == 'session_plan') {
        return d['content'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  String? get _childName {
    final c = widget.caseDetail?['case'] as Map<String, dynamic>?;
    final n = (c?['childDisplayName'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    final answers = widget.caseDetail?['intake']?['answers'] as Map<String, dynamic>?;
    return (answers?['childName'] as String?)?.trim();
  }

  Map<String, List<String>> _readSections() {
    final out = <String, List<String>>{};
    for (final s in _orderedSections) {
      out[s.key] = (_controllers[s.key] ?? [])
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return out;
  }

  Future<void> _save(String status) async {
    if (widget.busy) return;
    final sections = _readSections();
    await widget.onSavePlan(sections: sections, reviewStatus: status);
    setState(() => _reviewStatus = status);
  }

  void _addItem(String sectionKey) {
    setState(() {
      _controllers.putIfAbsent(sectionKey, () => []);
      _controllers[sectionKey]!.add(TextEditingController());
    });
  }

  void _removeItem(String sectionKey, int index) {
    setState(() {
      final list = _controllers[sectionKey];
      if (list == null || index >= list.length) return;
      list.removeAt(index).dispose();
    });
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
              TextButton(onPressed: widget.onBackTriage, child: const Text('← Triage')),
              Text(
                _childName == null
                    ? 'First session plan'
                    : '$_childName · First session plan',
                style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
              ),
              Row(
                children: [
                  const SonaPageTitle('Session plan',
                      style: SonaTypography.clinicianTitle),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _reviewStatus == 'final'
                          ? SonaColors.successBg
                          : SonaColors.warningBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _reviewStatus == 'final' ? 'FINAL' : 'DRAFT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _reviewStatus == 'final'
                            ? SonaColors.successText
                            : SonaColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  AiDraftBadge(compact: true),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit any bullet, add new ones, or remove. Save draft any '
                      'time; save as final to unlock parent summary.',
                      style: TextStyle(fontSize: 12, color: SonaColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _orderedSections.map(_sectionCard).toList(),
                );
                final aside = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _nextStepCard(),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed:
                          widget.busy ? null : () => _save('draft'),
                      child: const Text('Save draft'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed:
                          widget.busy ? null : () => _save('final'),
                      child: const Text('Save as final'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: widget.busy || _reviewStatus != 'final'
                          ? null
                          : widget.onPublishSummary,
                      child: const Text('Publish parent summary →'),
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

  Widget _sectionCard(_Section s) {
    final controllers = _controllers[s.key] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${controllers.length} item${controllers.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, color: SonaColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (controllers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No items yet. Use Add to seed this section.',
                style: TextStyle(
                    fontSize: 13, color: SonaColors.textMuted.withValues(alpha: 0.9)),
              ),
            )
          else
            ...List.generate(controllers.length, (i) {
              final c = controllers[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 16, right: 6),
                      child: Text('•',
                          style: TextStyle(
                              color: SonaColors.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: c,
                        enabled: !widget.busy,
                        maxLines: null,
                        minLines: 1,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed:
                          widget.busy ? null : () => _removeItem(s.key, i),
                    ),
                  ],
                ),
              );
            }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.busy ? null : () => _addItem(s.key),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextStepCard() {
    final msg = _reviewStatus == 'final'
        ? 'Plan saved as final. Ready to publish parent summary.'
        : 'Edit freely. Save as final once you\'re happy — that unlocks the parent summary publish step.';
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
          const Text('Workflow', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(msg,
              style: const TextStyle(
                  fontSize: 13, color: SonaColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

class _Section {
  const _Section(this.key, this.label);
  final String key;
  final String label;
}
