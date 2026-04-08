---
title: Plan ↔ Google Doc Mirror — Scope Revision (Proposed-Only)
status: proposed
owner: swain
created: 2026-04-08
---

# Plan ↔ Google Doc Mirror — Scope Revision (Proposed-Only)

## Context

The original gdoc-mirror plan (`plans/implemented/2026-04-08-plan-gdoc-mirror.md`, Decision 8) specified a single Drive folder, "Strawberry Plans (transient)", holding every published plan across every lifecycle stage. That decision shipped today; katarina bulk-published ~30 plans across `proposed/`, `approved/`, `in-progress/`, and `implemented/`. Duong opened the folder and called it "very disorganized, with everything in one place."

Four alternative layouts were surfaced (proposed-only, subfolders-by-status, active/archive, proposed+in-progress). **Duong chose Option A: the mirror holds only plans currently in `plans/proposed/`.** This revision codifies that choice and lays out the scripts, migration, and lifecycle changes needed to honor it.

## New scope

**Drive mirrors only plans that currently live in `plans/proposed/`.** The mental model is: *if it's in Drive, it needs Duong's attention.* Drive is a focused review inbox, not an archive. Anything that has moved out of `proposed/` — approved, in-progress, archived, or implemented — must not exist in Drive and must not carry `gdoc_id`/`gdoc_url` frontmatter.

Git remains the sole source of truth for all non-proposed plans. The existing plan-viewer (myapps) continues to serve the browse/read path for non-proposed plans; the gdoc mirror is now exclusively the *review-and-edit* surface for in-flight proposals.

## Script changes required

1. **`scripts/plan-publish.sh` — enforce proposed-only target.**
   - Refuse to run unless the target file path matches `plans/proposed/*.md`. Exit non-zero with a clear error: `plan-publish: refusing to publish <path>; Drive mirror is proposed-only. Move the plan back to plans/proposed/ or use plan-unpublish.sh.`
   - **Recommendation: no `--force` escape hatch.** The invariant "Drive == proposed" is the whole point of this revision; an escape hatch reintroduces the failure mode we are fixing. If a future need emerges, add it then.

2. **Promote/move operation — automatic unpublish on exit from `plans/proposed/`.**
   This is the trickiest call. Options:
   - (a) Wrapper script `scripts/plan-promote.sh <file> <target-status>` that runs `plan-unpublish.sh` then `git mv`.
   - (b) A pre-commit git hook that detects `git mv` out of `plans/proposed/` and calls `plan-unpublish.sh`.
   - (c) Agent procedure — every Opus/Sonnet agent that moves a plan must manually call `plan-unpublish.sh` first.
   - **Recommendation: (a) wrapper script `scripts/plan-promote.sh`.** Reasoning:
     - Git hooks (b) run inside commit context, need network access to Drive, can block commits on API failures, and are invisible to anyone reviewing the repo. Agents forget hooks exist; hooks forget to tell agents what they did.
     - Agent procedure (c) is what we have today and is exactly why the cleanup step gets missed. Convention without enforcement decays.
     - A wrapper script is explicit, greppable, testable offline, and failure-visible. An agent calling `plan-promote.sh foo.md approved` sees unpublish errors immediately and can recover. The script is also callable manually by Duong.
   - Contract for `plan-promote.sh`:
     1. Refuse if source is not in `plans/proposed/`.
     2. Refuse if target status is not one of `approved|in-progress|implemented|archived`.
     3. Require clean working tree for the target file (same guard as existing scripts).
     4. If frontmatter has `gdoc_id`, call `plan-unpublish.sh` (which trashes the Drive doc and strips `gdoc_id`/`gdoc_url`, committing its own change).
     5. `git mv plans/proposed/<file>.md plans/<target-status>/<file>.md`.
     6. Rewrite `status:` in frontmatter to match the new directory.
     7. Commit with `chore: promote <file> to <target-status>`.
   - Document in `CLAUDE.md` and `agents/memory/agent-network.md` that agents must use `plan-promote.sh` rather than raw `git mv` for plans leaving `proposed/`.

3. **`scripts/plan-fetch.sh` — confirm still valid.**
   The existing fetch flow already targets `proposed/ → approved/` only (Decision in original plan, Idempotency section step 5). The new contract does not change this, but fetch must now invoke unpublish as part of its commit (or delegate to `plan-promote.sh` — see below). Recommended shape:
   - Option 1 (minimal): `plan-fetch.sh` continues to pull the doc body, writes it to `plans/approved/<file>.md`, deletes the proposed copy, **then calls `plan-unpublish.sh` on the now-approved file before committing.** All three operations land in one commit: `chore: approve <file> via gdoc fetch (unpublished)`.
   - Option 2 (tidier): `plan-fetch.sh` writes the updated content back to the proposed file, commits, then delegates the directory move to `plan-promote.sh <file> approved` which handles unpublish + move + commit.
   - **Recommendation: Option 2.** It keeps each script to one responsibility and ensures every exit from `proposed/` flows through the same choke point. Fetch pulls edits, promote handles the lifecycle transition including unpublish.

4. **`scripts/plan-unpublish.sh` — verify, no behavioral change expected.**
   The script as shipped already: reads `gdoc_id`, trashes the Drive doc (or no-ops on 404), strips `gdoc_id`/`gdoc_url`, commits. This is exactly what the new contract needs. Verification step in implementation: confirm it still runs cleanly against a currently-published proposed plan and against a no-op (no `gdoc_id`) case. No code changes anticipated.

## Migration plan

Execute in order. Each step is a discrete commit (or commit batch). None require code changes — only running existing scripts and committing frontmatter edits.

1. **Unpublish all plans outside `proposed/` that have `gdoc_id`.** Enumerate with:
   ```
   git grep -l '^gdoc_id:' plans/approved plans/in-progress plans/implemented
   ```
   Expected ~30 files based on katarina's bulk publish. For each file, run `scripts/plan-unpublish.sh <path>`. The script already handles the trash + frontmatter strip + commit per file. A batch wrapper (`for f in ...; do ./scripts/plan-unpublish.sh "$f"; done`) is acceptable; individual commits are preferred over one squash commit so each unpublish is independently revertible.
   - Includes the gdoc-mirror plan itself: `plans/implemented/2026-04-08-plan-gdoc-mirror.md`.

2. **Delete the two orphan Drive docs that were never linked back.** Malformed frontmatter on source files left these docs in Drive with no `gdoc_id` anywhere in git:
   - `1jZfFq1hf741g1B69CVYy6HFjo_Ly6Is3g0Gh7CR68Uo` (orphan for `2026-04-04-git-safety-shared-workdir.md`)
   - `1KHrc2XC368LBUXhLgd0q5QcP78pdqmx5cS1SKDB6dHs` (orphan for `2026-04-04-pr-documentation-rules.md`)
   Since there is no markdown to clean up, unpublish via direct Drive API call (PATCH `files/{id}` with `trashed: true`, using the same OAuth credential the scripts use). Acceptable to do this as a one-shot inline `curl` invocation by the executor; no new script warranted for two IDs.

3. **Publish all plans currently in `plans/proposed/`** so Drive reflects the new contract. Current contents (verified at plan-authoring time):
   - `plans/proposed/2026-04-03-discord-cli-integration.md`
   - `plans/proposed/2026-04-05-gh-auth-lockdown.md`
   - `plans/proposed/2026-04-05-launch-verification.md`
   - `plans/proposed/2026-04-05-plan-viewer.md`
   - `plans/proposed/2026-04-08-cafe-from-home.md`
   - Plus this revision plan itself once it is moved into `proposed/` (it starts there). The executor should re-enumerate at runtime in case `proposed/` changed between approval and execution.
   Run `scripts/plan-publish.sh <path>` for each. The publish script commits each link-back on its own; expected ~6 commits.

4. **Verify end state.**
   - `git grep -l '^gdoc_id:' plans/` returns only files under `plans/proposed/`.
   - Drive folder "Strawberry Plans (transient)" contains exactly the proposed-plan count (currently 6).
   - No orphan docs remain in the Drive folder.

**Follow-up (out of scope for this plan):** the two files `plans/implemented/2026-04-04-git-safety-shared-workdir.md` and `plans/implemented/2026-04-04-pr-documentation-rules.md` have a stray single character (`l` and `i` respectively) before the opening `---` of their frontmatter. Fix is a one-byte edit per file. Not in scope here because they are in `implemented/` and will never be republished under the new contract; the orphan Drive docs are handled above by direct API call. Note for future hygiene pass.

## Open questions for Duong

1. **Should `plan-promote.sh` auto-push after committing, or leave the push to the caller?** Recommendation: **auto-push**, matching the existing publish/fetch/unpublish scripts. Consistency across the plan-lifecycle script family is worth more than flexibility.
2. **For the migration step 1, do you want one commit per file or one batch commit?** Recommendation: **one per file**, because plan-unpublish.sh already commits per invocation and rewiring it for batch mode is unnecessary churn. ~30 small commits for a one-time migration is cheap; revertibility is free.

## Rollback plan

If the proposed-only model also fails reality contact, walking it back is cheap:

1. Revert or disable the `plans/proposed/*.md`-only guard in `plan-publish.sh` (single conditional).
2. Delete or stop using `plan-promote.sh`; go back to raw `git mv` + manual unpublish discipline.
3. Re-publish plans in whatever directories the new model wants. Since `plan-publish.sh` is idempotent (checks for existing `gdoc_id`, creates if missing, updates if present), re-publishing 30 plans is a single loop and takes minutes.
4. No Drive state is destroyed irreversibly: unpublish uses trash, not hard-delete, so anything mistakenly removed during migration can be restored from Drive's trash for 30 days.

The only lossy direction is if Duong manually empties Drive trash between migration and rollback. Document that risk and move on.
