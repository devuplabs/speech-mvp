import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/utils/intake_validation.dart';

/// Screen 01 — Admin Sign-up (Auth·07, Figma node 3:2).
///
/// Creates the admin's Firebase account, then the practice + admin seat via
/// `POST /v1/practices`, and hands the new practice id back to the caller to
/// advance to Plan & Seats (screen 02). Firebase is injected via
/// [onCreateAccount] so the screen stays testable without a live Firebase.
class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({
    super.key,
    required this.apiClient,
    required this.onCreateAccount,
    required this.onAccountCreated,
    this.onSignIn,
  });

  final SonaApiClient apiClient;

  /// Creates (and signs in) the Firebase email/password user. Throws
  /// [FirebaseAuthException] on failure.
  final Future<void> Function({required String email, required String password})
      onCreateAccount;

  /// Called with the new practice id + name once the seat is created.
  final void Function(String practiceId, String practiceName) onAccountCreated;

  /// "Already have an account? Sign in" → Clinician Login (screen 06).
  final VoidCallback? onSignIn;

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  String _fullName = '';
  String _email = '';
  String _practiceName = '';
  String _password = '';
  bool _consent = false;
  bool _busy = false;

  String? _fullNameError;
  String? _emailError;
  String? _practiceError;
  String? _passwordError;
  String? _consentError;
  String? _formError;

  /// Password policy: ≥10 chars including a number and a symbol.
  static String? _validatePassword(String value) {
    if (value.length < 10) return 'Use at least 10 characters';
    if (!RegExp(r'\d').hasMatch(value)) return 'Include at least one number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Include at least one symbol';
    }
    return null;
  }

  Future<void> _submit() async {
    final fullNameError = _fullName.trim().isEmpty ? 'Enter your full name' : null;
    final emailError =
        IntakeValidation.isEmail(_email.trim()) ? null : 'Enter a valid email address';
    final practiceError =
        _practiceName.trim().isEmpty ? 'Enter your practice name' : null;
    final passwordError = _validatePassword(_password);
    final consentError =
        _consent ? null : 'Please accept the Terms & GDPR notice to continue';

    setState(() {
      _fullNameError = fullNameError;
      _emailError = emailError;
      _practiceError = practiceError;
      _passwordError = passwordError;
      _consentError = consentError;
      _formError = null;
    });

    if (fullNameError != null ||
        emailError != null ||
        practiceError != null ||
        passwordError != null ||
        consentError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.onCreateAccount(email: _email.trim(), password: _password);
      final body = await widget.apiClient.createPractice(
        practiceName: _practiceName.trim(),
        adminFullName: _fullName.trim(),
        adminEmail: _email.trim(),
      );
      final practice = body['practice'] as Map<String, dynamic>?;
      final id = practice?['id'] as String?;
      if (id == null) {
        setState(() =>
            _formError = 'Unexpected response from the server. Please try again.');
        return;
      }
      if (!mounted) return;
      final name = (practice?['displayName'] as String?)?.isNotEmpty == true
          ? practice!['displayName'] as String
          : _practiceName.trim();
      widget.onAccountCreated(id, name);
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _emailError = 'An account with this email already exists';
          case 'invalid-email':
            _emailError = 'Enter a valid email address';
          case 'weak-password':
            _passwordError = 'Choose a stronger password';
          default:
            _formError =
                e.message ?? 'Could not create your account. Please try again.';
        }
      });
    } on SonaApiException {
      setState(() =>
          _formError = 'Could not create your practice. Please try again.');
    } catch (_) {
      setState(() => _formError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: Column(
        children: [
          const OnboardingHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _card(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SonaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SonaColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F141F29), // rgba(20,31,41,0.06)
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create your practice account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Set up Sona for your group practice. You'll be the admin.",
            style: TextStyle(fontSize: 14, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 18),
          SonaTextField(
            label: 'Full name',
            value: _fullName,
            hint: 'Dr. Sarah Whitfield',
            autofillHints: const [AutofillHints.name],
            errorText: _fullNameError,
            onChanged: (v) => _fullName = v,
          ),
          SonaTextField(
            label: 'Work email',
            value: _email,
            hint: 'sarah@whitfieldspeech.co.uk',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            errorText: _emailError,
            onChanged: (v) => _email = v,
          ),
          SonaTextField(
            label: 'Practice name',
            value: _practiceName,
            hint: 'Whitfield Speech & Language',
            errorText: _practiceError,
            onChanged: (v) => _practiceName = v,
          ),
          SonaTextField(
            label: 'Password',
            value: _password,
            hint: 'At least 10 characters',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _passwordError,
            onChanged: (v) => _password = v,
          ),
          _consentRow(),
          if (_formError != null) ...[
            const SizedBox(height: 12),
            _errorBanner(_formError!),
          ],
          const SizedBox(height: 16),
          SonaButton(
            label: _busy ? 'Creating…' : 'Create account & continue',
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 12),
          _signInRow(),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Secured by Firebase Authentication',
              style: TextStyle(fontSize: 11, color: SonaColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _consentRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _consent = !_consent),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    activeColor: SonaColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'I agree to the Terms & GDPR data processing',
                    style: TextStyle(fontSize: 12, color: SonaColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_consentError != null)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(
              _consentError!,
              style: const TextStyle(fontSize: 12, color: SonaColors.dangerText),
            ),
          ),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SonaColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: SonaColors.dangerText),
      ),
    );
  }

  Widget _signInRow() {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Already have an account?',
            style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
          ),
          TextButton(
          onPressed: widget.onSignIn,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
            child: const Text(
              'Sign in',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SonaColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
