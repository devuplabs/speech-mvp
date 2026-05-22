import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/ai_draft_badge.dart';

/// Clinician consult-prep screen.
///
/// Renders the case detail returned by `GET /v1/cases/:id` — including the
/// parent-submitted intake snapshot and the AI-drafted `prep_brief` (probe
/// areas, red flags, references). Falls back to a friendly placeholder when
/// the case has no intake / draft yet so the screen never blanks the rail.
class ClinicianPrepScreen extends StatelessWidget {
  const ClinicianPrepScreen({
    super.key,
    required this.onContinueTriage,
    required this.onBackToday,
    this.caseDetail,
    this.onRefresh,
  });

  /// Shape: `{case: {...}, intake: {...} | null, drafts: [{kind, content, ...}]}`.
  final Map<String, dynamic>? caseDetail;
  final VoidCallback onContinueTriage;
  final VoidCallback onBackToday;
  final Future<void> Function()? onRefresh;

  Map<String, dynamic>? get _case =>
      caseDetail?['case'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _intake =>
      caseDetail?['intake'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _answers =>
      _intake?['answers'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _prepBrief {
    final drafts = (caseDetail?['drafts'] as List?)?.cast<Map<String, dynamic>>();
    if (drafts == null) return null;
    for (final d in drafts) {
      if (d['kind'] == 'prep_brief') {
        return d['content'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  String get _childName {
    final c = _case;
    if (c == null) return 'Client';
    final name = (c['childDisplayName'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return (_answers?['childName'] as String?)?.trim() ?? 'Client';
  }

  String? get _ageAtReferral => (_answers?['ageAtReferral'] as String?)?.trim();

  String? get _parentEmail {
    final c = _case;
    final fromCase = (c?['parentEmail'] as String?)?.trim();
    if (fromCase != null && fromCase.isNotEmpty) return fromCase;
    return (_answers?['email'] as String?)?.trim();
  }

  String? get _parentName {
    final n = (_answers?['motherName'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    return (_answers?['completedBy'] as String?)?.trim();
  }

  String? get _mainConcern => (_answers?['mainConcern'] as String?)?.trim();

  List<String> get _difficulties {
    final raw = _answers?['difficulties'];
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  String? get _intakeStatus {
    final status = _case?['status'] as String?;
    if (status == null) return null;
    return status.replaceAll('_', ' ');
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
              Row(
                children: [
                  TextButton(onPressed: onBackToday, child: const Text('← Today')),
                  const Spacer(),
                  if (onRefresh != null)
                    TextButton(
                      onPressed: () => onRefresh!(),
                      child: const Text('Refresh'),
                    ),
                ],
              ),
              Text('Today / Free consultation · ${_intakeStatus ?? "pending"}',
                  style: const TextStyle(fontSize: 12, color: SonaColors.textMuted)),
              Text('Consult prep · $_childName',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SonaColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('⏱', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _countdownBanner(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SonaColors.warningText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 900;
                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _clientCard(),
                    const SizedBox(height: 16),
                    _prepBriefCard(),
                  ],
                );
                final aside = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _redFlagsPanel(),
                    const SizedBox(height: 16),
                    _referencesPanel(),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: caseDetail == null ? null : onContinueTriage,
                      child: const Text('Mark consult complete → Triage'),
                    ),
                  ],
                );
                if (stack) {
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

  String _countdownBanner() {
    if (caseDetail == null) {
      return 'No case loaded — pick one from Today to load the prep brief.';
    }
    if (_prepBrief == null) {
      return 'Prep brief still drafting · refresh to update.';
    }
    return 'Consult ready · prep brief drafted from this morning\'s intake';
  }

  Widget _clientCard() {
    final age = _ageAtReferral;
    final parent = _parentName;
    final email = _parentEmail;
    final concern = _mainConcern;
    final difficulties = _difficulties;

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
          const Text('Client', style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
          const SizedBox(height: 6),
          Text(
            age == null || age.isEmpty ? _childName : '$_childName · age $age',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (parent != null && parent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email == null || email.isEmpty
                  ? 'Parent: $parent'
                  : 'Parent: $parent · $email',
              style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary),
            ),
          ],
          if (concern != null && concern.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Concern',
                style: TextStyle(
                    fontSize: 11, color: SonaColors.textMuted.withValues(alpha: 0.9))),
            Text(concern,
                style: const TextStyle(fontSize: 13, height: 1.35)),
          ],
          if (difficulties.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Difficulties flagged',
                style: TextStyle(fontSize: 11, color: SonaColors.textMuted)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: difficulties
                  .take(6)
                  .map((d) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SonaColors.heroTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(d,
                            style: const TextStyle(
                                fontSize: 12, color: SonaColors.primaryDark)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _prepBriefCard() {
    final brief = _prepBrief;
    final probes = (brief?['probeAreas'] as List?)?.cast<String>() ?? const [];
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
              Text('Suggested probe areas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Spacer(),
              AiDraftBadge(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          if (probes.isEmpty)
            const Text(
              'No prep brief yet. Once intake is submitted, this fills with parent-derived probe areas.',
              style: TextStyle(fontSize: 13, color: SonaColors.textSecondary, height: 1.4),
            )
          else
            ...probes.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: SonaColors.primary, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(q,
                          style: const TextStyle(fontSize: 14, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _redFlagsPanel() {
    final brief = _prepBrief;
    final flags = (brief?['redFlags'] as List?)?.cast<String>() ?? const [];
    return _panel(
      'Red flags',
      flags.isEmpty
          ? const ['No red flags from intake — confirm in conversation']
          : flags,
      SonaColors.dangerBg,
      SonaColors.dangerText,
    );
  }

  Widget _referencesPanel() {
    final brief = _prepBrief;
    final refs = (brief?['references'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final lines = refs
        .map((r) {
          final title = (r['title'] as String?) ?? '';
          final source = (r['source'] as String?) ?? '';
          if (source.isEmpty) return title;
          return '$source — $title';
        })
        .where((s) => s.isNotEmpty)
        .toList();
    return _panel(
      'References',
      lines.isEmpty
          ? const ['RCSLT — Speech sound disorder']
          : lines,
      SonaColors.heroTint,
      SonaColors.primaryDark,
    );
  }

  Widget _panel(String title, List<String> items, Color bg, Color fg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
          const SizedBox(height: 8),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $i',
                    style: TextStyle(fontSize: 13, color: fg, height: 1.4)),
              )),
        ],
      ),
    );
  }
}
