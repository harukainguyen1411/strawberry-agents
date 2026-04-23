---
status: proposed
concern: personal
owner: karma
created: 2026-04-22
updated: 2026-04-23
orianna_gate_version: 2
tests_required: true
complexity: quick
tags: [subagents, permissions, reliability, harness, diagnostics]
related:
  - .claude/agents/syndra.md
  - .claude/agents/yuumi.md
  - .claude/agents/lucian.md
  - .claude/agents/talon.md
  - .claude/agents/jayce.md
  - agents/evelynn/CLAUDE.md
---

# Subagent permission-denial reliability — diagnose and mitigate

## 1. Context

During today's Evelynn session, five Sonnet subagents declared with identical `permissionMode: bypassPermissions` frontmatter (Syndra, Yuumi, Lucian, Talon, Jayce) intermittently hit Edit/Write/Bash permission denials that persisted across retries within the same subagent invocation. A full coordinator session restart cleared the condition; 15+ denials were observed across six agent types after roughly 10 subagent dispatches in the same session. The failure correlates with parallel-dispatch load and session-age, not with the agent definition — two Syndra invocations launched minutes apart, identical prompts, saw one succeed and one denied.

Frontmatter is valid (shared with working agents), the Anthropic token is fine (adjacent calls succeed), and the decrypt path is untouched. The flakiness is upstream of our configuration. Hypotheses: (a) Anthropic harness state leak where `bypassPermissions` is dropped after N nested Task invocations in a session; (b) a coarseness bug in `settings.json` permission resolution under concurrent subagent load; (c) resource exhaustion (file descriptor or session token pool) on the coordinator side. We need data before we can pick a mitigation, so this plan is two-phase: diagnostic instrumentation first, then a coordinator-side recovery pattern gated on what phase 1 reveals.

Out of scope: changing any subagent's `permissionMode`, modifying `settings.json` globally, filing upstream Anthropic bugs (that's a follow-up once we have a capture).

## 2. Decision

Land a diagnostic wrapper (`scripts/subagent-denial-probe.sh` plus a `PostToolUse` hook entry) that captures every `permission denied` the harness surfaces to a subagent, with timestamps and dispatch-count context, into `agents/evelynn/journal/subagent-denials-YYYY-MM-DD.jsonl`. After one week of capture (or first reproduction at volume, whichever lands first), read the log and decide between (i) coordinator-side retry-with-fresh-spawn if the pattern is transient, (ii) a hard coordinator-session dispatch-budget (e.g. `/end-session` after N=8 subagent dispatches) if session-age is the dominant factor, or (iii) escalation to Anthropic if the capture shows the harness dropping `bypassPermissions` state.

## 3. Tasks

- **T1** — kind: script | estimate_minutes: 40 | files: `scripts/subagent-denial-probe.sh` (new) <!-- orianna: ok -->, `scripts/hooks/README.md` | detail: POSIX bash script that reads a JSON tool-use event from stdin, checks for `permission denied` / `not allowed` substrings in the result field, and if matched appends a JSONL line with `timestamp`, `agent_name` (from env `CLAUDE_SUBAGENT_NAME` if present), `tool`, `parent_session_id`, and `dispatch_ordinal` to `agents/evelynn/journal/subagent-denials-$(date +%F).jsonl`. Silent pass-through when no match. | DoD: script is executable, passes `shellcheck`, writes a valid JSONL line when fed a synthetic denial fixture, writes nothing when fed a success fixture.
- **T2** — kind: config | estimate_minutes: 20 | files: `.claude/settings.json` | detail: register `scripts/subagent-denial-probe.sh` under `hooks.PostToolUse` with a matcher covering `Edit|Write|Bash` so every subagent tool-result flows through it. Preserve existing hooks. | DoD: `jq` validates the file; a manual end-to-end run (trigger one real denial on a throwaway branch) appends a JSONL row.
- **T3** — kind: doc | estimate_minutes: 15 | files: `agents/evelynn/CLAUDE.md`, `agents/karma/memory/karma.md` | detail: document the capture path and the review cadence (Evelynn checks the journal on each coordinator startup; when the file exceeds 20 rows or one week old, escalate to Karma for phase-2 mitigation selection). | DoD: both files reference the exact JSONL path and the 20-row/one-week trigger.
- **T4** — kind: plan-followup | estimate_minutes: 10 | files: `plans/proposed/personal/2026-04-22-subagent-permission-reliability.md` | detail: once 20+ denial rows are captured, amend this plan (not a new plan) with a phase-2 section listing the chosen mitigation — one of (i) coordinator detects two denials → re-spawns fresh subagent with same prompt; (ii) coordinator enforces dispatch budget; (iii) upstream-bug escalation note + workaround of routing denial-prone tasks to the coordinator directly. Re-run Orianna gate. | DoD: phase-2 section added, signatures refreshed, `status:` still `approved` or bumped to `in-progress`.
- **T5** — kind: test | estimate_minutes: 25 | files: `tests/hooks/test_subagent_denial_probe.sh` (new), `tests/hooks/test_subagent_denial_probe_integration.sh` (new) | detail: xfail tests covering the plan's core invariants: (a) probe exits 0 regardless of input (never blocks a tool call); (b) denial fixture produces exactly one well-formed JSONL row; (c) success fixture produces zero rows; (d) `SubagentStop` fallback path (if activated) also produces valid JSONL from end-of-subagent tool history; (e) `PostToolUse` path and `SubagentStop` path produce identical JSONL schema so downstream analysis is path-agnostic. Commit xfail before T1 implementation per Rule 12. | DoD: all assertions failing xfail; schema contract between probe variants is documented in the test file header.

## 4. Test plan

- **Unit (T1)** — xfail-first test `tests/hooks/test_subagent_denial_probe.sh` (shell) feeds three fixtures to the probe: (a) a realistic denial JSON (shape matches one of today's actual Talon denials), (b) a benign success JSON, (c) a denial with missing `CLAUDE_SUBAGENT_NAME` env. Asserts: (a) appends exactly one JSONL line with all required fields; (b) appends zero lines and exits 0; (c) appends a line with `agent_name: "unknown"`. Invariant: the probe is never the thing that blocks a tool call — exit code is always 0.
- **Integration (T2)** — a manual smoke captured in the T2 DoD: run a deliberate denial (e.g. a Write to a path outside the allowlist on a throwaway branch) and confirm the JSONL row lands. Document the smoke in the T2 commit message.
- **Regression guard** — no existing hook behavior changes; `scripts/install-hooks.sh` is untouched. Re-run the existing hook test suite to confirm.

## 5. Success criteria

- Phase 1 complete when the JSONL capture exists and has at least one real denial recorded with full context (no more empty `stderr` mysteries).
- Phase 2 complete when, post-mitigation, fewer than 1 denial per 20 subagent dispatches is observed over a 7-day rolling window, OR the coordinator demonstrably recovers every denial by fresh-spawn within two retries (deterministic recovery path).
- Either condition satisfies the goal; they are OR'd because we don't yet know if the root cause is fixable from our side.

## 6. Open questions

- Does `PostToolUse` fire for *subagent* tool calls, or only for the parent session's tools? If only the parent, the probe needs to live in a `SubagentStop`-style hook or be wired via each agent's own frontmatter. Resolve empirically in T2.

  **Pivot note (OQ1):** If `PostToolUse` only fires at the parent-session level (not inside the child subagent context), T1 and T2 cannot use it as a live-gate trigger — the parent hook will never see individual subagent Edit/Write/Bash results. Alternative: switch T1 and T2 to a `SubagentStop` hook, which fires when each subagent terminates; the probe then reads the subagent's tool-use history post-hoc and appends any denial rows found. This loses live-intervention capability (we cannot gate the next tool call) but preserves full auditability for phase-2 analysis. Prefer the live `PostToolUse` path if empirical testing in T2 confirms it fires in subagent context; fall back to `SubagentStop` otherwise. Record which path was taken in the T2 commit message.
- Is `CLAUDE_SUBAGENT_NAME` actually set by the harness? If not, T1 falls back to parsing the tool-use event's agent-context field (structure TBD during T1).

## 7. References

- Today's Evelynn session journal (denial incidents): `agents/evelynn/journal/cli-2026-04-21.md`
- Related hook infrastructure: `scripts/install-hooks.sh`, `scripts/hooks/`
- Agent frontmatter reference: `.claude/agents/syndra.md` (known-good `bypassPermissions` example)
