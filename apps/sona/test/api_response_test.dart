import 'package:flutter_test/flutter_test.dart';
import 'package:sona/utils/api_response.dart';

void main() {
  test('bootstrap reuse: HTTP 200 is acceptable', () {
    expect(
      isAcceptableHttpStatus(200, allowedStatuses: {200, 201}),
      isTrue,
    );
  });

  test('bootstrap create: HTTP 201 is acceptable', () {
    expect(
      isAcceptableHttpStatus(201, allowedStatuses: {200, 201}),
      isTrue,
    );
  });

  test('create case: only 201 is acceptable', () {
    expect(isAcceptableHttpStatus(201, expected: 201), isTrue);
    expect(isAcceptableHttpStatus(200, expected: 201), isFalse);
  });

  test('2xx outside allowed set is rejected', () {
    expect(isAcceptableHttpStatus(204, allowedStatuses: {200, 201}), isFalse);
  });
}
