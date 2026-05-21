import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/trust_row.dart';

class ParentWelcomeScreen extends StatelessWidget {
  const ParentWelcomeScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

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
          const Text(
            'Tell us about your child',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            'A 10-minute form before your free 20-minute consultation. The more we know, the more we can help in the call.',
            style: TextStyle(fontSize: 14, height: 1.5, color: SonaColors.textSecondary),
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
            const SizedBox(height: 10),
            const Text(
              'Takes about 10 minutes  ·  Save as you go',
              style: TextStyle(fontSize: 12, color: SonaColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
