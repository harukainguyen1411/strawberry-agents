---
title: Universal subagent worktree isolation — opt-out, not opt-in
owner: azir
status: implemented
concern: personal
complexity: normal
tests_required: true
orianna_gate_version: 2
date: 2026-04-24
created: 2026-04-24
supersedes: plans/implemented/personal/2026-04-23-subagent-worktree-and-edit-only.md
---

## Context

Three incidents in a week all root in the same failure mode: coordinator-dispatched subagents share a single working tree and race each other through git.

- **2026-04-23 parallel write race (materialized).** Ekko #33 and Ekko #32 committed to the same tree during overlapping windows. The wrong commit was reverted, then the revert had to be reverted. Audit trail degraded, two extra commits in the log. `agents/evelynn/learnings/2026-04-23-parallel-subagent-write-race-materialized.md`.
- **2026-04-23 commit entanglement.** A pre-commit hook re-staged sibling files across hook invocations, causing one agent's commit SHA to carry another agent's staged work. Commit messages lied about diffs. Rule: nominally disjoint file sets are not sufficient — the staging area is global per working tree. `agents/evelynn/learnings/2026-04-23-concurrent-agent-commit-entanglement.md`.
- **2026-04-24 Ekko entanglement (today).** Ekko crashed mid-commit on a shared tree that already held orphan work from prior Lucian/Senna sessions. Had Ekko completed, his cleanup commit would have bundled Lucian's uncommitted learning, PR #104 screenshots, and unrelated `karma.md` edits.

The predecessor plan `2026-04-23-subagent-worktree-and-edit-only.md` added `default_isolation: worktree` frontmatter to four breakdown/test-plan agents (aphelios, kayn, xayah, caitlyn) primarily as inline-edit discipline (D1A — suppress sibling `-tasks.md` / `-breakdown.md` files). Race protection was a side-effect. That plan shipped (it is in `plans/implemented/personal/`), but today's Ekko incident — which involves an agent explicitly excluded from the opt-in set — demonstrates that the scope was drawn too narrowly. Duong's directive today: **"have the worktree isolation on agents who needs it"**, i.e. universal default with explicit opt-outs for the pointless cases.

This ADR supersedes the 2026-04-23 plan. The inline-edit-discipline subgoal of that plan (Aphelios/Kayn/Xayah/Caitlyn have `Write` removed from their tools list) is preserved; only the frontmatter policy and hook behavior change.

## Decision

**Flip `scripts/hooks/agent-default-isolation.sh` from opt-in to opt-out.** Every subagent dispatch is auto-isolated into a fresh worktree unless one of the following is true:

1. The caller explicitly set `isolation` on the Agent tool call (any value, including `"none"`). Explicit caller intent always wins — the hook never overwrites.
2. The target subagent's `.claude/agents/<name>.md` frontmatter declares `default_isolation: none`.
3. The target subagent appears in a short **opt-out allowlist** baked into the hook (see §Opt-out set).
4. The caller is itself already running inside a worktree (nested-dispatch guard — see §Nested-dispatch policy).

The existing `default_isolation: worktree` frontmatter becomes redundant (the default already produces that behavior) but remains harmless and may stay on the four agent defs as documentation-of-intent (see §Migration).

### Why opt-out over opt-in

Opt-in requires that every new agent author remembers to declare isolation. Today's incident proves the roster evolves faster than the policy labels: Ekko has been in the roster for months, has always written to the tree, and was never opted in because the 2026-04-23 plan framed the problem as "breakdown agents producing sibling files" rather than "any writer racing any other writer." The class of agents-that-commit is too large and too dynamic to maintain by allowlist. Flip the sign: isolate by default, list only the handful that don't need it.

Cost of universal isolation: a worktree create (~50ms) and a branch merge-back (~fast-forward, rarely any real merge) per dispatch. Negligible compared to the cost of one more entangled-commit audit.

### Opt-out set

Agents where isolation is pointless overhead (the agent does not mutate the working tree, or its writes are intentionally on-main ephemera that would be harder to merge back than to let through):

| Agent | Role | Opt-out rationale |
|---|---|---|
| **skarner** | Memory excavator (read-only) | Never mutates the working tree — read-only by definition post-2026-04-24 retirement of write mode. Hook-level opt-out is a clean full-opt-out; no two-mode caveat. |
| **orianna** | Script-only plan promoter | Not Agent-tool invocable; runs under `scripts/plan-promote.sh` with its own identity (`Duongntd`). Listed defensively — never reached via the hook. |

Agents **kept in the default-isolated set** (explicitly re-evaluated, not grandfathered):

- **yuumi** — errand runner. Writes files, edits memory, runs inbox helpers. She writes → she races → she isolates. (Brief noted this correctly.)
- **ekko** — quick task / DevOps executor. Commits. Today's incident is exactly why.
- **lissandra** — pre-compact memory consolidator. Writes handoff notes, memory shards, journal entries, commits. Runs near-simultaneously with coordinator's final close window — race-prone.
- **akali** — Playwright QA agent. Writes screenshots and QA reports under `assessments/qa-reports/`; commits them.
- all planners (swain, azir, kayn, aphelios, xayah, caitlyn, lulu, neeko, heimerdinger, camille, lux, senna, lucian, karma) — they write plans to `plans/proposed/` and commit.
- all implementers (viktor, jayce, seraphine, soraka, rakan, vi, talon) — they typically operate on PR branches, but "on a PR branch" is itself a worktree-shaped concern; isolation is cheap and keeps behavior uniform.
- all review/advisory/agentic agents with any write path (syndra, etc.).

"**Explore**" was mentioned in the brief as a possible opt-out candidate. There is no agent named Explore in the roster (`.claude/agents/`) — the brief may have been referring to Skarner's search mode or to a generic research pattern. No action for Explore.

### Merge-back protocol

The Agent tool returns a result dict that includes `path` (worktree location) and `branch` when `isolation: "worktree"` was applied. The coordinator (Evelynn or Sona) is responsible for reconciling.

Three cases:

**(a) Subagent made no commits.** The harness auto-cleans the worktree on subagent exit (per existing behavior — no change). Coordinator does nothing. Verification: `branch` equals the pre-dispatch HEAD of main, or `path` no longer exists.

**(b) Subagent made commits on its branch.** Coordinator fast-forward-merges the subagent branch into main:
  - `git fetch origin` (in the coordinator's tree, which is the repo root)
  - `git merge --ff-only <subagent-branch>` — succeeds when main has not advanced; this is the common case because the coordinator was blocked awaiting the subagent.
  - If `--ff-only` fails because main advanced (e.g., a parallel subagent's branch already merged), the coordinator performs `git merge --no-ff <subagent-branch>` per universal invariant Rule 11 (never rebase).
  - Push main. Delete subagent branch.

**(c) Two parallel subagents' worktrees touched the same file.** First merge is ff; second merge falls through to `--no-ff` and may conflict. Policy:
  - If the conflict is in a plan file (`plans/**`): **fail loud**. Coordinator reports the conflict to Duong. Manual resolution. Parallel dispatches of two plan authors on the same slug is itself a coordination bug — this is the surface that catches it.
  - If the conflict is in memory (`agents/**/memory/**`): **prefer last-sessions shards over main memory file**. Shards are append-only per-session; the main memory file is mutated by consolidation. Two shards never conflict; main-file conflicts indicate one agent should not have been touching the main file mid-session.
  - If the conflict is in code (`apps/**`, `scripts/**`): **coordinator aborts both merges, re-dispatches one of the two on top of the merged result of the other**. Do not attempt to auto-resolve code conflicts.

This merge-back work is coordinator-owned and should be codified in a small helper script `scripts/subagent-merge-back.sh` (documented in the implementation task list, not this ADR) so Evelynn/Sona invoke a single command per returned subagent instead of hand-rolling the three cases.

### Nested-dispatch policy

Learning `agents/evelynn/learnings/2026-04-11-nested-worktree-permissions.md` established: when a session already running inside a worktree spawns a subagent with `isolation: "worktree"`, the doubly-nested worktree path (`~/.../worktree-A/.claude/worktrees/worktree-B/`) is blocked by the harness's Write/Bash permission model. The fix has been "start coordinators from repo root, only."

Under universal opt-out, subagents-dispatching-subagents (Aphelios spawning a research dispatch, Xayah spawning a reviewer, etc.) would all default-isolate, which triggers the nested-worktree problem for everyone, not just the careless cases.

The hook must therefore skip injection when the **parent** is already in a worktree. Detection: `git rev-parse --show-toplevel` of the hook's cwd compared against the non-worktree canonical repo root (the path in `$REPO_ROOT` today resolves to whatever the calling session sees; when called from a worktree, `git rev-parse --git-common-dir` returns the main repo's `.git`, while `--git-dir` returns the worktree's). Concretely:

```
if git rev-parse --git-dir differs from git rev-parse --git-common-dir:
    # we're in a worktree; do not inject isolation for children
    skip injection, exit 0
```

This preserves the "coordinators start from repo root" invariant without requiring agents to remember it.

### Migration impact

- **Frontmatter:** `default_isolation: worktree` on aphelios/kayn/xayah/caitlyn is now redundant with the default. **Leave it in place** as documentation-of-intent — removing it produces churn with no behavior change, and if a future change re-scopes the default (e.g. a narrower setting per repo), the explicit frontmatter is the right source of truth. Document in the hook that explicit `default_isolation: worktree` is a no-op under the opt-out regime.
- **Hook:** `scripts/hooks/agent-default-isolation.sh` is rewritten — the core Python script flips from "inject only if frontmatter says worktree" to "inject unless opt-out applies." Opt-out allowlist is a constant inside the Python block; parent-worktree detection happens in the bash wrapper before invoking Python.
- **Settings:** no change in `.claude/settings.json` — the PreToolUse Agent matcher still points at the same hook file.
- **Inline-edit discipline preserved:** aphelios/kayn/xayah/caitlyn keep `Write` absent from their `tools:` block (D1A subgoal of the 2026-04-23 plan). That lever is orthogonal to isolation.
- **Break risk:** the only behavioral surface changed for previously-non-isolated agents is that they now return via a worktree branch that the coordinator must merge back. Coordinators without the merge-back helper will see "subagent completed but main has not advanced" until they pull in the branch. **Migration sequence:** ship the merge-back helper (script + coordinator CLAUDE.md instruction) *before* flipping the default, so coordinators are not surprised.

## Test plan

Invariants (xfail-first per Rule 12; tests committed BEFORE the hook flip):

**INV-1 — Default isolation applies to any non-opt-out subagent.** Feed fake Agent tool_input JSON for `ekko`, `yuumi`, `lissandra`, `akali`, and three planners through the hook. Assert `isolation` is mutated to `"worktree"` in each case. This is the scenario the 2026-04-23 regime did not cover for ekko/yuumi/lissandra/akali.

**INV-2 — Opt-out agents pass through untouched.** Feed fake tool_input for `skarner` (no explicit isolation). Assert the hook emits no mutation (exit 0, empty stdout). Skarner's read-only search mode is unchanged by isolation, so the default skips her to avoid pointless worktree churn.

**INV-3 — Explicit caller isolation is never overridden.** Feed tool_input with `isolation: "none"` for a default-isolated subagent (e.g. `yuumi`). Assert no mutation — caller intent wins.

**INV-4 — Parent-worktree nested-dispatch guard.** Simulate the hook running inside a worktree by setting the environment such that `git rev-parse --git-dir` != `--git-common-dir`. Feed tool_input for `aphelios`. Assert no mutation — the parent is in a worktree; children must not re-isolate.

**INV-5 — `default_isolation: none` frontmatter is honored.** Create a fixture agent def with `default_isolation: none` in a temp agents dir. Feed tool_input for it. Assert no mutation. (Exercises the frontmatter opt-out path in addition to the hardcoded allowlist.)

**INV-6 — Parallel independent worktrees do not race.** Integration-style test: dispatch two writer subagents in parallel (mocked), assert each gets a distinct worktree path and distinct branch name, assert both commits land on main after serial ff-merge-back.

**INV-7 — Skarner spawn produces no worktree.** Behavioral test (can be a mocked dispatch in CI): verify the tool_input received by the Agent dispatch layer when Skarner is spawned contains no `isolation` key, i.e. the hook did not mutate.

**INV-8 — Yuumi spawn produces a worktree.** Behavioral test mirror of INV-7, asserting `isolation: "worktree"` was injected by the hook.

Regression coverage for the 2026-04-23 invariants:
- INV-2-old (Write absent from aphelios/kayn/xayah/caitlyn): **preserved** — inherited from the superseded plan's tests. Do not delete those test files.
- INV-1-old (frontmatter-opt-in injection): **superseded by INV-1 above** — the new test is strictly broader. The old test can stay (harmless) or be folded into INV-1; that's a task-breakdown-level call.

Test files (new):
- `scripts/hooks/tests/test-agent-default-isolation-universal.sh` (INV-1, INV-2, INV-3, INV-5, INV-7, INV-8)
- `scripts/hooks/tests/test-nested-dispatch-guard.sh` (INV-4)
- `scripts/hooks/tests/test-parallel-worktree-merge-back.sh` (INV-6) — may require a mock harness; acceptable as a deferred INV if the breakdown agent determines it needs a harness that doesn't exist yet.

## Open questions

All four OQs resolved 2026-04-24 by Duong (ADR ready for Orianna promotion):

1. **OQ1 — Skarner-write mode.** **RESOLVED: retire Skarner-write entirely.** Duong confirmed the write mode was a legacy want ("I used to want Skarner to write memories for subagents when they're done with their task, but that's dumb"). Skarner is pure read-only. `.claude/agents/skarner.md` updated 2026-04-24 to remove the Write/Edit tools and the "Mode: Write" section. Skarner is now cleanly in the opt-out allowlist with no two-mode caveat.

2. **OQ2 — Merge-back mechanism.** **RESOLVED: explicit helper script, start here.** Ship `scripts/subagent-merge-back.sh`. Evelynn/Sona invoke it manually per returned subagent. Observability-first — a new mechanism across the full roster deserves explicit surface before we collapse it to auto-hook. If coordinators invoke the helper identically every time for a week with no branching, revisit and automate via PostToolUse hook. Not before.

3. **OQ3 — `run_in_background` composition.** **RESOLVED: no action.** Coordinator rules already mandate `run_in_background: true` on every Agent call. Universal worktree isolation composes cleanly; flagging only.

4. **OQ4 — Migration ordering.** **RESOLVED: single PR, three commits in sequence.** (i) merge-back helper + coordinator doc updates, (ii) xfail tests citing this plan's INV-1 through INV-8, (iii) hook flip from opt-in to opt-out. Rule 12 forces xfail-commit and impl-commit on the same branch; splitting into stacked PRs adds ceremony without meaningful review isolation. Breakdown agent confirms three-commit representability as part of task sequencing.

## References

- Superseded: `plans/implemented/personal/2026-04-23-subagent-worktree-and-edit-only.md`
- `agents/evelynn/learnings/2026-04-23-parallel-subagent-write-race-materialized.md`
- `agents/evelynn/learnings/2026-04-23-concurrent-agent-commit-entanglement.md`
- `agents/evelynn/learnings/2026-04-11-nested-worktree-permissions.md`
- `scripts/hooks/agent-default-isolation.sh` — the hook being flipped
- `.claude/settings.json` — PreToolUse Agent matcher (no wiring change)
- Universal invariants: Rule 10 (POSIX bash), Rule 11 (never rebase — merge-back uses `--no-ff`), Rule 12 (xfail-first)

## Handoff

Per architect closeout: this ADR stops at design. Task breakdown is Kayn's (normal-lane breakdown) once Orianna promotes proposed → approved. Do not assign an implementer in the breakdown — that is Evelynn's call after approval.

## Tasks

Normal-lane breakdown. Single PR, three commits in OQ4-mandated order: (C1) merge-back helper + coordinator docs, (C2) xfail tests covering INV-1..INV-8, (C3) hook flip opt-in → opt-out. Rule 12 forces xfail tests (C2) to commit BEFORE the impl flip (C3) on the same branch.

**Legend:** kind = `script` | `test` | `doc-edit`. `[TOP-LEVEL]` marks tasks touching `.claude/agents/*.md` (top-level-coordinator write surface — implementer must flag back to Evelynn before commit; PreToolUse plan-lifecycle guard does not block these, but they are Evelynn's surface by convention).

### Commit 1 — Merge-back helper + coordinator docs

- [ ] **T1** — Author `scripts/subagent-merge-back.sh`. kind: script. estimate_minutes: 45. Files: `scripts/subagent-merge-back.sh` (new). DoD: POSIX-portable bash (Rule 10), executable bit set, takes `<subagent-branch>` arg (and optional `--worktree-path`), implements the three ADR cases: (a) no-commits → noop + log, (b) commits + main-not-advanced → `git merge --ff-only`, (c) main advanced → `git merge --no-ff` (Rule 11 — never rebase). Conflict policy per ADR §Merge-back: plans/** → fail loud, memory/** → prefer last-sessions shards, code → abort both merges and exit non-zero with guidance. Prints subagent branch + resulting main SHA. Script includes `-h/--help`. Runs `git fetch origin` first. Deletes subagent branch after successful merge. No worktree prune (harness handles).
- [ ] **T2** — Smoke-test the helper locally. kind: script. estimate_minutes: 15. Files: none (throwaway). DoD: create a throwaway branch with one commit, run `scripts/subagent-merge-back.sh <branch>`, confirm ff-merge + branch deletion + clean exit. Not committed; evidence in PR description.
- [ ] **T3** — Document merge-back in Evelynn's CLAUDE.md. kind: doc-edit. estimate_minutes: 20. Files: `agents/evelynn/CLAUDE.md`. DoD: append a "Subagent merge-back" subsection referencing `scripts/subagent-merge-back.sh`, the three cases, and the invocation pattern (one call per returned subagent that reported a `branch`). Cross-link the ADR slug.
- [ ] **T4** — Document merge-back in Sona's CLAUDE.md. kind: doc-edit. estimate_minutes: 15. Files: `agents/sona/CLAUDE.md`. DoD: same substance as T3, adapted to Sona's work-concern tone. Cross-link the ADR slug.
- [ ] **T5** — Commit C1. kind: script. estimate_minutes: 5. Files: (all of the above). DoD: single commit `chore: subagent merge-back helper + coordinator docs (ADR 2026-04-24-universal-worktree-isolation)`. Do not touch the hook or test files yet.

T1–T4 can be parallelized (four disjoint files). T5 is the serialization point.

### Commit 2 — xfail tests (must land BEFORE C3)

- [ ] **T6** — Write `scripts/hooks/tests/test-agent-default-isolation-universal.sh`. kind: test. estimate_minutes: 50. Files: `scripts/hooks/tests/test-agent-default-isolation-universal.sh` (new). DoD: POSIX bash test harness matching shape of existing tests under `scripts/hooks/tests/`. Covers INV-1 (feed tool_input JSON for ekko, yuumi, lissandra, akali, and 3 planners through the hook; assert `isolation: "worktree"` injected for each), INV-2 (skarner → no mutation), INV-3 (yuumi + explicit `isolation: "none"` → no mutation), INV-5 (fixture agent def with `default_isolation: none` in temp REPO_ROOT → no mutation), INV-7 (skarner behavioral mirror of INV-2), INV-8 (yuumi behavioral mirror of INV-1). Each assertion must reference this ADR slug in a comment. **Tests must FAIL against the current opt-in hook** (that is the xfail guarantee — Rule 12). Include a top-of-file comment stating "xfail against current opt-in hook; passes after C3 flip."
- [ ] **T7** — Write `scripts/hooks/tests/test-nested-dispatch-guard.sh`. kind: test. estimate_minutes: 30. Files: `scripts/hooks/tests/test-nested-dispatch-guard.sh` (new). DoD: simulates running inside a worktree by setting up a temp git repo with an actual `git worktree add` and invoking the hook with cwd inside the worktree. Covers INV-4: feed tool_input for `aphelios`; assert no mutation (exit 0, empty stdout). Use `git rev-parse --git-dir` vs `--git-common-dir` divergence as the detection signal (matches ADR §Nested-dispatch detection). xfail against current hook.
- [ ] **T8** — Write `scripts/hooks/tests/test-parallel-worktree-merge-back.sh`. kind: test. estimate_minutes: 40. Files: `scripts/hooks/tests/test-parallel-worktree-merge-back.sh` (new). DoD: integration-style test for INV-6. Mock two writer subagent dispatches producing two distinct worktree paths + branches; run `scripts/subagent-merge-back.sh` serially against each; assert both commits end up on main after one ff + one `--no-ff`. If a full harness mock is out of scope, the test may assert the helper's behavior against two pre-created throwaway branches instead (ADR explicitly allows deferred INV-6 harness — document the deferral in the test file header). xfail against current state (helper exists post-C1 but the parallel-branch scenario exercises the --no-ff path which is new).
- [ ] **T9** — Run all three tests locally, confirm they FAIL (xfail) against current hook. kind: test. estimate_minutes: 10. Files: none. DoD: capture failure output in PR description; this is the evidence that Rule 12 / TDD gate is satisfied.
- [ ] **T10** — Commit C2. kind: test. estimate_minutes: 5. Files: (T6, T7, T8 outputs). DoD: single commit `test: xfail coverage for universal worktree isolation (INV-1..INV-8)`. Body references ADR slug. Pre-push TDD gate should be satisfied by this commit sitting on the branch before C3.

T6, T7, T8 can be written in parallel (three disjoint test files). T9 is a serialization gate before T10.

### Commit 3 — Hook flip (gated behind C2 landing on branch)

- [ ] **T11** — Rewrite `scripts/hooks/agent-default-isolation.sh` bash wrapper to add parent-worktree detection. kind: script. estimate_minutes: 20. Files: `scripts/hooks/agent-default-isolation.sh`. DoD: before invoking Python, compare `git rev-parse --git-dir` vs `git rev-parse --git-common-dir`; if they differ, exit 0 immediately (nested-dispatch guard — INV-4). Preserve `set -eu`, `REPO_ROOT` export, and the mktemp/trap idioms.
- [ ] **T12** — Rewrite the Python block in `scripts/hooks/agent-default-isolation.sh` from opt-in to opt-out. kind: script. estimate_minutes: 30. Files: `scripts/hooks/agent-default-isolation.sh` (same file as T11 — serialize). DoD: (a) define `OPT_OUT = {"skarner", "orianna"}` as a module-level constant with a comment citing ADR §Opt-out set; (b) after the existing caller-isolation-wins check, consult the frontmatter: if `default_isolation: none` → exit 0 (INV-5); if `default_isolation: worktree` → inject (preserves legacy-frontmatter semantics, now a no-op documentation hint per ADR §Migration); (c) if subagent in `OPT_OUT` → exit 0 (INV-2/INV-7); (d) otherwise inject `isolation: "worktree"` (INV-1/INV-8). Update the top-of-file comment block to cite this ADR instead of 2026-04-23. Unsupported `default_isolation` values still warn to stderr per existing behavior.
- [ ] **T13** — Run all three new tests + any pre-existing hook tests; confirm they PASS. kind: test. estimate_minutes: 10. Files: none. DoD: green output; capture in PR description.
- [ ] **T14** — Commit C3. kind: script. estimate_minutes: 5. Files: `scripts/hooks/agent-default-isolation.sh`. DoD: single commit `chore: flip agent-default-isolation hook from opt-in to opt-out`. Body references ADR slug + INV-1..INV-8.

T11 and T12 touch the same file — serialize (do T11 first, then T12, or combine in one editing pass). T13 gates T14.

### Out-of-scope (flag-back items)

- [ ] **T15 [TOP-LEVEL]** — (Optional, defer unless Evelynn asks.) Remove now-redundant `default_isolation: worktree` frontmatter from aphelios/kayn/xayah/caitlyn. kind: doc-edit. estimate_minutes: 10. Files: `.claude/agents/aphelios.md`, `.claude/agents/kayn.md`, `.claude/agents/xayah.md`, `.claude/agents/caitlyn.md`. DoD: **do not execute in this PR** per ADR §Migration ("leave it in place as documentation-of-intent"). Listed here only to mark the top-level write surface for future reference; implementer should NOT touch these files.

### Parallelization summary

- Parallel within C1: T1, T3, T4 (three disjoint files); T2 after T1.
- Parallel within C2: T6, T7, T8 (three disjoint test files); T9 after all three.
- C3 fully serial: T11 → T12 (same file) → T13 → T14.
- Commit order is strictly C1 → C2 → C3 (OQ4 + Rule 12).

### AI-minute total

T1–T14 sum to ~300 minutes (5 hours) of Sonnet-medium execution time. No gating questions — ADR resolved all four OQs; the breakdown sits cleanly within the implementer's scope.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Azir-authored ADR with clear owner, concrete decision (opt-out over opt-in) grounded in three dated incidents, and an explicit opt-out set with per-agent rationale. All four open questions are resolved with named decisions and artifacts (Skarner-write retirement already landed in commit 103dd3e, merge-back helper scoped, migration ordering committed to a single 3-commit PR). Eight invariants are declared with concrete test-file paths honoring tests_required, and the supersedes relationship preserves the prior plan's inline-edit-discipline subgoal. Nothing gating on proposed→approved is outstanding.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** approved → implemented
- **Rationale:** PR #37 merged to main with the OQ4-mandated three-commit sequence intact on main: C1 ff2d3e0d (merge-back helper + Evelynn/Sona doc updates), C2 ad63e39d (xfail tests covering INV-1..INV-8, Rule 12 satisfied), C3 e2097372 (hook flip opt-in → opt-out). Jayce reported xfail-red at C2 and green at C3 (11/11 universal, 4/4 nested-dispatch, 6/6 parallel merge-back, 6/6 legacy regression). Both Lucian and Senna APPROVEd the PR; Senna's four suggestions are non-blocking polish tracked as follow-up. Direct approved→implemented transition is appropriate here — the in-progress stage was logically held by Kayn's in-plan breakdown and the PR #37 branch, and a two-hop promotion would produce bookkeeping churn with no artifact change.
