---
id: 2026-04-23-inbox-write-guard
title: PreToolUse inbox-write guard — force inbox writes through /agent-ops send
concern: personal
complexity: quick
status: approved
owner: karma
tests_required: true
orianna_gate_version: 2
created: 2026-04-23
---

## Context

Sona hand-wrote an inbox file to Evelynn on 2026-04-23; Duong caught it and made Sona redo via `/agent-ops send`. Direct hand-writing inbox files is a footgun — it sidesteps the schema (frontmatter: `from`, `to`, `priority`, `timestamp`, `status`), the shortid filename convention, and sender-identity verification that `/agent-ops send` enforces.

This plan adds a PreToolUse hook that rejects any `Write` or `Edit`/`MultiEdit` targeting top-level `agents/*/inbox/*.md` <!-- orianna: ok -- prospective guard target pattern -->, with a narrow allowance for `check-inbox`'s legitimate archive flip (status pending -> read) and for admin identity (`Duongntd` / `harukainguyen1411`). Archive-subtree writes (`agents/*/inbox/archive/**`) <!-- orianna: ok -- prospective archive glob --> are allowed — those are produced by `mv` via Bash, but we allow them via direct tools too in case the archival workflow ever needs it.

Pattern mirrors the existing `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` (same identity resolution, same JSON-on-stdin contract, same exit-2 reject semantics).

## Tasks

### T1 — Author the guard script

- Kind: implementation
- Estimate_minutes: 25
- Files: `scripts/hooks/pretooluse-inbox-write-guard.sh` (new). <!-- orianna: ok -- new file, created by this plan -->
- Detail:
  - Read JSON from stdin. Extract `.tool_name` and `.tool_input.file_path` via `jq`.
  - Resolve agent identity: `CLAUDE_AGENT_NAME` then `STRAWBERRY_AGENT`, lowercase.
  - Admin bypass: if identity is `duongntd` or `harukainguyen1411`, exit 0.
  - Target detection: path matches regex `agents/[^/]+/inbox/[^/]+\.md$` <!-- orianna: ok -- regex, not a path --> AND does NOT match `agents/[^/]+/inbox/archive/` <!-- orianna: ok -- regex, not a path -->. If not a target, exit 0.
  - For matched target:
    - `Write` (new file): exit 2 with message `[inbox-write-guard] inbox writes must go through /agent-ops send — direct Write denied`.
    - `Edit` / `MultiEdit`: allow iff the edit is the check-inbox archive flip. Detection rule (keep simple): allow when `.tool_input.old_string` contains `status: pending` AND `.tool_input.new_string` contains `status: read`. Otherwise exit 2 with message `[inbox-write-guard] inbox Edit must be the status pending -> read flip (check-inbox path) or go through /agent-ops send`.
  - POSIX-portable bash, `set -u`, requires `jq`.
- DoD:
  - Script is executable (`chmod +x`).
  - Runs without syntax error under `bash -n`.
  - Follows the same header-comment shape as `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`.

### T2 — Register hook in `.claude/settings.json`

- Kind: configuration
- Estimate_minutes: 10
- Files: `.claude/settings.json`.
- Detail:
  - Under `hooks.PreToolUse` <!-- orianna: ok -- JSON config key, not a path -->, add a new matcher entry for `Write|Edit|MultiEdit` (or extend the existing `Write|Edit|NotebookEdit` matcher to include `MultiEdit` and add the new hook command alongside the plan-lifecycle guard).
  - Prefer adding a separate matcher entry for `Write|Edit|MultiEdit` that runs `bash scripts/hooks/pretooluse-inbox-write-guard.sh` <!-- orianna: ok -- new file from T1 --> to keep the two guards independent.
  - Confirm JSON remains valid (`jq . .claude/settings.json`).
- DoD:
  - Settings file parses clean.
  - New hook entry present and ordered after the lifecycle guard.

### T3 — xfail tests (Rule 12)

- Kind: test
- Estimate_minutes: 30
- Files: `scripts/hooks/tests/pretooluse-inbox-write-guard.test.sh` (new). <!-- orianna: ok -- new file, created by this plan -->
- Detail: Shell-driven harness (same style as `pretooluse-plan-lifecycle-guard` tests). Each case pipes synthetic JSON into the guard and asserts exit code. Commit this file FIRST with the tests expected to fail (script not yet present OR guard logic stubbed) before T1 is merged — TDD per Rule 12.
  - Case a: `Write` to `agents/evelynn/inbox/abc12345.md` <!-- orianna: ok -- synthetic test path --> with no identity set — expect exit 2.
  - Case b: Same `Write` with `CLAUDE_AGENT_NAME=Duongntd` — expect exit 0.
  - Case c: `Edit` on existing `agents/evelynn/inbox/abc12345.md` <!-- orianna: ok -- synthetic test path --> with `old_string` containing `status: pending` and `new_string` containing `status: read` — expect exit 0 (check-inbox flip).
  - Case d: `Write` to `agents/evelynn/inbox/archive/2026-04/abc12345.md` <!-- orianna: ok -- synthetic test path --> — expect exit 0 (archive subtree exempt).
  - Case e (regression): `Edit` on top-level inbox file that changes body but NOT status pending -> read — expect exit 2.
  - Case f: Non-inbox path (e.g. `plans/proposed/personal/foo.md` <!-- orianna: ok -- synthetic example path -->) — expect exit 0 (guard ignores).
- DoD:
  - Test script executable, runs under `bash`.
  - All six cases pass after T1 + T2 ship.
  - Initial commit has the test file but NO implementation — xfail order preserved.

### T4 — Doc update

- Kind: documentation
- Estimate_minutes: 10
- Files: `CLAUDE.md` (add short bullet referencing guard under the inbox/agent-ops context) OR `architecture/inbox-protocol.md` <!-- orianna: ok -- conditional: only referenced if it exists --> if it exists; otherwise append a note to `.claude/skills/agent-ops/SKILL.md`.
- Detail: One-paragraph note: "Direct Write/Edit to `agents/*/inbox/*.md` <!-- orianna: ok -- prospective guard target --> is blocked by `scripts/hooks/pretooluse-inbox-write-guard.sh` <!-- orianna: ok -- new file from T1 -->. Use `/agent-ops send` to deliver inbox messages. The check-inbox status flip (`pending` -> `read`) is the only permitted Edit; archival moves live under `archive/` <!-- orianna: ok -- prospective archive subdir --> and are unguarded."
- DoD:
  - Note committed alongside or after T2.
  - Doc references the script by path and names the admin bypass identities.

## Test plan

Invariants the tests protect:
1. **No direct inbox authorship** — agents cannot hand-write `agents/*/inbox/*.md` <!-- orianna: ok -- prospective guard target pattern -->; the `/agent-ops send` skill is the only sanctioned path for non-admin identities.
2. **Check-inbox still works** — the single legitimate Edit (status pending -> read) is not blocked, so existing inbox-processing workflows keep functioning.
3. **Archive path stays open** — `agents/*/inbox/archive/**` <!-- orianna: ok -- prospective archive glob --> writes are unaffected (future-proofing if archival ever switches from `mv` to Write).
4. **Admin bypass honored** — Duong's admin identities can author inbox files directly for recovery / break-glass operations, consistent with the Rule 19 pattern.
5. **Non-inbox tool calls untouched** — guard is scoped and does not regress other Write/Edit flows.

Tests live in `scripts/hooks/tests/pretooluse-inbox-write-guard.test.sh` <!-- orianna: ok -- new file from T3 --> and run via the existing `scripts/hooks/test-hooks.sh` aggregator (add the new test file to that runner if it enumerates explicitly; otherwise glob pickup is automatic).

## References

- `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` — reference implementation and identity-resolution pattern.
- `.claude/skills/agent-ops/SKILL.md` — the skill this guard forces callers through.
- CLAUDE.md Rule 19 — admin-identity bypass precedent (Orianna).
- Sona inbox relay 2026-04-23 06:36 — original footgun report.

---

<!-- Orianna approval block — 2026-04-23 -->
**APPROVED** by Orianna.
blocks: 0, warns: 0, infos: 4
Promoted-By: Orianna
