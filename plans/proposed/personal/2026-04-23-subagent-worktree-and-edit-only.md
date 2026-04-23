---
title: Subagent worktree auto-isolation + edit-only breakdown/test-plan agents
owner: karma
complexity: quick
tests_required: true
orianna_gate_version: 2
status: proposed
date: 2026-04-23
concern: personal
---

## Context

Today's session surfaced two recurring failure modes in the agent system that compound each other:

1. **Parallel subagents share the working tree.** When a coordinator dispatches Aphelios + Xayah (or Kayn + Caitlyn) in the same turn for the complex-track breakdown/test-plan slot, both subagents commit directly to `main` from the same checkout. The PR #22 flock protects coordinator-level concurrency only; nothing serializes subagent-level writes. Mitigation today is the coordinator manually setting `isolation: "worktree"` on each Agent call. This morning Evelynn forgot — Duong caught the omission before damage. Manual discipline is fragile.

2. **Breakdown / test-plan agents can `Write` sibling files.** Convention is one plan file per topic with ADR + Tasks + Test plan as inline sections. But Aphelios, Kayn, Xayah, Caitlyn all have `Write` in their tool lists, so they sometimes produce `<plan>-tasks.md` / `<plan>-tests.md` siblings instead of editing the ADR inline. Xayah refused correctly today via shared-rules discipline (D1A); Aphelios needed a mid-run SendMessage correction. Tool-level prevention is more reliable than prose discipline.

Both failures are cheap to close at the system layer rather than relying on human/coordinator vigilance.

## Decision

**Change A — auto-isolation: pick A2 (per-agent-def frontmatter) + A1 (hook reads it).**

Rationale: A1 alone (hook with hardcoded whitelist) couples the hook to the agent roster and rots whenever a new breakdown/test-plan role is added. A2 alone (frontmatter only) has no enforcement. Combining them puts the policy where it belongs (the agent definition declares its own isolation needs) while making enforcement automatic. A3 (manual coordinator skill) is the rejected status quo — today proved it doesn't hold under load.

Mechanism:
- New optional frontmatter field `default_isolation: worktree` on agent defs that should auto-isolate.
- New PreToolUse hook on the `Agent` matcher reads the target subagent's def, and if `default_isolation: worktree` is declared and the tool input lacks an explicit `isolation` value, injects `isolation: "worktree"` into the tool input before dispatch.
- Whitelist set in frontmatter (not the hook): `aphelios`, `kayn`, `xayah`, `caitlyn`. Future breakdown/plan-authoring roles opt in by adding the field.
- Excluded (no field): `yuumi`, `ekko` (errand runners — parallel artifacts in main are intentional), implementers (`jayce`, `viktor`, `seraphine`, `soraka`, `rakan`, `vi`, `talon` — operate on PR branches, not main), coordinators.

**Change B — drop `Write` from the four agent defs.**

Keep `Read`, `Edit`, `Glob`, `Grep`, `Bash`, `Agent`, `WebSearch`, `WebFetch`. They retain full ability to edit the ADR file inline; they lose the ability to create new sibling files. Failure mode becomes a loud tool-permission error instead of a silent convention violation.

Caveat / audit note: the only legitimate "create new file" cases for these roles are (a) writing a learnings file at session end and (b) writing an inbox SendMessage. Both go through skills/scripts that use `Bash` (`tee`, redirected `cat`, or `scripts/inbox-send.sh`), not the `Write` tool. Removing `Write` does not block either path. T2 includes a quick grep audit to confirm no in-repo skill or doc instructs these agents to use `Write` directly.

## Tasks

### T1 — kind: code — estimate_minutes: 25

Add the PreToolUse Agent hook that reads the target subagent's frontmatter and injects worktree isolation when declared.

- Files: `scripts/hooks/agent-default-isolation.sh` (new). <!-- orianna: ok -->
- Files: `.claude/settings.json` (extend the existing PreToolUse `Agent` matcher block to chain the new hook after the existing background-mode guard).
- Detail: hook reads JSON from stdin, extracts `tool_input.subagent_type`, locates `.claude/agents/<type>.md`, parses the YAML frontmatter for `default_isolation: worktree`. If present AND `tool_input.isolation` is unset/empty, emit a JSON response that mutates `tool_input.isolation` to `"worktree"`. If the field is absent or already set, pass through (exit 0, no output). Must be POSIX-portable bash (rule 10): use `awk` or `sed` for YAML extraction, no `yq` dependency.
- DoD: hook script exists, is executable, registered in settings.json, and a manual smoke (echo a fake Agent tool_input JSON for `aphelios` through it) returns the mutated input with `"isolation":"worktree"`.

### T2 — kind: code — estimate_minutes: 15

Drop `Write` from the four breakdown/test-plan agent defs and add `default_isolation: worktree` to all four.

- Files: `.claude/agents/aphelios.md`, `.claude/agents/kayn.md`, `.claude/agents/xayah.md`, `.claude/agents/caitlyn.md`.
- Detail: in each file's frontmatter `tools:` list, remove the `- Write` line. Add a top-level `default_isolation: worktree` key. Quick grep audit: `rg -n 'Write' .claude/agents/{aphelios,kayn,xayah,caitlyn}.md` should return only frontmatter/doc references that no longer instruct tool use. Also `rg -n 'use the Write tool' .claude/skills .claude/agents` to confirm no skill instructs these four to call `Write` directly.
- DoD: four files updated, audit greps clean, no skill references broken.

### T3 — kind: test — estimate_minutes: 20

Add xfail tests covering the three invariants below (INV-1, INV-2, INV-3). Committed BEFORE T1/T2 implementation per rule 12.

- Files: `scripts/hooks/tests/test-agent-default-isolation.sh` (new). <!-- orianna: ok -->
- Files: `scripts/hooks/tests/test-edit-only-agents.sh` (new). <!-- orianna: ok -->
- Detail: shell-based tests. INV-1 test feeds a fake Agent tool_input JSON for each whitelisted subagent through the hook and asserts `isolation` becomes `worktree`; also feeds a non-whitelisted subagent (`yuumi`) and asserts no mutation. INV-2 test greps each of the four agent defs for `^\s*-\s*Write\s*$` in the tools block and asserts zero matches. INV-3 test asserts each of the four defs lacks `Write` in `tools:` (operationally identical to INV-2 — a Write attempt by these agents will fail at the Claude tool-permission layer, which is asserted indirectly via the def). Mark all tests xfail (e.g., `set -e; ! actual_assertion` or comment block referencing this plan + task).
- DoD: tests exist, run red on a clean checkout, reference this plan slug in a comment header.

### T4 — kind: code — estimate_minutes: 5

Wire the new tests into the pre-commit hook test runner (or whichever CI surface runs `scripts/hooks/tests/`).

- Files: `scripts/hooks/tests/run-all.sh` if present, else just verify discovery glob already picks them up.
- Detail: confirm the new test scripts are picked up by whatever currently invokes the `scripts/hooks/tests/` suite. If discovery is glob-based, no edit needed — note that in the DoD.
- DoD: running the hook test suite locally executes the two new tests (red, as expected per T3).

### T5 — kind: docs — estimate_minutes: 10

Document the new `default_isolation` frontmatter field and the edit-only convention.

- Files: `architecture/agent-network.md` or `agents/memory/agent-network.md` (whichever is the canonical roster doc — author should check first).
- Files: `CLAUDE.md` (universal invariants — add a short bullet under existing rules referencing the new auto-isolation behavior; do NOT renumber existing rules).
- Detail: explain the frontmatter field, the four agents that opt in, the rationale (parallel-write race protection + edit-only enforcement). Cross-reference this plan slug.
- DoD: docs updated, plan referenced.

## Test plan

INV-1 — **Auto-isolation fires for whitelisted subagent types.** When the coordinator invokes Aphelios, Kayn, Xayah, or Caitlyn via the Agent tool without an explicit `isolation` argument, the PreToolUse hook injects `isolation: "worktree"` before dispatch. Verified by `scripts/hooks/tests/test-agent-default-isolation.sh` feeding fake tool_input JSON for each whitelisted type and asserting the mutation. Negative case: invoking `yuumi` (no frontmatter field) leaves `isolation` unset.

INV-2 — **`Write` tool absent from the four agent defs.** `aphelios.md`, `kayn.md`, `xayah.md`, `caitlyn.md` do not list `Write` in their `tools:` block. Verified by `scripts/hooks/tests/test-edit-only-agents.sh` grepping each frontmatter.

INV-3 — **Aphelios/Kayn/Xayah/Caitlyn cannot create new files; failure is loud.** Because `Write` is absent from their tool lists, any attempt to call `Write` returns a tool-permission error from the Claude runtime (visible to the coordinator) rather than silently succeeding and producing a sibling `-tasks.md` / `-tests.md` file. Verified structurally by INV-2 (the def is the source of truth for tool permissions); behavioral verification happens the next time one of these agents is invoked end-to-end.

## Open questions

- Should `default_isolation` accept values other than `worktree` (e.g., `branch`, `none`) for future flexibility? Recommendation: ship as a string field, only `worktree` recognized today, ignore unknown values with a stderr warning. Defer richer values until a second use case appears.
- Does the existing PreToolUse Agent hook chain (background-mode guard) already block when its python check fails with exit 2? If yes, the new hook must run BEFORE the guard so that mutation lands even on background-mode rejections — or AFTER, accepting that background-mode rejections skip isolation injection (probably fine — they don't dispatch). T1 author should verify ordering during smoke test.

## References

- `plans/proposed/personal/2026-04-22-subagent-permission-reliability.md` — adjacent subagent-permission hardening (different angle: tool grant reliability).
- PR #22 — coordinator-level flock for the working tree.
- Today's session transcript — Aphelios mid-run SendMessage correction; Xayah D1A discipline hold.
- Universal invariants rules 10 (POSIX bash), 12 (xfail-first).
