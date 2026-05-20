# ADR 002 — Flutter client with GenUI (A2UI → Sona API)

**Status:** Accepted  
**Date:** 2026-05-20  
**Updated:** 2026-05-20 — A2UI-only; no Firebase AI Logic branch  
**Supersedes:** Next.js / React assumptions in early `mvp-brief.md` sketches

## Context

- Figma targets **mobile parent** (375×812) and **web clinician** (1440×900).
- AI surfaces need structured, editable UI — not walls of text.
- **PHI must not** reach any LLM from the device.
- **Demo and production** must share one transport and API shape (ADR-004).

## Decision

### Client: **Flutter** (single codebase)

| Surface | Target | Notes |
|---------|--------|--------|
| Parent intake | **Flutter** — iOS, Android, and **Web** | Magic-link deep links. |
| Clinician app | **Flutter Web** (primary) | Passkeys / WebAuthn. |

Figma tokens → `ThemeData` + `apps/sona/lib/design_system/`.

### Generative UI: **GenUI + A2UI → Sona API**

| Item | Choice |
|------|--------|
| UI framework | [`genui`](https://docs.flutter.dev/ai/genui) |
| Server protocol | **[A2UI](https://a2ui.org/)** via [`genui_a2a`](https://pub.dev/packages/genui_a2a) + [`a2a`](https://pub.dev/packages/a2a) |
| Agent / LLM location | **Sona API + self-hosted inference** (ADR-003) — not on device |
| Flutter wiring | `A2uiAgentConnector` or custom transport whose `onSend` posts to **Sona API**; render with `Surface` / `SurfaceController` |

**All environments (dev, stage, prod):** same packages and transport. Dev uses synthetic data against the **dev** API URL; prod uses the **prod** URL — not a different GenUI provider.

**Rejected**

- Firebase AI Logic / Vertex from Flutter.
- `genui_google_generative_ai` client-side keys.
- A separate “demo-only” GenUI stack.

### Backend: **Sona API** on Cloud Run

- **TypeScript** (Hono or Fastify) + OpenAPI → Dart client.
- Implements **A2UI server/agent** side: streams structured UI to Flutter; calls **internal inference** (ADR-003).
- **REST** for non-AI CRUD; **SSE/WebSocket** where A2UI streaming requires it.
- **Cloud Tasks** → worker for async LLM jobs.

### Hosting

| Artifact | Hosting |
|----------|---------|
| **Sona API** | Cloud Run (regional, VPC connector) |
| **Flutter Web** | GCS + Cloud CDN or Firebase Hosting (static only) |
| **Inference** | GKE/GCE private (ADR-003) |

## Consequences

- API team owns A2UI message compatibility with `genui_a2a` version pins.
- No Next.js / React-PDF; PDF via API worker.
- GenUI is **alpha** — pin versions in `pubspec.lock`.

## References

- [GenUI get started — GenUI A2UI](https://docs.flutter.dev/ai/genui/get-started)
- [ADR-003](003-self-hosted-llm-air-gap.md), [ADR-004](004-unified-environments-access.md)
