import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/trust_row.dart';

class ClinicianParentSummaryScreen extends StatelessWidget {
  const ClinicianParentSummaryScreen({
    super.key,
    required this.summaryHtml,
    required this.onBackClinician,
  });

  final String? summaryHtml;
  final VoidCallback onBackClinician;

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
                      const Text(
                        'Aria\'s consultation summary',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'From Monal Gajjar SLT · Published today',
                        style: TextStyle(fontSize: 13, color: SonaColors.textMuted),
                      ),
                      const SizedBox(height: 20),
                      _section('What we discussed', [
                        'Aria\'s speech sounds and how they affect everyday communication',
                        'Eating patterns and when to involve other professionals',
                      ]),
                      const SizedBox(height: 12),
                      _section('What happens next', [
                        'A formal speech assessment is recommended',
                        'We\'ll share home practice ideas after the assessment',
                        'Your next appointment will be booked by the clinic',
                      ]),
                      const SizedBox(height: 12),
                      _section('For you at home', [
                        'Repeat back what Aria says — don\'t correct every sound',
                        'Offer one new food alongside a safe favourite',
                      ]),
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
