import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';
import 'package:sona/features/auth/widgets/onboarding_header.dart';

/// Screen 07 — Set Password / Invite accept (Auth·13, Figma node 4:132).
///
/// Landing from the Auth·05 invite email. Verifies the action code, shows the
/// inviter/practice and the read-only email, then sets the password (with live
/// rule checks) and continues to the dashboard. Firebase is injected via
/// callbacks so the screen is testable without a live backend.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({
    super.key,
    required this.oobCode,
    required this.onVerifyCode,
    required this.onSetPassword,
    required this.onCompleted,
    this.inviterName,
    this.practiceName,
    this.role = 'Clinician',
  });

  /// Firebase action code parsed from the invite deep link (Auth·06/14).
  final String oobCode;

  /// Verifies the code and returns the invited email. Throws on invalid/expired.
  final Future<String> Function(String code) onVerifyCode;

  /// Sets the password (confirm reset + sign in + activate, wired in Auth·14).
  final Future<void> Function({required String code, required String password})
      onSetPassword;

  /// Called once the password is set and the user is signed in.
  final VoidCallback onCompleted;

  final String? inviterName;
  final String? practiceName;
  final String role;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  bool _verifying = true;
  bool _invalid = false;
  String _email = '';

  String _password = '';
  String _confirm = '';
  bool _busy = false;
  String? _error;

  bool get _hasTen => _password.length >= 10;
  bool get _hasNumberAndSymbol =>
      RegExp(r'\d').hasMatch(_password) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(_password);
  bool get _matches => _confirm == _password && _password.isNotEmpty;
  bool get _canSubmit => _hasTen && _hasNumberAndSymbol && _matches && !_busy;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      final email = await widget.onVerifyCode(widget.oobCode);
      setState(() {
        _email = email;
        _verifying = false;
      });
    } catch (_) {
      setState(() {
        _invalid = true;
        _verifying = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSetPassword(code: widget.oobCode, password: _password);
      if (!mounted) return;
      widget.onCompleted();
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'expired-action-code' || e.code == 'invalid-action-code') {
          _invalid = true;
        } else {
          _error = e.message ?? 'Could not set your password. Please try again.';
        }
      });
    } catch (_) {
      setState(() => _error = 'Could not set your password. Please try again.');
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
                  child: _verifying
                      ? _loadingCard()
                      : (_invalid ? _invalidCard() : _formCard()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: SonaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SonaColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0F141F29), blurRadius: 24, offset: Offset(0, 8)),
        ],
      );

  Widget _loadingCard() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _invalidCard() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite link invalid or expired',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This invitation link is no longer valid. Ask your practice admin to '
            'resend your invite.',
            style: TextStyle(fontSize: 14, color: SonaColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.inviterName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SonaColors.heroTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Invitation from ${widget.inviterName}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: SonaColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Set your password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You've been added to ${widget.practiceName ?? 'your practice'} as a "
            '${widget.role}. Create a password to access your dashboard.',
            style: const TextStyle(fontSize: 14, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _readonlyEmail(),
          const SizedBox(height: 14),
          SonaTextField(
            label: 'New password',
            value: _password,
            hint: 'At least 10 characters',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (v) => setState(() => _password = v),
          ),
          SonaTextField(
            label: 'Confirm password',
            value: _confirm,
            hint: 'Re-enter your password',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _confirm.isNotEmpty && _confirm != _password
                ? 'Passwords don’t match'
                : null,
            onChanged: (v) => setState(() => _confirm = v),
          ),
          const SizedBox(height: 4),
          _ruleRow('At least 10 characters', _hasTen),
          const SizedBox(height: 4),
          _ruleRow('One number and one symbol', _hasNumberAndSymbol),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: SonaColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: SonaColors.dangerText),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SonaButton(
            label: _busy ? 'Setting password…' : 'Set password & continue',
            onPressed: _canSubmit ? _submit : null,
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

  Widget _readonlyEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SonaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: SonaColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SonaColors.border),
          ),
          child: Text(
            _email,
            style: const TextStyle(fontSize: 14, color: SonaColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _ruleRow(String label, bool met) {
    return Row(
      children: [
        Text(
          '✓',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: met ? SonaColors.successText : SonaColors.chipBorder,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
        ),
      ],
    );
  }
}
