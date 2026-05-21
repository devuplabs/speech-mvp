import 'dart:convert';

/// JSON body for API requests — omit null keys (Zod `.optional()` rejects JSON `null`).
String encodeJsonBody(Map<String, dynamic> body) =>
    jsonEncode(Map<String, dynamic>.fromEntries(
      body.entries.where((e) => e.value != null),
    ));
