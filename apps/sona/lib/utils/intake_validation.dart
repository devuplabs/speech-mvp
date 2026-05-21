/// Client-side intake field validation (aligned with API boundaries).
abstract final class IntakeValidation {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _datePattern = RegExp(r'^\d{1,2}\s*/\s*\d{1,2}\s*/\s*\d{4}$');

  static bool isEmail(String value) {
    final v = value.trim();
    return v.isNotEmpty && _email.hasMatch(v);
  }

  static bool isDdMmYyyy(String value) {
    final v = value.trim();
    if (!_datePattern.hasMatch(v)) return false;
    final parts = v.split('/').map((p) => p.trim()).toList();
    if (parts.length != 3) return false;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return false;
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900 || year > 2100) {
      return false;
    }
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  static String formatDdMmYyyy(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d / $m / ${date.year}';
  }
}
