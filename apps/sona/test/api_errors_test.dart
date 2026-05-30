import 'package:flutter_test/flutter_test.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/utils/api_errors.dart';

void main() {
  test('parseApiValidationFailure lists all fields with human labels', () {
    const body = '''
{
  "error": "validation_failed",
  "issues": {
    "fieldErrors": {
      "motherEmail": ["Invalid email"],
      "gpPhone": ["String must contain at least 1 character(s)"]
    },
    "formErrors": []
  }
}
''';
    final failure = parseApiValidationFailure(
      SonaApiException(400, body),
    );
    expect(failure, isNotNull);
    expect(failure!.issues.length, 2);
    expect(failure.firstFieldKey, 'motherEmail');
    expect(
      failure.summaryMessage,
      contains("Mother's email"),
    );
    expect(failure.summaryMessage, contains('GP phone'));
    expect(friendlyApiError(SonaApiException(400, body)), failure.summaryMessage);
  });

  test('friendlyApiError includes body excerpt when validation shape is unknown', () {
    const body = '{"error":"validation_failed","issues":{}}';
    final msg = friendlyApiError(SonaApiException(400, body));
    expect(msg, contains('Validation failed'));
    expect(msg, contains('400'));
  });
}
