# Logging policy — no PHI in logs

**Hard rule:** logs must never contain protected health information or anything
that identifies a family. This is a UK GDPR / HCPC requirement and a launch
gate for the customer pilot.

## Never log

- Child or parent **names**, dates of birth, emails, phone numbers, addresses
- **Intake answers** or any free-text a family typed
- **AI draft content** (prep briefs, session plans, summaries, reports) or the
  **prompts/completions** that produce them — prompts embed intake context
- **Magic-link / portal tokens** (they are bearer credentials) — including via
  URL paths; log the route *pattern*, never the concrete path
- Raw request/response bodies, database row dumps, pg error `detail`

## Always fine to log

Opaque identifiers and operational metadata: `requestId`, `caseId`,
`tenantId`, `userId`, route patterns, HTTP status, latency, queue names,
migration IDs, error name/code/stack.

## How this is enforced

- `apps/api/src/logger.ts` is the only logging interface. Context fields pass
  an **allowlist** — anything not on it is silently dropped, so the safe
  behaviour is the default. Errors are reduced to name/message/code/stack.
- `console.*` is banned in API source; `src/__tests__/no-console.test.ts`
  fails CI on regressions.
- Request logging records `c.req.routePath` (e.g. `/v1/intake-links/:token`),
  never the concrete URL.
- LLM failure reasons carry the HTTP status only — response bodies are
  dropped because inference errors can echo the prompt
  (`apps/api/src/llm/chat.ts`).

## Rules when writing code

1. Never interpolate user data into `Error` messages — they end up in logs.
2. Adding a context field to logs? Add it to the allowlist in `logger.ts`
   only if it is an opaque ID or operational metadata, and extend
   `logger.test.ts`.
3. Third-party error trackers (Sentry etc.) count as logs — same rules.
4. Request IDs: pass `x-request-id` across service hops (API → Cloud Tasks →
   worker) so log lines correlate without identifying content.
