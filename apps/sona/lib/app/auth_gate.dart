import 'package:flutter/material.dart';
import 'package:sona/config/firebase_options.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/services/auth/auth_controller.dart';

/// Gates authenticated (clinician/admin) surfaces behind Firebase auth (Auth·06).
///
/// Behaviour:
/// - If Firebase isn't configured for this build (no `--dart-define`), it falls
///   through to [child] so the existing demo flow and widget tests are
///   unaffected.
/// - Otherwise it shows [signedOut] until a user is authenticated, then renders
///   [child]. The real login UI lands in **Auth·12**; this ships a minimal
///   placeholder so the gate is usable today.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.child,
    this.signedOut,
  });

  final AuthController controller;
  final Widget child;
  final Widget? signedOut;

  @override
  Widget build(BuildContext context) {
    if (!SonaFirebaseOptions.isConfigured) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isSignedIn) return child;
        return signedOut ?? const _SignInPlaceholder();
      },
    );
  }
}

/// Minimal signed-out state — replaced by the Auth·12 Clinician Login screen.
class _SignInPlaceholder extends StatelessWidget {
  const _SignInPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SonaColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to Sona',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Clinician login is coming in the next update.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SonaColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
