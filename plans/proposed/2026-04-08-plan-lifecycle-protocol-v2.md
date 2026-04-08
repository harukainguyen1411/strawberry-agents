---
status: proposed
owner: syndra
created: 2026-04-08
title: Plan Lifecycle Protocol v2 — Two-Phase Planning, Canonical Frontmatter, draft-plan/detailed-plan Skills
gdoc_id: 1cYrwq7uvuVIHA89mzWYKvI_20CqPa_wZZ4wFpF7aJC4
gdoc_url: https://docs.google.com/document/d/1cYrwq7uvuVIHA89mzWYKvI_20CqPa_wZZ4wFpF7aJC4/edit
---

# Plan Lifecycle Protocol v2

> Rough plan. Alignment-level only. Meta-note: this is the first rough plan written under a protocol that does not yet exist. The detailed execution spec for this plan will happen after Duong approves, under the new protocol, by whichever Opus Evelynn assigns.
>
> No component self-implements. No implementer assigned.

---

## Problem

The current plan lifecycle conflates two very different things into one artifact: **"is this the right direction?"** (alignment) and **"exactly how do we execute it?"** (spec). Opus agents today write a single plan file in `plans/proposed/` that tries to do both, and the quality bar drifts:

1. **Rough plans that are too thick.** Opus agents over-invest in a plan Duong may not even approve, burning Opus tokens on file-level detail before alignment.
2. **Approved plans that are too thin.** When a plan lands in `approved/` light on detail, the Sonnet executor has to make design judgment calls it was never meant to make. This violates Rule 6 (Sonnet never executes without a plan) in spirit — the plan technically exists, but it does not answer the questions execution needs answered.
3. **No explicit "ready for pickup" signal.** `approved/` today means both "Duong liked the direction" and "a Sonnet can grab this right now." Two Sonnets could conceivably pick up the same plan. There is no visible "claimed" state until it lands in `in-progress/`.
4. **Frontmatter drift.** Every plan author invents slightly different frontmatter. Last session's orphan-Drive-doc incidents traced back to malformed/missing fields that no linter catches. With ~46 plan files across the lifecycle, the schema has quietly forked per-author.

The fix is to split planning into two explicit phases with two distinct skills, add a `ready/` folder between them, and pin the frontmatter schema with a linter.

---

## Proposed approach

### The new lifecycle

```
Opus drafts rough          Duong approves            Opus (same or reassigned)         Sonnet picks up             Sonnet finishes
     |                           |                   writes detailed spec                    |                           |
     v                           v                           v                              v                           v
plans/proposed/  --->  plans/approved/  --->  (in place, expanded)  --->  plans/ready/  --->  plans/in-progress/  --->  plans/implemented/
   [draft-plan skill]         [manual mv]          [detailed-plan skill]        [plan-promote.sh approved ready]    [plan-promote.sh ready in-progress]   [plan-promote.sh in-progress implemented]
```

Key distinctions:

- **`proposed/`** — rough plan, direction only. Duong is reviewing alignment, not execution.
- **`approved/`** — Duong has said "yes to direction." The plan is still rough. The Opus owner (default same author, reassignable by Evelynn) expands it in place.
- **`ready/`** — NEW. Detailed, Sonnet-ready execution spec. Waiting for a Sonnet to claim it. Not human-review territory — no Drive mirror.
- **`in-progress/`** — Sonnet has claimed and started. The move from `ready/` to `in-progress/` is the claim signal and prevents two Sonnets grabbing the same plan.
- **`implemented/`** — done. Same semantics as today.
- **`archived/`** — abandoned or superseded. Same as today.

### The two skills

**`draft-plan` skill** — invoked by any Opus when starting a rough plan.

Codifies what "rough" means so every Opus writes rough plans the same way:

- Required sections: Problem, Context, Proposed approach (shape only, not steps), Open questions for Duong, Rollback / failure-mode sketch.
- Forbidden in rough: exact file diffs, exact shell commands, step-by-step scripts, line-level instructions, verification gates. Those belong to the detailed phase.
- Canonical frontmatter schema (see below).
- File naming: `YYYY-MM-DD-<slug>.md`.
- Write target: `plans/proposed/`.
- Hard stop at proposed. Rule 7 (no self-implementation) reiterated.
- Owner is the rough-plan author. `detailed_owner` left null/omitted.

**`detailed-plan` skill** — invoked by an Opus after Duong approves a rough plan.

Codifies the expansion phase:

- First action: read the rough plan in full, plus any referenced context (learnings, prior plans, related architecture docs).
- Expand in place — the file stays at its current path (`approved/<name>.md`) during drafting, then moves to `ready/` on completion.
- Detail bar: a Sonnet executor must be able to read the plan and execute without making a single design judgment. Exact files, exact edits (or close-enough anchors), exact commands, verification commands for each step, rollback procedure, pre-flight checks.
- Fill `detailed_owner` if the author differs from `owner`. Fill `readied` date.
- Final action: `scripts/plan-promote.sh <file> ready` — the script moves the file from `approved/` to `ready/` and rewrites `status:` (see plan-promote.sh changes below).
- Hard stop at `ready/`. No self-implementation.

Both skills live in the Claude Code skills directory and are preloaded on Opus agents (Evelynn, Syndra, Swain, Pyke, Bard) via the `skills:` frontmatter convention introduced by the skills-integration plan. Sonnet agents do not get these skills — they do not draft plans.

### Canonical frontmatter schema

Every plan file, at every lifecycle stage, carries this exact shape:

```yaml
---
title: <human-readable plan title>
status: proposed | approved | ready | in-progress | implemented | archived
owner: <agent-name>              # rough-plan author. Never changes after creation.
detailed_owner: <agent-name>     # Opus who wrote the detailed phase. null/omitted until detailed phase.
created: YYYY-MM-DD              # rough-plan creation date
approved: YYYY-MM-DD             # set when Duong moves to approved/. null until then.
readied: YYYY-MM-DD               # set when plan-promote ready. null until then.
implemented: YYYY-MM-DD           # set when plan-promote implemented. null until then.
gdoc_id: <id>                     # optional, managed by plan-publish/unpublish. proposed/ only.
gdoc_url: <url>                   # optional, managed by plan-publish/unpublish. proposed/ only.
---
```

Rationale:

- **`owner` never changes** — authorship of the original direction is a stable fact. Git blame confirms.
- **`detailed_owner` is separate** — Evelynn's reassignment option (Syndra drafts AI-strategy rough, Swain picks up detailed architecture) is a first-class thing the schema tracks, not a git-log archaeology exercise.
- **Four date fields for the four lifecycle transitions** — not required for ordering (the directory is the source of truth), but they make retrospective analysis trivial ("how long did this plan sit in approved/ before detailed?").
- **Status is the directory name** — redundant with path, but the frontmatter carries it for tooling that reads the file directly (Drive mirror, the viewer), and `plan-promote.sh` already rewrites it on move.
- **Drive fields stay as-is** — managed only in `proposed/`, stripped on promote. No change from today.

### Frontmatter validator (sketch)

A linter at `scripts/plan-lint.sh` (to be built in the detailed phase, not now) that, given a plan file path, does:

1. Parse the YAML frontmatter.
2. Enforce required fields: `title`, `status`, `owner`, `created`.
3. Enforce conditional fields: `detailed_owner` must be set if file is in `ready/` or later; `approved` must be set if file is in `approved/` or later; `readied` if in `ready/` or later; `implemented` if in `implemented/`.
4. Enforce `status` matches the directory.
5. Enforce `owner` is a known agent name.
6. Wire into the pre-commit hook so no plan file lands on main with malformed frontmatter. Opt-in warning mode during migration, hard-fail after.

Just a sketch — the detailed phase picks the YAML parser (likely `yq` since it is already available), picks the hook integration style, decides the agent-name source-of-truth file.

---

## Rough shape / components

1. **New `plans/ready/` directory.** Created with a `.gitkeep`.
2. **`draft-plan` skill file.** Claude Code skill format. Location per skills-integration plan (`.claude/skills/draft-plan/` or wherever that plan settled on).
3. **`detailed-plan` skill file.** Same location family.
4. **`scripts/plan-promote.sh` updates.** Add `ready` as a valid target status. Transition table:
   - `proposed -> approved` — manual (Duong moves the file), not via plan-promote. Unchanged.
   - `approved -> ready` — via plan-promote. New.
   - `ready -> in-progress` — via plan-promote. New.
   - `in-progress -> implemented` — via plan-promote. Existing.
   - any -> `archived` — via plan-promote. Existing.
   Enforcement of *who* can do which transition (e.g., "only Sonnet can do ready -> in-progress") is **not recommended** — it would require the script to know the caller's agent identity, which it currently does not, and the rule can be enforced by profile/skill instructions instead. Keep the script dumb, keep the discipline in the agent layer.
5. **`scripts/plan-lint.sh` (sketch only in this plan).** Frontmatter validator. Detailed phase decides implementation.
6. **Migration script (sketch only).** One-shot, per-file commit, walks `plans/{proposed,approved,in-progress,implemented,archived}/*.md`, diffs existing frontmatter against canonical schema, backfills missing fields with best-effort defaults:
   - `created` — from `git log --diff-filter=A --follow --format=%as -- <file> | tail -1`.
   - `approved`, `readied`, `implemented` — from the git log entry that moved the file between directories, if resolvable; else null.
   - `title` — from the first `# <heading>` in the file body if missing.
   - `owner` — best-effort from git log first-committer-to-agent-name mapping; unresolved cases get flagged for manual fix.
   Approximately 46 plan files today. Detailed phase decides the commit cadence (one commit per file vs one batch commit) and whether to run the linter in warn-only mode during the transition window.
7. **CLAUDE.md updates.** Rule 6 (Sonnet-needs-plan) unchanged in intent but reworded: "Every delegated Sonnet task must reference a plan in `plans/ready/` or `plans/in-progress/`." Rule 7 (Opus-no-self-execute) unchanged in intent but explicit about the two phases: "Opus writes rough plans to `plans/proposed/` and detailed plans to `plans/ready/`. Never self-implements either phase." Rule 12 (plan-promote) add `ready` to the valid-target list. Possibly a new rule for frontmatter compliance once the linter goes hard-fail.
8. **`agents/memory/agent-network.md` updates.** Step 9 (plan approval gate) reworded for the two-phase model: after a rough plan lands in `proposed/`, the task is done; after a detailed plan lands in `ready/`, the task is done. Step 10 (plan-promote) adds `ready` to the valid-target list and documents the transition table.
9. **Skills preload updates.** Opus agents (Evelynn, Syndra, Swain, Pyke, Bard) get `draft-plan` and `detailed-plan` added to their `skills:` frontmatter per the skills-integration plan's per-agent preload convention.
10. **Backwards compatibility cutoff.** Plans currently in `approved/` (9 files at time of writing) get a one-time retroactive decision: the detailed phase is OPTIONAL for them. They can either (a) run through the new detailed phase before going to `ready/`, or (b) skip straight from `approved/` to `in-progress/` under the old one-phase semantics. Recommendation: **option (b) for everything currently in `approved/` as of the migration date**, to avoid a cleanup-before-cleanup death spiral. Plans proposed AFTER this plan ships go through the new two-phase lifecycle strictly. Plans currently in `in-progress/` or later are untouched — they ship under whatever rules they started under.

### Migration of existing plans

~46 plan files across the lifecycle (6 proposed, 9 approved, 2 in-progress, ~28 implemented, ~1 archived by rough count). All need a schema backfill pass, because none of them were written against the canonical schema.

Approach:

1. Dry-run the migration script. Dump a per-file diff: what's present, what's missing, what would be backfilled, what can't be resolved.
2. Duong reviews the dry-run output.
3. Run for real. One commit per file (or one commit per directory — detailed phase picks) with `chore: backfill frontmatter for <file>`.
4. Enable the linter in warn-only mode.
5. After a grace period (say one week or "next time Duong notices"), flip the linter to hard-fail.

No plan file is rewritten content-wise — only frontmatter. Body is untouched.

---

## Open questions for Duong

1. **Skill file location.** The skills-integration plan (approved, `plans/approved/2026-04-08-skills-integration.md`) is the source of truth for where skills live. **Recommended default:** whichever directory that plan settled on, referenced not re-decided here. Detailed phase reads that plan and inherits.

2. **Does `ready/` get a Drive mirror?** Duong's direction said no — `ready/` is Sonnet-consumption, not human review. **Recommended default:** no mirror, matching Duong's call. Confirmed unless you want review visibility in the Docs app for the detailed spec too.

3. **Migration cutoff for currently-approved plans.** Do the 9 plans currently in `approved/` get a retroactive detailed phase, or do they skip to `in-progress/` under the old model? **Recommended default:** skip — option (b) above. Retrofitting is a time-sink with no clear payoff, and the current approved plans were written by Opus agents who knew they were going to Sonnet — they are already thicker than a v2 rough plan would be.

4. **Who enforces the "Opus reassignment" call for detailed phase?** Default is same author. Evelynn reassigns explicitly when cross-domain. **Recommended default:** bake into the `detailed-plan` skill: "If you believe this detailed phase needs a different Opus than the rough-plan owner, escalate to Evelynn before starting. Evelynn's call is final." Evelynn then writes the reassignment into `detailed_owner` in the frontmatter before handing off.

5. **Should `plan-promote.sh` enforce caller identity for `ready -> in-progress`?** Direction said to think about whether this is over-engineering. **Recommended default: over-engineering, skip.** The script cannot cleanly know which agent is calling it (it runs as a shell process, not a harness tool), and the discipline is already encoded in Sonnet profiles + Rule 6. Script stays dumb; rule layer enforces. If the discipline breaks in practice, revisit.

6. **Frontmatter linter: where does the agent-name authority list live?** Options: `agents/roster.md`, a dedicated `agents/known-agents.txt`, or the directory listing of `agents/`. **Recommended default:** parse `agents/roster.md` — it is already the authoritative roster and the linter can grep agent names out of the table. No new file to maintain.

7. **Skill naming.** `draft-plan` vs `rough-plan` vs `plan-rough`. `detailed-plan` vs `exec-plan` vs `plan-detailed`. **Recommended default:** `draft-plan` and `detailed-plan` — those are the names Duong used in the task description, and they are the clearest phase labels.

8. **Do rough plans themselves get to commit to main, or do they need their own gate?** Today rough plans commit directly to main (Rule 9). Under v2 the same commit-direct-to-main rule should hold for both phases — neither rough nor detailed plans go through a PR. Detailed phase expansion is committed in place in `approved/`, then promoted to `ready/` with another commit. **Recommended default:** keep Rule 9 as-is, both phases commit direct to main.

---

## Rollback / failure-mode sketch

Rollback is cheap because this is mostly additive:

- **If the `ready/` folder causes confusion** — delete the folder, remove `ready` from `plan-promote.sh`, revert the skill files. Any plans in `ready/` move back to `approved/`. CLAUDE.md and agent-network.md rules revert. One-commit rollback.
- **If the frontmatter linter is too strict** — flip back to warn-only mode. Plans with bad frontmatter still commit, just with a warning. Linter itself stays installed.
- **If the migration backfill writes bad values** — every backfill commit is per-file, so `git revert <hash>` is surgical. Dry-run gate in the detailed phase catches most of this before it lands.
- **If skills don't load reliably on Opus agents** — the skills-integration plan's reversibility flags apply. Agents fall back to writing plans from memory of the convention (which is what happens today anyway).

Worst failure mode: the discipline does not hold and Opus agents keep writing one-phase plans that conflate rough and detailed. The structural fix cannot force behavior; that is a profile/CLAUDE.md-rule problem, not a folder-structure problem. Mitigation: the `draft-plan` skill actively blocks file-level detail by refusing to include those sections in its output, and the `detailed-plan` skill actively requires them. The skills are the enforcement surface, not the folders.

---

## Out of scope

- Detailed rewrites of individual existing plans. Migration is frontmatter-only.
- Any change to the Drive mirror publish/unpublish flow beyond "ready/ is not mirrored."
- Any change to the commit prefix rules, the PR rules, or the worktree rules.
- Any change to how Sonnet agents are delegated to — Evelynn still picks, still assigns, still tracks via `delegate_task`.
- Implementation of the linter, the migration script, or the skill files. This rough plan names them; the detailed phase specs them.
