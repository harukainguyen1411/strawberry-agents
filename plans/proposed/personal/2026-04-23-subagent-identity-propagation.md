---
title: Propagate subagent identity into PreToolUse plan-lifecycle guard via hook JSON agent_type
owner: lux
complexity: quick
tests_required: true
orianna_gate_version: 2
status: proposed
date: 2026-04-23
created: 2026-04-23
concern: personal
tags: [hooks, plan-lifecycle, orianna]
related:
  - plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md
---

## 1. Problem & motivation

PR #31 (merged) shipped `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` as the physical guard for plan-lifecycle moves. The guard reads agent identity from `$CLAUDE_AGENT_NAME` / `$STRAWBERRY_AGENT`. This works when Duong runs `claude --agent orianna` from the CLI — the env var is set on the top-level process.

It does **not** work when a coordinator (Evelynn) dispatches Orianna via `Agent(subagent_type: "orianna")`. Claude Code does not propagate an env var for subagent identity into the subagent's tool-invocation process. The guard reads empty identity, fail-closes, and blocks Orianna's own promotion moves. The approved → implemented promotion of the physical-guard plan itself is currently blocked by this.

## 2. Decision

Teach the guard to read agent identity from a third, authoritative source: the **PreToolUse hook JSON payload's `agent_type` field**, which Claude Code already populates for every subagent-originated tool call (documented in the stable hook contract at https://code.claude.com/docs/en/hooks). No env vars, no new hooks, no identity files, no command-line whitelists. One additional `jq` extraction in the existing guard, added to the identity-resolution chain.

Identity-resolution order (first non-empty wins):

1. `.agent_type` from hook JSON (subagent calls)
2. `$CLAUDE_AGENT_NAME` env var (CLI `--agent` sessions)
3. `$STRAWBERRY_AGENT` env var (legacy fallback)

Everything else in the guard stays identical: case-insensitive lowercase compare against `orianna`, fail-closed when all three are empty on a protected-path access, same reject message.

### Scope — out

- No change to which agents may promote (still Orianna only).
- No change to which paths are protected.
- No change to `.claude/settings.json` hook registration.
- No SessionStart hook, no identity file, no PreToolUse:Agent hook — all unnecessary.
- No command-line env-prefix whitelist for `git mv` — rejected as a spoof door.

## 3. Design

### Why option 1 (hook JSON `agent_type`) is correct

Verified against current Claude Code docs (fetched 2026-04-23 from `https://code.claude.com/docs/en/hooks`):

> When running with `--agent` or inside a subagent, two additional fields are included: `agent_id` (unique identifier for the subagent; present only when the hook fires inside a subagent call) and `agent_type` (agent name, e.g. `"Explore"` or `"security-reviewer"`; present when the session uses `--agent` or the hook fires inside a subagent).

This is part of the documented common-input-fields schema — not experimental, not plugin-scoped. It fires for every PreToolUse invocation originated by a subagent spawned via the Task/Agent tool. The `agent_type` value matches the `subagent_type` argument from `Agent(...)` which, for Orianna dispatched by Evelynn, is `"orianna"`.

### Why the alternatives are worse

- **Option 2 (SessionStart hook writes env var):** `CLAUDE_ENV_FILE` is available in SessionStart, but this is multi-hop (SessionStart → env file → subprocess inheritance) where option 1 is a one-line jq extraction in the hook that already runs at the exact moment identity is needed. No reason to add indirection.
- **Option 3 (command-line env prefix whitelist):** explicitly a spoof door. Any agent could prepend `CLAUDE_AGENT_NAME=orianna git mv …` and bypass. Duong's constraint: must not reintroduce a spoofing door. Rejected.
- **Option 4 (per-session identity file):** SessionStart → tmp file → guard cross-check. Multiple new moving parts, new cleanup surface. Strictly more complex than option 1. Rejected.

### Exact change to the guard

In `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`, resolve identity **after** `_input="$(cat)"` and the jq-parse check, so we have the validated JSON to read from. The current identity block sits at lines 32-37 before stdin is read; it moves to after line 144 (`_tool_name` extraction). Replace:

```bash
_agent="${CLAUDE_AGENT_NAME:-}"
if [ -z "$_agent" ]; then
  _agent="${STRAWBERRY_AGENT:-}"
fi
```

with:

```bash
_agent="$(printf '%s' "$_input" | jq -r '.agent_type // empty' 2>/dev/null)"
if [ -z "$_agent" ]; then
  _agent="${CLAUDE_AGENT_NAME:-}"
fi
if [ -z "$_agent" ]; then
  _agent="${STRAWBERRY_AGENT:-}"
fi
```

Keep `_agent_lc` derivation, `is_orianna`, fail-closed behavior, reject message — all unchanged.

### Spoofing surface analysis

`agent_type` is set by the Claude Code runtime, not by the agent or its tool inputs. An agent cannot forge it inside a `Bash(...)` or `Write(...)` call — the field lives at the hook-payload top level, next to `session_id` / `transcript_path` / `tool_name`, all of which are runtime-controlled. No new spoof door. The CLI-env fallback (`$CLAUDE_AGENT_NAME`) retains its existing trust model (honor-system within the single CLI process Duong launched).

## 4. Non-goals

- Generalizing identity propagation beyond the plan-lifecycle guard. Other hooks (if any) can adopt the same pattern independently.
- Removing the env-var fallbacks. They remain for `claude --agent orianna` CLI sessions where the hook payload would not carry `agent_type` unless `--agent` is passed — and even then, belt-and-suspenders is free.
- Changing the Orianna agent definition or invocation path.

## 5. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Claude Code changes the hook-payload schema and drops `agent_type`. | Env-var fallbacks remain. Test T2 covers both paths independently. Breakage would be detected by `scripts/hooks/test-hooks.sh` in CI the next time the schema changed. |
| A non-Orianna subagent is misnamed `"orianna"` in its agent def. | Existing concern — unchanged by this plan. Agent-def review is the control. |
| `jq` extraction on malformed JSON. | Already handled — the existing `jq '.'` parse check at line 141 fail-closes before identity extraction runs. |

## 6. Tasks

- [ ] **T1 — xfail test for subagent-dispatched identity.** kind: test. estimate_minutes: 10. Files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` (updated). Detail: add two cases — (a) JSON payload includes `"agent_type": "orianna"` with NO env vars set, Bash `git mv plans/proposed/x.md plans/approved/x.md` → expected exit 0; (b) JSON payload includes `"agent_type": "ekko"` with NO env vars set, same `git mv` → expected exit 2. Committed xfail first (current guard fails both). DoD: two new test cases present, both xfail against current `main`. Satisfies Rule 12.

- [ ] **T2 — update guard to read `agent_type` from hook JSON.** kind: impl. estimate_minutes: 15. Files: `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` (updated). Detail: move identity-resolution block to after stdin read + jq-parse validation. Add `.agent_type` as the first source, preserve env-var fallbacks in order. Run shellcheck. DoD: all existing tests green; T1 cases green; shellcheck clean; guard behavior unchanged for CLI-agent and no-identity cases.

- [ ] **T3 — integration test: Orianna dispatched via Agent tool can promote.** kind: test. estimate_minutes: 10. Files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-integration.sh` (updated). Detail: add end-to-end case simulating Evelynn → Orianna dispatch — payload has `"agent_type": "orianna"` with env vars unset; run sequence `Write plans/proposed/personal/x.md` → `Bash git mv plans/proposed/personal/x.md plans/approved/personal/x.md`; both must exit 0. DoD: integrated into `scripts/hooks/test-hooks.sh`; run exits 0.

Total estimate: 35 minutes.

## Test plan

Guard unit tests (`scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh`) exercise the identity chain with (a) JSON `agent_type` only, (b) env var only, (c) both, (d) neither (fail-closed). Integration test (`scripts/hooks/tests/test-pretooluse-plan-lifecycle-integration.sh`) proves the Evelynn → Orianna dispatch path works without any env-var setup. All three new cases fail against `main` until T2 lands — xfail first per Rule 12.

## Rollback

Revert the T2 commit. The guard falls back to env-var-only identity, reproducing today's state (CLI works, subagent dispatch blocked). No data or filesystem state to undo.

## Open questions

- **OQ1** — Should the env-var fallbacks be removed once `agent_type` is confirmed reliable in practice? Recommendation: keep them for a full release cycle (≥ 2 weeks); they're 4 lines, harmless, and provide defense-in-depth against a future Claude Code schema change. Defer removal to a follow-up once we have telemetry.

---

## Orianna approval

**Status:** APPROVED
**Reviewed:** 2026-04-23
**Reviewer:** Orianna (fact-checker)

All load-bearing claims verified against repo state. Identity resolution block confirmed absent of `agent_type` extraction (lines 32-35). Both test scaffolds present without new cases (xfail tasks correctly scoped). Vendor URL citation noted (info-only, non-blocking). No blocks, no warns.

Plan remains at `plans/proposed/personal/` <!-- orianna: ok -- directory path, not a file citation --> — physical move delegated to Duong (admin) per dispatch instructions.
