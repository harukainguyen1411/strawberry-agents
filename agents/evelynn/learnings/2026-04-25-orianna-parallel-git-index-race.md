# Orianna parallel-dispatch git-index race

**Date:** 2026-04-25
**Session:** db2e8cdf
**Severity:** high (data-loss observed)
**Mitigation discovered:** explicit-pathspec on `git commit`
**Long-term fix tracking:** task #150

## What happened

Dispatched 6 Orianna instances in parallel to promote 6 sibling ADRs from `proposed/` → `approved/`. Plans were:
- plan-of-plans-and-parking-lot
- assessments-folder-structure
- structured-qa-pipeline
- pr-reviewer-tooling-guidelines
- frontend-uiux-in-process
- unified-process-synthesis

Each Orianna ran independently in the main repo workdir (no per-instance worktree — Orianna is `default_isolation: false` per her script-only agent shape). They concurrently:
1. `git mv proposed/<plan> approved/<plan>`
2. `git add` the moved file + status flip
3. `git commit -m "$HEREDOC"` with their per-plan rationale + approval block
4. `git push`

## What broke

Two distinct corruption modes:

**Mode 1 — commit-message body cross-pollination.** The plan-of-plans Orianna's commit (`8f60395a`) carried the file diff for plan-of-plans (correct) but the commit subject + body referenced assessments-folder-structure + Lux. Two follow-on commits (`bd1a34fa`, `2fcb5813`) showed the same pattern. Strong signal: heredoc content interleaving via shared `.git/COMMIT_EDITMSG` or `git commit -m` race.

**Mode 2 — file deletion inside sibling commit.** Commit `2fcb5813` (frontend-uiux's "rename fix" commit by a different Orianna instance) wholesale **deleted** `plans/approved/personal/2026-04-25-assessments-folder-structure.md` while completing an unrelated rename. Assessments Orianna recovered via `85bf198b` but only because she explicitly checked her file's presence post-commit and re-added it. This is **data loss inside another agent's commit**.

## Mitigation discovered (used same-session)

The frontend-UX Orianna recovered its own commit (`f1f6a904`) using **explicit-pathspec on commit**:

```bash
git add plans/approved/personal/2026-04-25-frontend-uiux-in-process.md
git commit -- plans/approved/personal/2026-04-25-frontend-uiux-in-process.md
```

The `-- <pathspec>` argument on `git commit` scopes the commit to ONLY the listed paths, ignoring whatever else is concurrently staged by sibling instances. This proved load-bearing for the rest of the session — both the project-context Orianna promotion (`7f09ba31`, single-instance) and all subsequent Yuumi commits used this pattern with zero further race incidents.

## Generalized rule

**When dispatching multiple instances of any agent that commits to the same repo workdir, the agent MUST use explicit-pathspec on `git commit -- <paths>`.** This is now part of the parallel-slice doctrine deployment caveats.

Better long-term fixes (task #150):
- Update `.claude/_script-only-agents/orianna.md` to use explicit-pathspec by default in her commit step.
- OR add a per-repo file-lock (`flock`) around the commit phase to serialize.
- OR coordinator MUST serialize Orianna dispatches (no parallel Orianna).
- Decision required pre-canonical-v1-lock.

## What this teaches about parallel-slice doctrine

The doctrine's premise — "parallelism risk is shared-state, not shared-agent-type" — held but exposed a previously-hidden shared state surface: the git index. Per-worktree isolation (Rule 20) handles content-conflict but not staging-race when multiple agents land in main directly without isolation.

Two patterns now coexist:
- **Isolated agents** (Rule 20: aphelios/kayn/xayah/caitlyn + builders that auto-worktree): no race because each has its own working directory.
- **Non-isolated agents** committing to main (Orianna, Yuumi): MUST use explicit-pathspec to scope their commits.

Going forward, any agent type that lands commits directly to main needs the explicit-pathspec discipline encoded in its agent-def.
