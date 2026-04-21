# Prompt-injection via WebFetch is field-confirmed, not hypothetical

**Date:** 2026-04-21
**Source:** Lux's WebFetch research session for the daily-agent-repo-audit-routine ADR

## What happened

Lux was researching audit tooling via WebFetch when an injected instruction appeared in the fetched content — a payload embedded in a web page that attempted to redirect Lux's output. Lux identified it and surface it; it was not acted upon. The content of the injection was not reproduced in the transcript.

## Why this matters

Prompt-injection via fetched web content is a known theoretical attack vector but is often dismissed as low-probability in practice. This session provides field evidence that it happens in the wild, against production agent workflows, during routine research tasks — not just in adversarial research settings.

## Chosen mitigation

The daily-agent-repo-audit-routine ADR (`2026-04-21-daily-agent-repo-audit-routine.md`) includes a prompt-injection defense layer:

- **Primary:** ProtectAI `deberta-v3-base-prompt-injection-v2` model via `llm-guard` library. Local inference, no external API, no per-call cost. Runs as a pre-process filter on all WebFetch output before it enters the agent context window.
- **Fallback:** Lakera Guard free tier — API-based, rate-limited, zero cost within quota. Used when local inference is unavailable (Windows mode, resource-constrained environments).

## Operational rules derived

1. WebFetch output should be treated as untrusted content by default — the same trust boundary as user-submitted input.
2. Agents with WebFetch access should use llm-guard or an equivalent sanitizer on all fetched payloads before acting on their content.
3. Research tasks involving unfamiliar third-party sites carry elevated injection risk compared to fetching from known canonical sources (GitHub, docs.anthropic.com, etc.).

## What does NOT change

Agent-to-agent communication within the harness is out of scope for this mitigation — injection via the inter-agent message bus is a separate threat model handled by harness-level message signing (not yet implemented).
