# Last session — 2026-04-20 (session 1)

**What happened:** Planning day. Three ADRs written, committed, pushed on `feat/demo-studio-v3` (`d68df34`):
1. `plans/2026-04-20-session-state-encapsulation.md` — session stays on Service 1, `session_store.py` sole Firestore boundary.
2. `plans/2026-04-20-managed-agent-lifecycle.md` — Anthropic-first scanner, idle 1h warn / 2h terminate, 5-min scan.
3. `plans/2026-04-20-managed-agent-dashboard-tab.md` — second dashboard tab, Anthropic-sourced, orphans visible, terminate button.

Also: `ARCHITECTURE.md` rewritten (same commit range via `a6bf240`), 10 spec drifts flagged vs PR #40. Stray `company-os/secretary/` cleaned up + gitignored (`67281cc`). Local demo-studio-v3 backend verified green on :8080.

## Critical state
- All 3 ADRs depend on **Spike 1** (verify Anthropic SDK: `sessions.list(agent=…)` filter + `lastActivityAt` field). Run spike FIRST next session.
- Shared deliverable = `managed_session_client.py` (used by both lifecycle monitor + dashboard tab).
- Session API stays in-process on Service 1 — NOT a new Cloud Run service, NOT on Service 2.
- SessionStatus migration: `approved` → correct new value, `archived` → `completed` if `outputUrls` set, else `cancelled`.

## Open threads / pickup
- Spike 1 → then Kayn decomposes all 3 ADRs.
- Sona memory mechanism fixes from Ekko (uncommitted in workspace) — commit early next session.
- Strawberry-agents memory fixes (uncommitted in `/Users/duongntd99/Documents/Personal/strawberry-agents`) — commit separately.
- Admin API key + workspace isolation for Anthropic cost report — separate track.

## Rules locked this session
- "We own X" = the whole store, not just the API surface. Ask before splitting ownership.
- Anthropic API is source of truth for managed sessions, NOT our Firestore.
- Orphans (in Anthropic, not in our DB) must be visible + terminable.
- Stray `secretary/` writes from agents with wrong cwd are gitignored in `company-os`.

## Mistakes to avoid
- Don't draft an ADR placing new functionality on someone else's service without confirming ownership first. Wasted a half-loop on "session on Service 2".
- Finalize agent-generated diffs same-session — don't leave them drifting uncommitted.
