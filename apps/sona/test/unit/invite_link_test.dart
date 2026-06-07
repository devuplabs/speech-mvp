import 'package:flutter_test/flutter_test.dart';
import 'package:sona/main.dart';

void main() {
  group('inviteCodeFromUri', () {
    test('returns the oobCode from a password-reset invite link', () {
      final uri = Uri.parse(
        'https://app.sona.dev/auth/accept-invite'
        '?mode=resetPassword&oobCode=ABC123&apiKey=k',
      );
      expect(inviteCodeFromUri(uri), 'ABC123');
    });

    test('accepts an oobCode when no mode is present', () {
      final uri = Uri.parse('https://app.sona.dev/?oobCode=XYZ');
      expect(inviteCodeFromUri(uri), 'XYZ');
    });

    test('ignores non-reset action modes', () {
      final uri = Uri.parse(
        'https://app.sona.dev/?mode=verifyEmail&oobCode=ABC123',
      );
      expect(inviteCodeFromUri(uri), isNull);
    });

    test('returns null when there is no action code', () {
      expect(inviteCodeFromUri(Uri.parse('https://app.sona.dev/')), isNull);
      expect(
        inviteCodeFromUri(Uri.parse('https://app.sona.dev/?oobCode=')),
        isNull,
      );
    });
  });
}
