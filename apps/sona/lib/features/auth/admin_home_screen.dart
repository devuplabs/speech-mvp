import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';

/// Minimal admin landing (Auth·14). Admins land here after login; clinicians
/// never reach it. The clinician workspace is one tap away (admins are also
/// clinicians in the MVP), and admin-only controls live here.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({
    super.key,
    required this.practiceName,
    required this.onOpenWorkspace,
    required this.onSignOut,
    this.onManageClinicians,
  });

  final String practiceName;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onSignOut;
  final VoidCallback? onManageClinicians;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: Column(
        children: [
          const OnboardingHeader(trailingLabel: 'Admin'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    decoration: BoxDecoration(
                      color: SonaColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SonaColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F141F29),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: SonaColors.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          practiceName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: SonaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Manage your practice, seats and clinicians — or jump into the '
                          'clinician workspace.',
                          style: TextStyle(fontSize: 14, color: SonaColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        SonaButton(
                          label: 'Open clinician workspace',
                          onPressed: onOpenWorkspace,
                        ),
                        if (onManageClinicians != null) ...[
                          const SizedBox(height: 12),
                          SonaButton(
                            label: 'Manage clinicians',
                            variant: SonaButtonVariant.secondary,
                            onPressed: onManageClinicians,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SonaButton(
                          label: 'Sign out',
                          variant: SonaButtonVariant.ghost,
                          onPressed: onSignOut,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
