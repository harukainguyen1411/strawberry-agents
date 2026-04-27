---
plan_id: 2026-04-27-agent-team-mode-comms-discipline
title: Agent Team Mode — Communication Discipline
status: proposed
concern: personal
project: agent-team-mode-comms-discipline
created: 2026-04-27
last_reviewed: 2026-04-27
priority: P1
owner: karma
tier: quick
complexity: quick
orianna_gate_version: 2
tests_required: true
qa_plan: inline
risk: moderate
related_decisions:
  - 2026-04-27-team-mode-sendmessage-contract
  - 2026-04-27-team-mode-tmux-scope
  - 2026-04-27-team-mode-completion-signal
related_plans: []
---

## Context

The Agent Team feature works mechanically but lacks the discipline that turns it into a *team*. Three failure modes recur: (a) teammates answer in their own terminal so the lead is blind, (b) `shutdown_request` gets ignored or silently dropped, leaving `isActive: true` and blocking `TeamDelete`, and (c) when a teammate has already finished prior work, a late-arriving task can be silently swallowed. Three Duong-binding decisions (see frontmatter) collapse the fix-set: SendMessage is the exclusive substantive channel; tmux is a footnote; every inbound task and every shutdown_request requires a typed completion-marker reply.

This plan codifies those decisions across (A) the runbook, (B) the 11 teammate-eligible agent defs, (C) memory + cross-doc cleanups that contradict the new shape, and (D) a structural detection mechanism so violation feels like swimming upstream. The plan is quick-lane — decisions are made, the work is mechanical-but-numerous edits across known files. xfail tests precede impl per Rule 12.

## Decision

- **Completion-marker schema (proposed, OQ3 confirms):** `{type: "task_done"|"shutdown_ack"|"blocked"|"clarification_needed", ref: "<task-id-or-inbound-msg-id>", summary: "<≤150 chars>"}`. Sent via SendMessage to the lead. `task_done` and `shutdown_ack` are the two terminal-state markers; `blocked` and `clarification_needed` are non-terminal but still satisfy the "must reply" obligation.
- **Enforcement mechanism (D, picked):** shared-include rule (`_shared/teammate-lifecycle.md`) added to every teammate-eligible agent def, plus a lightweight PostToolUse hook on the lead's side (`scripts/hooks/posttooluse-teammate-idle-marker.sh`) that flags when a teammate's pane goes idle (`idle_notification` received) without a preceding completion-marker SendMessage in that turn. Self-check + structural detection > pure self-check or pure hook. See task T7.
- **Distribution:** the teammate-lifecycle clause goes via `_shared/teammate-lifecycle.md` include (synced by `scripts/sync-shared-rules.sh`). Per-file edits are restricted to the two contradiction cases (Senna, Lucian) where the existing "self-close as final action" line must be replaced, not just supplemented.
- **Senna/Lucian self-close contradiction:** the existing line is replaced with conditional language: "If running as a teammate (dispatched into a TeamCreate team with a `name` handle), DO NOT self-close on first verdict — emit a `task_done` completion marker via SendMessage and remain alive for re-review turns. Self-close only on `shutdown_request` from the lead, after emitting `shutdown_ack`. If running one-shot (no team_name), self-close on completion as before."

## Tasks

- T1 — kind: test, estimate_minutes: 20, files: `tests/runbook/test_completion_marker_schema.py` (new). <!-- orianna: ok -- prospective path -->
  - detail: xfail test asserting that the runbook §Completion-Marker Protocol section exists and documents the four marker types (`task_done`, `shutdown_ack`, `blocked`, `clarification_needed`) with the schema `{type, ref, summary}`. Parses `runbooks/agent-team-mode.md` for the section heading + a fenced JSON-ish block listing the four type literals. References plan_id in the xfail reason.
  - DoD: test exists, marked xfail with `pytest.mark.xfail(reason="<plan_id>: T2 not landed")`, committed in its own commit on this branch before any T2 work.

- T2 — kind: impl, estimate_minutes: 35, files: `runbooks/agent-team-mode.md`.
  - detail: revise runbook with the following NEW or REWRITTEN sections (slot under existing Policy section, before Failure Modes):
    1. **§ SendMessage Contract** — substantive teammate output MUST go via SendMessage to the lead (or to a peer teammate when peer-to-peer applies). Terminal output is a Duong-only side channel; the lead never reads it; if information is not in a SendMessage, the lead does not have it. Examples of conformant vs non-conformant turns.
    2. **§ Completion-Marker Protocol** — every inbound task message AND every `shutdown_request` requires a typed reply. Schema (per Decision section). Worked example for the stale-task pattern: lead dispatches Task #5 to a teammate that already finished Task #4 and went idle — the teammate, upon receiving #5 in their next turn, MUST emit `{type: "task_done"|"blocked"|...|"clarification_needed", ref: "#5", ...}`. Idle-without-marker is a runbook violation.
    3. **§ Peer-to-peer SendMessage** — supported, full graph in scope. When appropriate: two teammates coordinating a localized handoff (e.g., implementer→reviewer fix-and-recheck loop) where the lead does not need to mediate. When NOT appropriate: scope/priority decisions, cross-cutting structural changes, anything the lead must arbitrate. Always cc the lead via summary marker when a peer-to-peer thread converges.
    4. **§ Failure Modes Appendix** — fold in the React Ink crash on large-prompt teammates (cite `agents/.../learnings/2026-04-26-team-mode-ink-crash-and-tmux-fallback.md`), the missing-`name`-field symptom (spawn returns hex agent_id, not `<name>@<team>`), AND the **TaskList ↔ team-dispatch desynchronization** observed during this plan's own authoring (Karma session 2026-04-27): teammate marks a task `completed` via `TaskUpdate` in turn N; team harness re-dispatches the same task as `task_assignment` in turn N+1. Document the symptom + the protocol response (teammate MUST reply with a completion marker referencing the new task ID — silently swallowing is a violation; the marker reply is what neutralizes the harness bug). Note: this was the first end-to-end validation of the completion-marker protocol — the protocol worked on first invocation.
    5. **tmux footnote** — reduced to a single paragraph noting the existing `teammateMode` escape hatch in `~/.claude/settings.json`. No engineering of tmux-death recovery.
  - DoD: T1 xfail flips to pass when run; runbook diff applied; existing sections preserved.

- T3 — kind: test, estimate_minutes: 15, files: `tests/runbook/test_teammate_lifecycle_include.py` (new). <!-- orianna: ok -- prospective path -->
  - detail: xfail test asserting (i) `_shared/teammate-lifecycle.md` exists, (ii) it contains the required clauses (SendMessage contract self-check, completion-marker obligation on every inbound task + shutdown_request, peer-to-peer guidance pointer, conditional self-close), (iii) all 11 teammate-eligible agent defs (`senna`, `lucian`, `viktor`, `talon`, `rakan`, `jayce`, `vi`, `ekko`, `akali`, `karma`, `yuumi`) embed the include marker.
  - DoD: xfail test committed before T4.

- T4 — kind: impl, estimate_minutes: 25, files: `.claude/agents/_shared/teammate-lifecycle.md` (new). <!-- orianna: ok -- new shared rule file -->
  - detail: author the canonical teammate-lifecycle clause. Sections: (1) Detect mode — if `team_name` injected via dispatch frontmatter or env, you are a teammate; else one-shot. (2) Substantive-output rule — final substantive content of every turn goes via SendMessage. (3) Completion-marker obligation — schema + the four types + stale-task worked example. (4) Conditional self-close — teammate stays alive across turns; self-closes only on `shutdown_request` after emitting `shutdown_ack`. One-shot self-closes on completion as before. (5) Peer-to-peer pointer — refer to runbook §Peer-to-peer SendMessage.
  - DoD: file exists with the clauses; T3 still red until T5 lands.

- T5 — kind: impl, estimate_minutes: 20, files: 11 agent defs under `.claude/agents/` (`senna.md`, `lucian.md`, `viktor.md`, `talon.md`, `rakan.md`, `jayce.md`, `vi.md`, `ekko.md`, `akali.md`, `karma.md`, `yuumi.md`).
  - detail: add `<!-- include: _shared/teammate-lifecycle.md -->` marker block to each. For Senna and Lucian additionally REPLACE the existing self-close-as-final-action line (`senna.md:173`, `lucian.md:143`) with the conditional language from the Decision section. Yuumi gets the include but with a leading note that yuumi is exception-list per evelynn rule (no `/end-subagent-session` — so yuumi's "self-close" rule is a no-op, but the SendMessage-contract and completion-marker obligations still apply when used as a teammate).
  - DoD: T3 flips green; `scripts/sync-shared-rules.sh` runs clean.

- T6 — kind: test, estimate_minutes: 15, files: `tests/runbook/test_stale_rule_cleanups.py` (new). <!-- orianna: ok -- prospective path -->
  - detail: xfail test asserting NEGATIVE — the following stale assertions are absent or amended:
    - `agents/sona/memory/sona.md` lines 33–37: no longer asserts background subagents are universally one-shot without teammate carveout.
    - `agents/evelynn/memory/evelynn.md` line 39: TeamCreate scope is now Policy-aligned ("any work that may iterate"), not "when Duong says have a team".
    - `agents/evelynn/memory/evelynn.md` line 52: agent-self-close rule now references the conditional teammate clause.
    - `agents/memory/agent-network.md`: Communication and Coordination sections reference the runbook + teammate-default mandate.
    - `agents/evelynn/learnings/index.md`: 2026-04-17 deployment-pipeline lesson is amended/superseded with a pointer to the new runbook + a corrected lesson summary.
    - `_shared/sonnet-executor-rules.md` lines 10–11: contains a teammate-mode lifecycle clause (or pointer to `_shared/teammate-lifecycle.md`).
  - DoD: xfail committed before T7.

- T7 — kind: impl, estimate_minutes: 30, files: `agents/sona/memory/sona.md`, `agents/evelynn/memory/evelynn.md`, `agents/memory/agent-network.md`, `agents/evelynn/learnings/index.md`, `.claude/agents/_shared/sonnet-executor-rules.md`.
  - detail: surgical edits per T6 enumeration. For sona memory: rewrite lines 33–37 to qualify "background subagents are one-shot" with "EXCEPT when dispatched into a TeamCreate team with a `name` handle — then teammate lifecycle applies (see runbook)". For evelynn line 39: rewrite TeamCreate scope to match runbook Policy. For line 52: insert "Teammates (any agent dispatched with `team_name` + `name`) follow the teammate lifecycle in `_shared/teammate-lifecycle.md` instead — they self-close ONLY on `shutdown_request` after emitting `shutdown_ack`." For agent-network.md: add a Communication section reference to `runbooks/agent-team-mode.md` and the teammate-default mandate. For evelynn learnings index: amend the 2026-04-17 lesson summary line with "(SUPERSEDED 2026-04-27 — see runbook; teammate dispatches DO survive across turns)". For `_shared/sonnet-executor-rules.md`: insert a one-line pointer "When running as a teammate, see `_shared/teammate-lifecycle.md` for the conditional self-close + completion-marker obligations."
  - DoD: T6 flips green; `scripts/sync-shared-rules.sh` clean.

- T8 — kind: test, estimate_minutes: 20, files: `tests/hooks/test_teammate_idle_marker_hook.sh` (new). <!-- orianna: ok -- prospective path -->
  - detail: xfail test for the detection hook. Synthesizes a fake lead-side event log where a teammate emitted `idle_notification` with no preceding completion-marker SendMessage in the same turn; asserts the hook surfaces a structured warning (stderr line + log entry under `.claude/logs/teammate-idle-marker.log`). Second case: teammate emitted a valid `task_done` marker before going idle — asserts hook stays silent.
  - DoD: xfail committed before T9.

- T9 — kind: impl, estimate_minutes: 30, files: `scripts/hooks/posttooluse-teammate-idle-marker.sh` (new), `.claude/settings.json` (wire under PostToolUse). <!-- orianna: ok -- new hook + settings wiring -->
  - detail: PostToolUse hook firing on the lead's session after `idle_notification` events. Reads the teammate's recent SendMessage stream from the team event store; if no completion-marker (`type` field matching one of the four canonical values) was emitted in the current turn, logs a warning to `.claude/logs/teammate-idle-marker.log` and emits a non-blocking stderr line that the lead's prompt picks up next turn ("Teammate <name> went idle without a completion marker — consider pinging or escalating"). Non-blocking — never aborts a tool call. Lightweight: <50 lines bash.
  - DoD: T8 flips green; hook wired; manual smoke on a two-pane team confirms warning fires on synthetic violation and stays silent on conformant turn.

- T10 — kind: test, estimate_minutes: 10, files: `tests/runbook/test_e2e_demo_recorded.py` (new). <!-- orianna: ok -- prospective path -->
  - detail: xfail test that asserts the existence of a recorded end-to-end demo artifact at `assessments/personal/2026-04-XX-team-mode-comms-e2e-demo.md` containing: team_name, lead identity, ≥2 teammates, full turn-by-turn SendMessage transcript with completion markers, clean shutdown via shutdown_request → shutdown_ack → TeamDelete, no orphaned `isActive: true`. The DoD bullet "shipped guidance has been demonstrated end-to-end on a real team in this repo" is satisfied by this artifact.
  - DoD: xfail committed.

- T11 — kind: impl, estimate_minutes: 45, files: `assessments/personal/2026-04-XX-team-mode-comms-e2e-demo.md` (new). <!-- orianna: ok -- demo artifact -->
  - detail: Talon (or Evelynn herself) runs a real two-teammate team exercising the new discipline end-to-end on a small real task in this repo (suggested: a one-file doc-tidy where reviewer dual-loop converges). Records the transcript per T10 schema. This task is the project's DoD-closer.
  - DoD: T10 flips green; artifact committed; project doc gets a Decisions-log entry confirming DoD met.

## Test plan

xfail-first per Rule 12. Each impl task (T2, T4+T5, T7, T9, T11) is preceded on this branch by its xfail counterpart (T1, T3, T6, T8, T10). Invariants protected:

- **Runbook completeness** (T1) — the protocol layer is documented as code asserts, not just prose; future edits that drop the marker schema break a test.
- **Teammate-lifecycle distribution** (T3) — every teammate-eligible agent def carries the conditional-self-close + completion-marker obligation. New teammate-eligible agents must add the include or this test fires.
- **Stale-rule absence** (T6) — five known-stale lines across memory/learnings/shared rules are asserted gone or amended. Resurrection (e.g., a future memory edit re-introducing "background subagents are universally one-shot") fails CI.
- **Detection mechanism** (T8) — the lead-side warning fires on synthetic violation and stays silent on conformant turn. Hook regressions or schema drift break this.
- **End-to-end demonstration** (T10) — the project DoD's "demonstrated end-to-end on a real team" requirement is gated by a test, not by a verbal claim.

Test runner: pytest for the runbook/include tests (re-using existing `tests/runbook/` pattern if present, else creates the dir); bash test framework already in use under `tests/hooks/` for T8.

## Resolved questions

All six OQs resolved by Duong on 2026-04-27 (concurrence with Karma's picks; Evelynn captured in decision logs `2026-04-27-team-mode-{reviewer-flush-protocol,karma-eligibility,marker-schema,sona-cleanup-scope,coordinator-include,hook-oneshot-scope}.md`). OQ7 (TaskList↔team-dispatch desync) folded into the T2 §Failure Modes Appendix per Duong's go-ahead — protocol response neutralizes the symptom, no separate decision needed.

- **OQ1 — Reviewer flush protocol — RESOLVED (b).** Senna and Lucian flush memory/learnings only on `shutdown_request`. Per-verdict flush would produce partial learnings polluting the next session; shutdown matches natural session-end semantics. Implementation: T5 conditional-self-close clause for senna/lucian explicitly defers flush to shutdown.
- **OQ2 — Karma teammate-eligibility — RESOLVED (b).** Karma stays one-shot by default; teammate is opt-in. The shared-include rule still applies if Karma is dispatched as teammate, but default invocation stays one-shot. Implementation: T4 includes the "detect mode" branch; T5 includes the marker in karma.md without changing default dispatch shape.
- **OQ3 — Completion-marker schema — RESOLVED (a).** Schema confirmed as `{type, ref, summary}` with the four type literals AND an optional `next_action: <string>` field present only on `blocked`. Implementation: T2 §Completion-Marker Protocol documents the optional field; T4 includes it in the schema clause; T8 hook detection accepts markers with or without `next_action`.
- **OQ4 — Sona memory cleanup scope — RESOLVED (a).** Surgical edit only the conflicting lines 33–37. Broader Sona memory refresh — if warranted — files separately on its own merit. Implementation: T7 Sona edit is line-scoped, no other Sona memory changes.
- **OQ5 — Coordinator-defs teammate-lifecycle include — RESOLVED (b).** Defer. Coordinator-of-coordinators pattern does not exist; adding the include implies it does. Implementation: T5's 11-agent list does not include evelynn/sona.
- **OQ6 — Hook scope on one-shot subagents — RESOLVED (a).** Hook ignores `idle_notification` events from one-shot subagents (no `team_name`). Implementation: T9 hook's first-line guard checks for `team_name` in the event metadata and exits 0 if absent.

## References

- Project doc: `projects/personal/active/agent-team-mode-comms-discipline.md`
- Decision logs: `agents/evelynn/memory/decisions/log/2026-04-27-team-mode-sendmessage-contract.md`, `2026-04-27-team-mode-tmux-scope.md`, `2026-04-27-team-mode-completion-signal.md`
- Runbook: `runbooks/agent-team-mode.md`
- Anthropic docs: `https://code.claude.com/docs/en/agent-teams`
- Stale-rule audit findings: see Evelynn dispatch context for this plan (Skarner read-only excavation passes).
- React Ink crash learning: `agents/.../learnings/2026-04-26-team-mode-ink-crash-and-tmux-fallback.md`
