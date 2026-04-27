---
status: approved
concern: personal
owner: karma
created: 2026-04-27
tier: quick
complexity: simple
qa_plan: none
qa_plan_none_justification: Pure prose-edit work — no executable code, no agent dispatch behavior change, no schemas/scripts; verification is manual via the T10 grep + read pass in §Test plan.
tests_required: false
tags: [agent-team, rules, runbook, prose-edit]
related:
  - assessments/personal/2026-04-27-team-mode-default-rule-patches.md
  - runbooks/agent-team-mode.md
  - agents/memory/duong.md
  - agents/evelynn/CLAUDE.md
  - agents/sona/CLAUDE.md
  - architecture/agent-network-v1/communication.md
  - agents/memory/agent-network.md
  - plans/proposed/personal/2026-04-27-team-mode-foreground-dispatch-carveout.md
  - agents/evelynn/memory/decisions/log/2026-04-27-team-mode-bg-rule-amend-route.md
invariants:
  - The bg-only-dispatch invariant survives — it is now the FALLBACK rule, not the DEFAULT.
  - Foreground one-shot dispatch (no team_name) remains hard-blocked.
  - `runbooks/agent-team-mode.md` becomes the canonical operational policy site for team-mode.
  - `agents/memory/duong.md` retains personal preferences only; no operational runbook content.
---

## Context

Lux's assessment (`assessments/personal/2026-04-27-team-mode-default-rule-patches.md`) inventoried every rule site that biases bg-one-shot dispatch and proposed making `agents/memory/duong.md` §Agent Team mode the canonical-rule site. Duong has reversed that direction: `duong.md` is for personal preferences only; operational runbook rules belong in a runbook.

This plan therefore lifts the team-mode policy out of `duong.md` into `runbooks/agent-team-mode.md` (new top-level §Policy section), then patches the downstream prose sites Lux flagged (A1, A2, B1–B4) to defer to the runbook. The carveout-plan ghost (`plans/proposed/personal/2026-04-27-team-mode-foreground-dispatch-carveout.md`) is deleted — Duong's direction makes it moot (the PreToolUse hook already accepts `bg + team_name` correctly; no carveout needed).

This is pure prose-edit work: no behavior change, no schemas, no scripts, no tests. The PreToolUse Agent hook (A4 in Lux's inventory) is left as-is; the rules now describe the system as it already behaves rather than introducing new mechanism.

**Decisions (open questions Duong delegated):**

- **Fallback friction = medium.** Each fallback to bg one-shot requires a decision-log entry under the coordinator's `memory/decisions/log/` (not just a learning). Duong hates ceremony but values audit trails for things that matter; this matters because silent fallback would erode the team-mode default.
- **Escape-hatch mechanism = none special.** If team mode itself is broken, the escape is "fall back to bg one-shot AND log a decision-log entry titled `team-mode-unavailable-<reason>`." No `.no-team-mode` sentinel file, no flag — the existing fallback path with a justification entry is sufficient.
- **Fallback exception list = confirmed as-is.** Skarner (read-only excavation), Yuumi (errand), Lissandra (script), Orianna (script), single-pass status probes. No additions.
- **B6 (`/end-subagent-session` skill) = no change needed.** Read-pass confirmed: the skill is lifecycle-agnostic. It runs when the subagent decides to close. Teammates receive `{type: "shutdown_request"}` from the lead and at that point self-invoke `/end-subagent-session` exactly as bg one-shots do. The skill text says nothing that conflicts with teammate semantics. No teammate-mode branch required.

## Tasks

### T1 — Lift §Agent Team mode policy into the runbook (new §Policy section)

- **kind:** edit
- **estimate_minutes:** 5
- **files:** `runbooks/agent-team-mode.md`
- **detail:** Insert a new top-level `## Policy` section immediately AFTER the `## TL;DR — the working dispatch shape` section and BEFORE `## Settings — what controls backend selection`. Section content (verbatim — preserves every operational claim from `duong.md` lines 84–92):

  ```markdown
  ## Policy (mandatory for coordinators)

  From 2026-04-27 onward, coordinators (Evelynn, Sona) MUST use the Agent Team feature (`TeamCreate` + Agent dispatch with `team_name`) instead of one-shot background subagents for any work that may iterate.

  - **Spawn into a team, not as a one-shot.** Each new piece of work gets a `TeamCreate` with a descriptive `team_name`; agents are dispatched into that team and stay alive between turns.
  - **A task is "FULLY done" only when the entire build → review → re-review loop has converged green.** If a reviewer requests changes, the build agent's task is NOT done — another change-and-re-review turn must occur on the same teammate before shutdown. Same for QA: a FAIL verdict means the implementer's task is not done; re-dispatch them in-team for the fix.
  - **On full completion, shut down explicitly.** Send `{type: "shutdown_request"}` via `SendMessage` to each teammate, then `TeamDelete` to remove the team. Do not leave idle teammates lingering across unrelated work.
  - **Never declare "done" on partial loop state.** "Code shipped, awaiting review" is not done. "Reviewer LGTM but Akali pending" is not done. "Akali FAIL, fix dispatched" is not done. Done = green-on-all-gates AND merged AND no follow-on rework outstanding.
  - **Fallback exception list.** Ad-hoc one-shot Agent dispatches remain acceptable only for read-only excavation (Skarner), errands (Yuumi), single-pass status probes, and Lissandra/Orianna script-style invocations — work that genuinely cannot iterate.
  - **Fallback requires a justification trail.** Every fall back to bg one-shot dispatch (outside the exception list above) requires a decision-log entry under `agents/<coordinator>/memory/decisions/log/<date>-<slug>.md` documenting (i) which team-mode failure mode fired, (ii) what the fallback dispatch was, (iii) whether a follow-up plan or learning is needed.
  - **Escape hatch when team mode itself is broken.** If `TeamCreate` errors or teammate spawn returns a hex agentId / missing `members[]` / no `<teammate-message>` reply, fall back to bg one-shot AND log a decision-log entry titled `team-mode-unavailable-<reason>`. No special flag or sentinel file needed.
  ```

- **DoD:** New `## Policy` section exists in `runbooks/agent-team-mode.md`, positioned between TL;DR and Settings. Every bullet from `duong.md` lines 84–92 is preserved with no semantic loss.

### T2 — Add §Operational hygiene + post-tmux-reinstall reality update to runbook

- **kind:** edit
- **estimate_minutes:** 4
- **files:** `runbooks/agent-team-mode.md`
- **detail:**
  (a) Update the "Current repo state" line in `## Settings — what controls backend selection`. Replace the existing line:

  > `**Current repo state (2026-04-27):** tmux uninstalled (`brew uninstall tmux`), `teammateMode: "auto"` → all teammates route in-process. Empirically verified.`

  with:

  > `**Current repo state (2026-04-27, post-reinstall):** tmux 3.6a is installed at `/opt/homebrew/bin/tmux`, `teammateMode: "auto"`. Teammates still route in-process because the parent CLI is not launched from inside a tmux session — `auto` only selects tmux when the parent is already inside one. To exercise the tmux backend, launch `claude` from inside `tmux new -s claude`.`

  (b) Insert a new `## Operational hygiene` section immediately BEFORE `## Cross-references` (near the bottom). Content:

  ```markdown
  ## Operational hygiene

  - **Shut down idle teammates promptly when their work is done.** Do not let teammates linger across unrelated work — they consume context window and quietly accumulate stale state. Per the loop-convergence rule in `## Policy` above, "done" means green-on-all-gates AND merged AND no follow-on rework outstanding; once true, send `{type: "shutdown_request"}` to each teammate then `TeamDelete`.
  - **One team per coordinator session.** A lead can only manage one team at a time (per `## Failure modes` Failure 4). Tear down the previous team fully before `TeamCreate` for a new piece of work.
  - **Don't reuse teammates across unrelated work.** A teammate's context is shaped by its initial dispatch prompt. When the work topic shifts, shut them down and dispatch a fresh teammate rather than retasking — the fresh teammate gets a clean prompt aligned to the new work.
  ```

- **DoD:** Settings line reflects post-reinstall reality. `## Operational hygiene` section exists immediately before `## Cross-references`.

### T3 — Delete §Agent Team mode block from `agents/memory/duong.md`

- **kind:** edit
- **estimate_minutes:** 2
- **files:** `agents/memory/duong.md`
- **detail:** Delete lines 84–92 in their entirety (the `## Agent Team mode (mandatory for coordinators)` heading and all bullets beneath it, up to but not including the next `##` heading). The content has been lifted into `runbooks/agent-team-mode.md` §Policy by T1.

  Old block to remove (verbatim — confirm exact match before deleting):

  ```markdown
  ## Agent Team mode (mandatory for coordinators)

  From 2026-04-27 onward, coordinators (Evelynn, Sona) MUST use the **Agent Team feature** (`TeamCreate` + Agent dispatch with `team_name`) instead of one-shot background subagents for any work that may iterate.

  - **Spawn into a team, not as a one-shot.** Each new piece of work gets a `TeamCreate` with a descriptive `team_name`; agents are dispatched into that team and stay alive between turns.
  - **A task is "FULLY done" only when the entire build → review → re-review loop has converged green.** If a reviewer requests changes, the build agent's task is NOT done — another change-and-re-review turn must occur on the same teammate before shutdown. Same for QA: a FAIL verdict means the implementer's task is not done; re-dispatch them in-team for the fix.
  - **On full completion, shut down explicitly.** Send `{type: "shutdown_request"}` via `SendMessage` to each teammate, then `TeamDelete` to remove the team. Do not leave idle teammates lingering across unrelated work.
  - **Never declare "done" on partial loop state.** "Code shipped, awaiting review" is not done. "Reviewer LGTM but Akali pending" is not done. "Akali FAIL, fix dispatched" is not done. Done = green-on-all-gates AND merged AND no follow-on rework outstanding.
  - Ad-hoc one-shot Agent dispatches remain acceptable only for read-only excavation (Skarner), errands (Yuumi), single-pass status probes, and Lissandra/Orianna script-style invocations — work that genuinely cannot iterate.
  ```

- **DoD:** The §Agent Team mode heading and all its bullets no longer exist in `duong.md`. The preceding §Briefing-and-status-check section and the following section (whatever it is) flow contiguously.

### T4 — Patch A1 (`#rule-background-subagents` in `agents/evelynn/CLAUDE.md`)

- **kind:** edit
- **estimate_minutes:** 3
- **files:** `agents/evelynn/CLAUDE.md`
- **detail:** Replace the existing rule body at line 41–42:

  Old:
  ```markdown
  <!-- #rule-background-subagents -->
  **Always run subagents in the background** — Every Agent tool call must include `run_in_background: true`. Never launch a subagent in foreground. Exceptions only when the result is strictly required before any further action can be taken and that dependency cannot be avoided.
  ```

  New:
  ```markdown
  <!-- #rule-background-subagents -->
  **Default to teammate dispatch; background one-shot is the fallback** — Per `runbooks/agent-team-mode.md` §Policy (the canonical mandate), the default dispatch shape for any iterating work is `TeamCreate` + Agent dispatch with `team_name` + `name` + `run_in_background: true` (see runbook §TL;DR for the working shape). Background one-shot dispatch (`run_in_background: true`, no `team_name`) is the fallback — use it only when (a) the work is genuinely one-pass per the runbook's exception list (Skarner read-only excavation, Yuumi errand, single-pass status probe, Lissandra/Orianna script-style), or (b) team mode is empirically not working in this session. Smells that team mode is broken: spawn returns a hex agentId instead of `<name>@<team>`; teammate not present in `~/.claude/teams/<team>/config.json` `members[]`; `SendMessage` produces no `<teammate-message>` reply within the expected turn; `TeamCreate` itself errors. On any fallback (outside the exception list), write a decision-log entry under `agents/evelynn/memory/decisions/log/<date>-<slug>.md` documenting which failure mode fired and what the fallback dispatch was. Foreground dispatch remains hard-blocked by the PreToolUse hook unless `team_name` is set.
  ```

- **DoD:** Rule anchor `#rule-background-subagents` survives. Body cites `runbooks/agent-team-mode.md` §Policy as canonical. Fallback smells and justification-trail requirement are present.

### T5 — Patch A2 (`#rule-sona-background-subagents` in `agents/sona/CLAUDE.md`)

- **kind:** edit
- **estimate_minutes:** 3
- **files:** `agents/sona/CLAUDE.md`
- **detail:** Replace the existing rule body at line 40–41:

  Old:
  ```markdown
  <!-- #rule-sona-background-subagents -->
  **Always run subagents in the background** — Every Agent tool call must include `run_in_background: true`. Foreground only when a result is strictly required before any further action and that dependency cannot be avoided. Background subagents are one-shot; `SendMessage` after termination drops silently. Re-spawn with full context.
  ```

  New:
  ```markdown
  <!-- #rule-sona-background-subagents -->
  **Default to teammate dispatch; background one-shot is the fallback** — Per `runbooks/agent-team-mode.md` §Policy (the canonical mandate), the default dispatch shape for any iterating work is `TeamCreate` + Agent dispatch with `team_name` + `name` + `run_in_background: true` (see runbook §TL;DR for the working shape). Background one-shot dispatch (`run_in_background: true`, no `team_name`) is the fallback — use it only when (a) the work is genuinely one-pass per the runbook's exception list (Skarner read-only excavation, Yuumi errand, single-pass status probe, Lissandra/Orianna script-style), or (b) team mode is empirically not working in this session. Smells that team mode is broken: spawn returns a hex agentId instead of `<name>@<team>`; teammate not present in `~/.claude/teams/<team>/config.json` `members[]`; `SendMessage` produces no `<teammate-message>` reply within the expected turn; `TeamCreate` itself errors. On any fallback (outside the exception list), write a decision-log entry under `agents/sona/memory/decisions/log/<date>-<slug>.md` documenting which failure mode fired and what the fallback dispatch was. **For bg fallback dispatches only:** subagents are one-shot; `SendMessage` after termination drops silently; re-spawn with full context. Teammates dispatched via `team_name` do NOT have this lifecycle — they persist between turns and stay reachable via `SendMessage`. Foreground dispatch remains hard-blocked by the PreToolUse hook unless `team_name` is set.
  ```

- **DoD:** Rule anchor `#rule-sona-background-subagents` survives. Body cites `runbooks/agent-team-mode.md` §Policy. The "one-shot / SendMessage drops silently" sentence is scoped explicitly to bg fallback (no longer misdescribes teammates). Decision-log path is `agents/sona/memory/decisions/log/`.

### T6 — Patch B1 (`#rule-prefer-roster-agents` in `agents/evelynn/CLAUDE.md`)

- **kind:** edit
- **estimate_minutes:** 2
- **files:** `agents/evelynn/CLAUDE.md`
- **detail:** Replace the trailing sentence of `#rule-prefer-roster-agents` body (line 45):

  Old (final sentence of the body paragraph):
  ```markdown
  Run roster agents in the background with `run_in_background: true` unless their output is needed before proceeding.
  ```

  New (final sentence of the body paragraph):
  ```markdown
  Dispatch shape (teammate-default vs bg-fallback) is governed by `#rule-background-subagents` above.
  ```

  Leave the rest of the rule body and the agent roster lists below it unchanged.

- **DoD:** The bg-default sub-clause is removed; B1 now defers to A1 (T4). Anchor and roster lists unchanged.

### T7 — Patch B3 (`architecture/agent-network-v1/communication.md`)

- **kind:** edit
- **estimate_minutes:** 2
- **files:** `architecture/agent-network-v1/communication.md`
- **detail:** Replace the existing line 17:

  Old:
  ```markdown
  All background subagents run with `run_in_background: true`. Foreground dispatch is reserved for results strictly needed before any further action can be taken.
  ```

  New:
  ```markdown
  Dispatch shape is governed by `runbooks/agent-team-mode.md` §Policy — teammate dispatch (`TeamCreate` + Agent with `team_name` + `name` + `run_in_background: true`) is the default for iterating work; background one-shot (`run_in_background: true`, no `team_name`) is the fallback. Foreground dispatch is hard-blocked by the PreToolUse hook unless `team_name` is set.
  ```

- **DoD:** Line 17 cites the runbook as canonical; the architecture doc no longer carries stale bg-only framing.

### T8 — Patch B4 (final-message rule in `agents/memory/agent-network.md`)

- **kind:** edit
- **estimate_minutes:** 3
- **files:** `agents/memory/agent-network.md`
- **detail:** Replace lines 221–229 (the `### Final-message rule (applies to all background subagents)` heading and its three paragraphs/bullets).

  Old:
  ```markdown
  ### Final-message rule (applies to all background subagents)

  Background subagents run via the Agent tool with `run_in_background: true`. The dispatching parent session **only sees your final message as the task result**. Anything you write or output in earlier turns is invisible to the parent.

  Therefore, before invoking `/end-subagent-session`:

  - Restate your complete deliverable in your **final message** — full findings, commit SHAs, file paths, recommendations, gating questions, whatever the dispatcher needs.
  - Do not close with "report delivered above" or "see learnings file" as the final content. The parent has no "above" and will not read your learnings file.
  - Learnings files and memory updates are for *your* future sessions; the final message is for the parent.
  ```

  New:
  ```markdown
  ### Final-message rule (applies to one-shot bg subagents only)

  Background one-shot subagents run via the Agent tool with `run_in_background: true` and no `team_name`. The dispatching parent session **only sees your final message as the task result**. Anything you write or output in earlier turns is invisible to the parent.

  **This rule does NOT apply to teammates.** If you were dispatched as a teammate (Agent dispatch included `team_name` + `name`), your `<teammate-message>` blocks reach the lead during your lifetime — the lead sees your intermediate output. The final-message constraint is a bg-one-shot artifact.

  For one-shot bg subagents, before invoking `/end-subagent-session`:

  - Restate your complete deliverable in your **final message** — full findings, commit SHAs, file paths, recommendations, gating questions, whatever the dispatcher needs.
  - Do not close with "report delivered above" or "see learnings file" as the final content. The parent has no "above" and will not read your learnings file.
  - Learnings files and memory updates are for *your* future sessions; the final message is for the parent.
  ```

- **DoD:** Heading is retitled to scope the rule. New paragraph explicitly excludes teammates. The three execution bullets remain (now scoped to one-shot bg).

### T9 — Delete the carveout-plan ghost

- **kind:** delete
- **estimate_minutes:** 2
- **files:** `plans/proposed/personal/2026-04-27-team-mode-foreground-dispatch-carveout.md`
- **detail:** The file exists on disk untracked (never committed; from yesterday's reaped Karma worktree). Lux assumed it would land first; Duong's direction makes it moot — the PreToolUse hook already accepts `bg + team_name` correctly, and this rule-patch plan establishes teammate-default without requiring a foreground carveout. Delete the file via `rm`.

  Note in implementation: confirm the file is in fact untracked (`git ls-files --error-unmatch plans/proposed/personal/2026-04-27-team-mode-foreground-dispatch-carveout.md` returns non-zero) before `rm`. If it is somehow tracked, escalate to Karma rather than `git rm` — that would imply someone committed it, which changes the situation.

- **DoD:** File no longer exists at that path. `git status` no longer shows it as untracked.

### T10 — Verify the chain

- **kind:** verify
- **estimate_minutes:** 4
- **files:** (read-only)
- **detail:** After T1–T9 land:

  1. Re-read `runbooks/agent-team-mode.md` end-to-end. Confirm §Policy and §Operational hygiene exist; confirm the post-tmux-reinstall sentence in §Settings.
  2. `grep -n "Agent Team mode" agents/memory/duong.md` returns no hits.
  3. `grep -rn "background subagents are one-shot" agents/sona/CLAUDE.md` returns no hits OR returns only the explicitly-scoped "for bg fallback dispatches only" form.
  4. `grep -rn "Always run subagents in the background" agents/` returns no hits (both A1 and A2 retitled).
  5. Confirm `plans/proposed/personal/2026-04-27-team-mode-foreground-dispatch-carveout.md` does not exist.
  6. Confirm cross-references survive: `grep -rn "rule-background-subagents\|rule-sona-background-subagents" .` should still return references in the same callsites (the anchor names are unchanged).

- **DoD:** All six checks pass. Report any discrepancy back to Karma rather than self-correcting (this is the verification gate, not the edit gate).

## Test plan

This is pure prose-edit work — no code, no behavior change, no schemas, no scripts. `tests_required: false` is justified because:

- No executable code is added or modified.
- No agent dispatch behavior changes (the PreToolUse hook is untouched; teammate dispatch already works per the empirical verification on 2026-04-27).
- No data structure or contract is altered.

Verification is manual via T10's grep + read pass. Senna (reviewer) and Lucian (re-reviewer) read each diff against the assessment and against this plan's old/new excerpts.

**Manual acceptance criteria for Senna:**

1. Every operational claim from `agents/memory/duong.md` lines 84–92 (pre-deletion) is preserved in `runbooks/agent-team-mode.md` §Policy. Diff the two by hand — no bullet should be lost.
2. Both A1 and A2 anchors (`#rule-background-subagents`, `#rule-sona-background-subagents`) survive verbatim — only the rule body changes. Cross-references elsewhere in the repo continue to resolve.
3. The "background subagents are one-shot" claim now appears only in scoped form ("for bg fallback dispatches only") in A2; it does not appear unscoped anywhere.
4. B1, B3, B4 each defer to either `runbooks/agent-team-mode.md` §Policy or `#rule-background-subagents`. None retain the bg-only-default framing.
5. The carveout-plan ghost is gone from `plans/proposed/personal/`.

## Decision log

This plan is itself a decision-axis update: the canonical-rule site moved from `agents/memory/duong.md` to `runbooks/agent-team-mode.md`. Evelynn's existing decision log (`agents/evelynn/memory/decisions/log/2026-04-27-team-mode-bg-rule-amend-route.md`) covers the route choice (Karma quick-lane). No new decision-log entry is required for this plan; the plan itself records the policy-site move.

## References

- `assessments/personal/2026-04-27-team-mode-default-rule-patches.md` — Lux's full inventory and proposed wording (this plan supersedes Lux's §3.1 "make duong.md canonical" recommendation per Duong's direction reversal)
- `runbooks/agent-team-mode.md` — the runbook this plan amends
- `agents/memory/duong.md` lines 84–92 — the source of the §Policy content (pre-deletion)
- `plans/proposed/personal/2026-04-27-team-mode-foreground-dispatch-carveout.md` — the ghost being deleted by T9
- `agents/evelynn/memory/decisions/log/2026-04-27-team-mode-bg-rule-amend-route.md` — route decision (Karma quick-lane)
- `agents/evelynn/memory/decisions/log/2026-04-27-team-mode-it2-empirical-test.md` — empirical test that produced the runbook

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Re-promotion after Yuumi added `qa_plan_none_justification` (line 9). Structural checks (qa_plan frontmatter, qa_plan body, UX Spec linter) all pass. Plan has clear owner (Karma), no unresolved TBDs in gating sections, tasks T1–T10 are concrete with explicit old/new excerpts and DoDs, and the `qa_plan: none` justification (pure prose-edit, no executable code) is sound. Decisions are explicitly enumerated and resolved. T9 includes a sensible safety check (verify untracked before `rm`).
