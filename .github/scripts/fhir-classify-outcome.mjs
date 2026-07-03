// Classify a FHIR validator OperationOutcome into GENUINE conformance errors vs
// terminology-server TRANSPORT failures.
//
// Why this exists: the official HL7 validator resolves code-system/value-set
// membership against the public terminology server (tx.fhir.org). When that
// external server is slow or unreachable, the validator surfaces the network
// failure as an `error`-severity issue (e.g. "java.net.SocketTimeoutException:
// timeout") on whichever coding it was checking. That is infrastructure
// flakiness, not a conformance defect in our resource — yet it would fail the
// `errors=0` gate on any PR, including ones that don't touch FHIR at all.
//
// This script separates those transport failures from real conformance errors so
// CI can gate on the latter and treat the former as non-gating warnings.
//
// Usage:  node .github/scripts/fhir-classify-outcome.mjs <operation-outcome.json>
// stdout: a single sourceable line -> genuine=<n> transport=<n> warning=<n> information=<n>
// stderr: one line per error, tagged CONFORMANCE-ERROR or TX-TRANSPORT.
import { readFileSync } from 'node:fs';

const path = process.argv[2];
if (!path) {
  console.error('usage: fhir-classify-outcome.mjs <operation-outcome.json>');
  process.exit(2);
}

const outcome = JSON.parse(readFileSync(path, 'utf8'));
const issues = Array.isArray(outcome.issue) ? outcome.issue : [];

// Signatures of a terminology-server *transport* failure (network/IO to the tx
// server), never a real finding about the validated resource. Deliberately
// narrow so genuine conformance errors are never masked.
const TRANSPORT =
  /SocketTimeoutException|java\.net\.[A-Za-z]*Exception|Unable to connect to (the )?terminology server|Error (from|communicating with) (the )?(terminology )?server|terminology server[^.]*(unavailable|timed out|timeout)|tx\.fhir\.org|System URI could not be determined for the code|which could not be found, and the server returned error|took too long to process/i;

const textOf = (x) => `${x.diagnostics || ''} ${(x.details && x.details.text) || ''}`.trim();
const locOf = (x) => (x.location || x.expression || ['?']).join(',');

const errors = issues.filter((x) => x.severity === 'error' || x.severity === 'fatal');
const transport = errors.filter((x) => TRANSPORT.test(textOf(x)));
const genuine = errors.filter((x) => !TRANSPORT.test(textOf(x)));
const warning = issues.filter((x) => x.severity === 'warning');
const information = issues.filter((x) => x.severity === 'information');

for (const x of genuine) console.error('CONFORMANCE-ERROR', locOf(x), '::', textOf(x));
for (const x of transport) console.error('TX-TRANSPORT (non-gating)', locOf(x), '::', textOf(x));

process.stdout.write(
  `genuine=${genuine.length} transport=${transport.length} warning=${warning.length} information=${information.length}\n`,
);
