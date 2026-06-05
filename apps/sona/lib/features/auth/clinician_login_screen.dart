import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';
import 'package:sona/services/api_client.dart' show SonaApiException;
import 'package:sona/utils/intake_validation.dart';

/// Screen 06 — Clinician Login (Auth·12, Figma node 4:100).
///
/// Email/password sign-in plus passwordless magic link and forgot-password.
/// Firebase is injected via callbacks so the screen is testable without a live
/// backend; on success the auth state drives routing (Auth·14).
class ClinicianLoginScreen extends StatefulWidget {
  const ClinicianLoginScreen({
    super.key,
    required this.onPasswordSignIn,
    required this.onMagicLink,
    required this.onForgotPassword,
    this.onSignedIn,
    this.subtitle = 'Sign in to your practice',
  });

  final Future<void> Function({required String email, required String password})
      onPasswordSignIn;
  final Future<void> Function(String email) onMagicLink;
  final Future<void> Function(String email) onForgotPassword;
  final VoidCallback? onSignedIn;
  final String subtitle;

  @override
  State<ClinicianLoginScreen> createState() => _ClinicianLoginScreenState();
}

class _ClinicianLoginScreenState extends State<ClinicianLoginScreen> {
  String _email = '';
  String _password = '';
  bool _busy = false;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  String? _info;

  bool get _emailValid => IntakeValidation.isEmail(_email.trim());

  Future<void> _signIn() async {
    final emailError = _emailValid ? null : 'Enter a valid email address';
    final passwordError = _password.isEmpty ? 'Enter your password' : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _formError = null;
      _info = null;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _busy = true);
    try {
      await widget.onPasswordSignIn(email: _email.trim(), password: _password);
      if (!mounted) return;
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _formError = _signInErrorMessage(e));
    } on SonaApiException {
      setState(() => _formError = 'Your account isn’t ready yet. Contact your admin.');
    } catch (_) {
      setState(() => _formError = 'Could not sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _signInErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
      case 'invalid-email':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your admin.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      default:
        return e.message ?? 'Could not sign in. Please try again.';
    }
  }

  Future<void> _magicLink() async {
    if (!_requireEmail()) return;
    setState(() => _busy = true);
    try {
      await widget.onMagicLink(_email.trim());
      _showInfo('Magic link sent to ${_email.trim()} — check your inbox.');
    } catch (_) {
      setState(() => _formError = 'Could not send the magic link. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (!_requireEmail()) return;
    setState(() => _busy = true);
    try {
      await widget.onForgotPassword(_email.trim());
      _showInfo('Password reset email sent to ${_email.trim()}.');
    } catch (_) {
      setState(() => _formError = 'Could not send the reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _requireEmail() {
    if (_emailValid) {
      setState(() {
        _emailError = null;
        _formError = null;
        _info = null;
      });
      return true;
    }
    setState(() => _emailError = 'Enter your email first');
    return false;
  }

  void _showInfo(String message) {
    if (!mounted) return;
    setState(() {
      _info = message;
      _formError = null;
    });
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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _card(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
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
          Center(
            child: Container(
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
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SonaTextField(
            label: 'Email',
            value: _email,
            hint: 'james@whitfieldspeech.co.uk',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            errorText: _emailError,
            onChanged: (v) => _email = v,
          ),
          SonaTextField(
            label: 'Password',
            value: _password,
            hint: 'Your password',
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            errorText: _passwordError,
            onChanged: (v) => _password = v,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _forgotPassword,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SonaColors.primary,
                ),
              ),
            ),
          ),
          if (_info != null) ...[
            const SizedBox(height: 4),
            _banner(_info!, SonaColors.successBg, SonaColors.successText),
          ],
          if (_formError != null) ...[
            const SizedBox(height: 4),
            _banner(_formError!, SonaColors.dangerBg, SonaColors.dangerText),
          ],
          const SizedBox(height: 12),
          SonaButton(
            label: _busy ? 'Signing in…' : 'Sign in',
            onPressed: _busy ? null : _signIn,
          ),
          const SizedBox(height: 12),
          _orDivider(),
          const SizedBox(height: 12),
          SonaButton(
            label: 'Email me a magic link',
            variant: SonaButtonVariant.secondary,
            onPressed: _busy ? null : _magicLink,
          ),
          const SizedBox(height: 12),
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

  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: SonaColors.border, height: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('or', style: TextStyle(fontSize: 11, color: SonaColors.textMuted)),
        ),
        const Expanded(child: Divider(color: SonaColors.border, height: 1)),
      ],
    );
  }

  Widget _banner(String message, Color bg, Color fg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}
