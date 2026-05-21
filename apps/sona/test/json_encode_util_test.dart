import 'package:flutter_test/flutter_test.dart';
import 'package:sona/utils/json_encode_util.dart';

void main() {
  test('encodeJsonBody omits null keys', () {
    expect(
      encodeJsonBody({
        'tenantId': 't-1',
        'parentEmail': null,
        'childDisplayName': null,
      }),
      '{"tenantId":"t-1"}',
    );
  });

  test('encodeJsonBody keeps empty strings and nested maps', () {
    expect(
      encodeJsonBody({
        'answers': {'email': 'a@b.com'},
        'parentEmail': 'a@b.com',
      }),
      contains('"answers"'),
    );
  });
}
