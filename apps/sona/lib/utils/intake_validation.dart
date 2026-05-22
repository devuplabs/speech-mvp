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

  /// Parses a DD/MM/YYYY string and returns a `DateTime`, or null if invalid.
  static DateTime? parseDdMmYyyy(String value) {
    if (!isDdMmYyyy(value)) return null;
    final parts = value.trim().split('/').map((p) => p.trim()).toList();
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  /// Returns a human-readable age string like "5 years, 3 months" from a
  /// DD/MM/YYYY birth date. Returns null when [dob] is not a valid date or
  /// is in the future relative to [now] (defaults to `DateTime.now()`).
  static String? computeAgeAtReferral(String dob, {DateTime? now}) {
    final birth = parseDdMmYyyy(dob);
    if (birth == null) return null;
    final today = now ?? DateTime.now();
    if (birth.isAfter(today)) return null;

    int years = today.year - birth.year;
    int months = today.month - birth.month;
    if (today.day < birth.day) months--;
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years < 0) return null;

    if (years == 0 && months == 0) return 'less than 1 month';
    if (years == 0) return '$months ${months == 1 ? 'month' : 'months'}';
    if (months == 0) return '$years ${years == 1 ? 'year' : 'years'}';
    return '$years ${years == 1 ? 'year' : 'years'}, $months ${months == 1 ? 'month' : 'months'}';
  }
}
