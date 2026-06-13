import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';
import 'package:sona/design_system/widgets/trust_row.dart';

/// Parent portal view — frame 07 in Figma.
///
/// DEV-9 redundancy decision: this is the older standalone, in-app demo summary
/// view (static copy, no live data, no magic-link auth). The **canonical family
/// summary delivery is now the authenticated family portal** ([ParentPortalScreen])
/// that the "your summary is ready" email links to — that surface renders the
/// live published summary, the "AI-assisted · reviewed by your clinician" line,
/// resources and check-ins. This screen is retained only as the demo-app
/// `SonaRoute.parentSummary` walkthrough card and is NOT part of the real
/// receive/view flow; it should not gain new clinical wiring. Prefer the portal.
class ParentSummaryScreen extends StatelessWidget {
  const ParentSummaryScreen({
    super.key,
    this.summaryHtml,
    this.onBack,
  });

  final String? summaryHtml;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ParentMobileScaffold(
      header: onBack != null
          ? Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
          const SonaPageTitle("Aria's consultation summary", style: SonaTypography.sectionTitle),
          const SizedBox(height: 8),
          const Text(
            'From Monal Gajjar SLT · Published today',
            style: TextStyle(fontSize: 13, color: SonaColors.textMuted),
          ),
          const SizedBox(height: 20),
          _section('What we discussed', [
            "Aria's speech sounds and how they affect everyday communication",
            'Eating patterns and when to involve other professionals',
          ]),
          const SizedBox(height: 12),
          _section('What happens next', [
            'A formal speech assessment is recommended',
            "We'll share home practice ideas after the assessment",
            'Your next appointment will be booked by the clinic',
          ]),
          const SizedBox(height: 12),
          _section('For you at home', [
            "Repeat back what Aria says — don't correct every sound",
            'Offer one new food alongside a safe favourite',
          ]),
          if (summaryHtml != null && summaryHtml!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SonaColors.heroTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SonaColors.border),
              ),
              child: Text(
                _stripHtml(summaryHtml!),
                style: const TextStyle(fontSize: 13, height: 1.45),
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
                  const Text('• ', style: TextStyle(color: SonaColors.primary, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 14, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
