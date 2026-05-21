/// HTTP status acceptance for [SonaApiClient] — extracted for unit tests.
bool isAcceptableHttpStatus(
  int statusCode, {
  int? expected,
  Set<int>? allowedStatuses,
}) {
  final ok = statusCode >= 200 && statusCode < 300;
  final statusOk = allowedStatuses != null
      ? allowedStatuses.contains(statusCode)
      : expected == null || statusCode == expected;
  return ok && statusOk;
}
