import 'package:flutter/material.dart';
import 'package:sona/features/auth/admin_signup_screen.dart';
import 'package:sona/features/auth/invite_clinicians_screen.dart';
import 'package:sona/features/auth/plan_seats_screen.dart';
import 'package:sona/features/auth/practice_config_screen.dart';
import 'package:sona/features/auth/practice_live_screen.dart';
import 'package:sona/services/api_client.dart';

enum OnboardingStep { signup, plan, config, invite, live }

/// Sequences the group-practice onboarding wizard (Auth·07–11) into one flow,
/// threading the new practice id / name / seats between screens (Auth·14).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.apiClient,
    required this.onCreateAccount,
    required this.onComplete,
    this.onSignIn,
  });

  final SonaApiClient apiClient;

  /// Creates (and signs in) the admin's Firebase user.
  final Future<void> Function({required String email, required String password})
      onCreateAccount;

  /// Onboarding finished — route to the admin dashboard.
  final VoidCallback onComplete;

  /// "Already have an account? Sign in".
  final VoidCallback? onSignIn;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingStep _step = OnboardingStep.signup;
  String _practiceId = '';
  String _practiceName = '';
  int _seats = 1;

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case OnboardingStep.signup:
        return AdminSignupScreen(
          apiClient: widget.apiClient,
          onCreateAccount: widget.onCreateAccount,
          onSignIn: widget.onSignIn,
          onAccountCreated: (id, name) => setState(() {
            _practiceId = id;
            _practiceName = name;
            _step = OnboardingStep.plan;
          }),
        );
      case OnboardingStep.plan:
        return PlanSeatsScreen(
          apiClient: widget.apiClient,
          practiceId: _practiceId,
          onContinue: (seats) => setState(() {
            _seats = seats;
            _step = OnboardingStep.config;
          }),
        );
      case OnboardingStep.config:
        return PracticeConfigScreen(
          apiClient: widget.apiClient,
          practiceId: _practiceId,
          initialPracticeName: _practiceName,
          onContinue: () => setState(() => _step = OnboardingStep.invite),
        );
      case OnboardingStep.invite:
        return InviteCliniciansScreen(
          apiClient: widget.apiClient,
          practiceId: _practiceId,
          totalSeats: _seats,
          onFinish: () => setState(() => _step = OnboardingStep.live),
        );
      case OnboardingStep.live:
        return PracticeLiveScreen(
          apiClient: widget.apiClient,
          practiceId: _practiceId,
          practiceName: _practiceName,
          seats: _seats,
          onGoToDashboard: widget.onComplete,
        );
    }
  }
}
