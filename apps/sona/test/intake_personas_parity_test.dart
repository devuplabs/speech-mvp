import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Dart-side parity check: each persona in `lib/test_utils/intake_personas.dart`
/// must match the canonical JSON at `scripts/personas/<id>.json` field-by-field.
///
/// The sibling Playwright spec at `e2e/tests/personas-parity.spec.ts` covers
/// the TS ↔ JSON edge. Together they enforce the three-way invariant.
void main() {
  // Run from `apps/sona/`, so walk up two dirs to reach repo root.
  final cwd = Directory.current.path;
  final repoRoot = cwd.endsWith('apps/sona') || cwd.endsWith('apps\\sona')
      ? Directory.current.parent.parent.path
      : cwd;
  final personasDir = Directory('$repoRoot/scripts/personas');

  test('every Dart persona has a matching JSON file', () {
    expect(personasDir.existsSync(), isTrue,
        reason: 'Expected scripts/personas to exist at $repoRoot');
    final jsonFiles = personasDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(jsonFiles, hasLength(intakePersonas.length),
        reason: 'JSON file count must match Dart persona count');

    final jsonIds = jsonFiles
        .map((f) => (jsonDecode(f.readAsStringSync()) as Map)['id'] as String)
        .toSet();
    final dartIds = intakePersonas.map((p) => p.id).toSet();
    expect(jsonIds, equals(dartIds));
  });

  for (final p in intakePersonas) {
    test('persona ${p.id} matches scripts/personas/${p.id}.json', () {
      final file = File('${personasDir.path}/${p.id}.json');
      expect(file.existsSync(), isTrue,
          reason: 'Missing JSON mirror for ${p.id} at ${file.path}');
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(raw['id'], equals(p.id));
      expect(raw['label'], equals(p.label));
      expect(raw['summary'], equals(p.summary));
      expect(raw['childDisplayName'], equals(p.childDisplayName));
      expect(raw['parentEmail'], equals(p.parentEmail));

      final jsonAnswers = raw['answers'] as Map<String, dynamic>;
      final dartAnswers = p.answers;

      expect(
        jsonAnswers.keys.toSet(),
        equals(dartAnswers.keys.toSet()),
        reason: 'Key set mismatch for ${p.id}',
      );

      for (final key in dartAnswers.keys) {
        final dv = dartAnswers[key];
        final jv = jsonAnswers[key];
        if (dv is List && jv is List) {
          expect(jv, equals(dv),
              reason: 'List mismatch on ${p.id}.$key');
        } else {
          expect(jv, equals(dv),
              reason: 'Value mismatch on ${p.id}.$key');
        }
      }
    });
  }
}
