import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/trust_row.dart';

class ClinicianParentSummaryScreen extends StatelessWidget {
  const ClinicianParentSummaryScreen({
    super.key,
    required this.summaryHtml,
    required this.onBackClinician,
    this.caseDetail,
  });

  final String? summaryHtml;
  final VoidCallback onBackClinician;

  /// `{case: {...}, intake: {...}, drafts: [...]}` — the case the clinician
  /// clicked through to publish. Phone preview shows THAT child's name +
  /// intake-derived content rather than a hardcoded persona.
  final Map<String, dynamic>? caseDetail;

  String get _childName {
    final caseMap = caseDetail?['case'] as Map<String, dynamic>?;
    final fromCase = (caseMap?['childDisplayName'] as String?)?.trim();
    if (fromCase != null && fromCase.isNotEmpty) return fromCase;
    final answers = caseDetail?['intake']?['answers'] as Map<String, dynamic>?;
    final fromIntake = (answers?['childName'] as String?)?.trim();
    if (fromIntake != null && fromIntake.isNotEmpty) return fromIntake;
    return 'your child';
  }

  Map<String, dynamic>? get _answers =>
      caseDetail?['intake']?['answers'] as Map<String, dynamic>?;

  String? get _mainConcern => (_answers?['mainConcern'] as String?)?.trim();
  List<String> get _difficulties {
    final raw = _answers?['difficulties'];
    if (raw is List) return raw.whereType<String>().toList(growable: false);
    return const [];
  }

  /// Top items the clinician (or LLM) added to the session plan — surfaced
  /// to the parent verbatim. Falls back to a small fixed set when no plan
  /// draft is present yet.
  List<String> _planBullets(String key, List<String> fallback) {
    final drafts =
        (caseDetail?['drafts'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
    for (final d in drafts) {
      if (d['kind'] == 'session_plan') {
        final sections =
            (d['content'] as Map<String, dynamic>?)?['sections']
                as Map<String, dynamic>?;
        final list = (sections?[key] as List?)?.cast<String>();
        if (list != null && list.isNotEmpty) return list.take(4).toList();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final preview = ClinicianShellPreview(onBack: onBackClinician);
          final phone = SizedBox(
            width: 375,
            child: ParentMobileScaffold(
              showStatusBar: false,
              body: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: SonaColors.successBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Summary ready',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SonaColors.successText),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "$_childName's consultation summary",
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'From Monal Gajjar SLT · Published today',
                        style: TextStyle(
                            fontSize: 13, color: SonaColors.textMuted),
                      ),
                      const SizedBox(height: 20),
                      _section('What we discussed', _whatWeDiscussedBullets()),
                      const SizedBox(height: 12),
                      _section(
                        'What happens next',
                        _planBullets('goals', const [
                          'A formal speech assessment is recommended',
                          "We'll share home practice ideas after the assessment",
                          'Your next appointment will be booked by the clinic',
                        ]),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        'For you at home',
                        _planBullets('homePractice', const [
                          "Repeat back what your child says — don't correct every sound",
                          'Try one short play session per day',
                        ]),
                      ),
                      if (summaryHtml != null && summaryHtml!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SonaColors.surface,
                            border: Border.all(color: SonaColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Portal HTML loaded (${summaryHtml!.length} chars)',
                            style: const TextStyle(fontSize: 11, color: SonaColors.textMuted),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const TrustRow(
                        title: 'Secure portal',
                        subtitle: 'Sign in with your clinic link — not in email',
                      ),
                    ],
                  ),
            ),
          );
          if (constraints.maxWidth < 800) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [preview, const SizedBox(height: 24), phone],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: preview),
                  const SizedBox(width: 24),
                  phone,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _whatWeDiscussedBullets() {
    final bullets = <String>[];
    final concern = _mainConcern;
    if (concern != null && concern.isNotEmpty) {
      bullets.add('Your main worry: $concern');
    }
    final diffs = _difficulties;
    if (diffs.isNotEmpty) {
      bullets.add('Areas we focused on: ${diffs.take(4).join(", ")}');
    }
    if (bullets.isEmpty) {
      bullets.add('We reviewed the intake answers together and agreed where to start.');
    }
    return bullets;
  }

  Widget _section(String title, List<String> bullets) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: SonaColors.primary)),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 14, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClinicianShellPreview extends StatelessWidget {
  const ClinicianShellPreview({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(onPressed: onBack, child: const Text('← Back to triage')),
          const Text('Parent portal preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Parents open this in the authenticated app — not via email body.',
            style: TextStyle(fontSize: 13, color: SonaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
