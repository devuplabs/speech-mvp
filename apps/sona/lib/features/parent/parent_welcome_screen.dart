import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/trust_row.dart';
import 'package:sona/test_utils/intake_personas.dart';

class ParentWelcomeScreen extends StatelessWidget {
  const ParentWelcomeScreen({
    super.key,
    this.onGetStarted,
    this.onResume,
    this.hasDraft = false,
    this.linkExpired = false,
    this.intakeLocked = false,
    this.onFillSample,
  });

  final VoidCallback? onGetStarted;
  final VoidCallback? onResume;
  final bool hasDraft;
  final bool linkExpired;
  final bool intakeLocked;

  /// Set by the shell when the build is dev + non-prod; when null the
  /// "Fill with sample data" affordance is not rendered.
  final void Function(IntakePersona persona)? onFillSample;

  @override
  Widget build(BuildContext context) {
    return ParentMobileScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SonaColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monal Gajjar SLT',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Private speech & language therapy',
                    style: TextStyle(fontSize: 11, color: SonaColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (linkExpired) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SonaColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SonaColors.border),
              ),
              child: const Text(
                'This intake link has expired. Contact your clinician for a new link.',
                style: TextStyle(fontSize: 13, color: SonaColors.warningText),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (intakeLocked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SonaColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SonaColors.border),
              ),
              child: const Text(
                'Your clinician has locked this intake. You can no longer edit your answers.',
                style: TextStyle(fontSize: 13, color: SonaColors.warningText),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            height: 168,
            width: double.infinity,
            decoration: BoxDecoration(
              color: SonaColors.heroTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 64,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 8,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: SonaColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: SonaColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'BEFORE WE MEET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SonaColors.primaryDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SonaPageTitle('Tell us about your child', style: SonaTypography.pageTitle),
          const SizedBox(height: 8),
          const Text(
            'A 10-minute form before your free 20-minute consultation. The more we know, the more we can help in the call.',
            style: SonaTypography.body,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SonaColors.trustCardBg,
              border: Border.all(color: SonaColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                TrustRow(
                  title: 'UK data residency',
                  subtitle: 'Encrypted & GDPR-compliant',
                ),
                SizedBox(height: 10),
                TrustRow(
                  title: 'HCPC-registered SLT',
                  subtitle: 'Reviewed by your clinician',
                ),
                SizedBox(height: 10),
                TrustRow(
                  title: 'Parent fills this in',
                  subtitle: 'No screens for kids',
                ),
              ],
            ),
          ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            SonaButton(label: 'Get started', onPressed: onGetStarted),
            if (hasDraft && onResume != null) ...[
              const SizedBox(height: 10),
              SonaButton(
                label: 'Continue where you left off',
                variant: SonaButtonVariant.secondary,
                onPressed: onResume,
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Takes about 10 minutes  ·  Save as you go',
              style: TextStyle(fontSize: 12, color: SonaColors.textMuted, fontWeight: FontWeight.w500),
            ),
            if (onFillSample != null) ...[
              const SizedBox(height: 18),
              _DevFillSampleButton(onFillSample: onFillSample!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dev-only affordance: presents the persona picker and forwards the choice to
/// [onFillSample]. Never built in prod — `SonaAppShell` only passes a non-null
/// `onFillSample` when `kDebugMode` AND the API base URL is not prod.
class _DevFillSampleButton extends StatelessWidget {
  const _DevFillSampleButton({required this.onFillSample});

  final void Function(IntakePersona persona) onFillSample;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SonaColors.warningBg,
        border: Border.all(color: SonaColors.warningText.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DEV ONLY · Fill with sample data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SonaColors.warningText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Synthetic personas only. Never ships to prod.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: SonaColors.textMuted),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _showPicker(context),
            child: const Text('Pick a sample persona'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<IntakePersona>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: intakePersonas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = intakePersonas[i];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(p.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.summary,
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(ctx).pop(p),
                ),
              );
            },
          ),
        );
      },
    );
    if (picked != null) onFillSample(picked);
  }
}
