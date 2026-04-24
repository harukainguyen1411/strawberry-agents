# 2026-04-24 — PR #39 coordinator-boot unification (APPROVE)

## Context

Personal-concern PR: `chore/coordinator-boot-unification` → main. Three-commit TDD-gated
stack unifying the Mac/Windows/alias launcher boot path into a single
`scripts/coordinator-boot.sh`, with explicit identity env-var exports (INV-4),
Signal B (model heuristic) removal from Evelynn/Sona agent defs, and a stateless
PreToolUse Monitor-arming gate that warns coordinators until the inbox watcher is armed.

## Verdict

APPROVE — code quality solid, tests independently reproducible green on C3 HEAD.

## Independent verification

Cloned the branch to `/tmp/pr39-review` and ran all 6 test files. Every group passed:

- `test-monitor-arming-gate-stateless.sh` — 5/5
- `test-monitor-gate-coordinator-scoped.sh` — 10/10 (8 subagents silent; 2 coordinators emit)
- `test-initialprompt-signal-b-absent.sh` — 8/8
- `test-coordinator-boot-identity-export.sh` — 4/4
- `test-inbox-watch-fail-loud.sh` — 3/3
- `test-inbox-watch-scopes-by-env.sh` — 4/4

Matches Jayce's claim of xfail-red at C2 (hit T11/T13/T14/T15) and green at C3.

## What I learned

1. **Stateless gate design is the right pattern for arming semantics.** The gate uses
   a single `[ -f "$sentinel" ]` check per call. No counter, no atomic writes, no
   drift. The sentinel (`/tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}`) is session-
   scoped — created by a PostToolUse hook that fires only when the Monitor tool is
   invoked with `inbox-watch.sh`. Re-entrant safe, fast path when armed is trivial.

2. **Identity resolution order matters for fail-loud discipline.** Both
   `inbox-watch.sh` and `inbox-watch-bootstrap.sh` use the same 2-tier chain:
   `CLAUDE_AGENT_NAME` → `STRAWBERRY_AGENT` → fail-loud (stderr diagnostic + empty
   stdout). Critically the old `.claude/settings.json` `.agent` fallback is
   deliberately removed from the resolution path (but the `.agent` field itself
   stays, per OQ-1 — it's used by Claude Code for agent-routing metadata, not
   for our inbox-scope resolution). Important distinction.

3. **Signal B removal = move model-level heuristic to hook-level determination.**
   The old initialPrompt said "If this is a resumed session (you already have prior
   conversation history above this message)…" — that's the model inspecting its
   context window to decide. The new prompt says "The SessionStart hook has already
   determined whether this is a resumed session — do not make your own judgement."
   This is a real hardening: model-inspection of prior-context is unreliable and
   can be spoofed by the conversation content itself.

4. **POSIX portability (Rule 10) in coordinator-boot.sh handled correctly.** Uses
   `set -eu` only (no pipefail), provides cd-based `realpath` fallback, uses
   `printf '%s' | tr` for case normalization, `case` not `[[`. All patterns work
   on Git Bash for Windows.

5. **Non-blocking style observations I recorded but did not request changes on:**
   - Mac launcher `delegates to coordinator-boot.sh` comment is misleading (it
     inlines the exports and invokes `claude` directly to layer in
     `--dangerously-skip-permissions --remote-control`). Intentional, just the
     comment is wrong. Follow-up not worth a round.
   - `memory-consolidate.sh` failure in boot is silently swallowed via
     `2>&1 || true`. Acceptable (boot must not block) but a one-line stderr warn
     would aid debugging.

## Review URL

https://github.com/harukainguyen1411/strawberry-agents/pull/39#pullrequestreview-4168537199

## Commit SHAs reviewed

- C1 `986bf7f7` — coordinator-boot.sh + launcher identity exports
- C2 `bcf0a5f0` — xfail tests INV-1..INV-6 / AC-1..AC-8
- C3 `e7c92bf1` — harden identity + remove Signal B + wire PreToolUse gate
