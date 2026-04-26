---
area: plan-lifecycle-guard
source_pr: 69
source_commit: pending
surfaced_at: 2026-04-26
status: deferred
---

Risk surfaced 2026-04-26 during PR #69 wave merge (Frontend-UX Stream B). Plan context: none authored — watch-list only per Duong directive ("we will look into it if it happens more often"). Dispatched manually by Duong's admin identity (allowlisted by Rule 19).

## R1 — Plan-lifecycle guard fires on local merge commits bringing forward Orianna-promoted plan adds

- **Source:** PR #69 attempted local `git merge origin/main` to resolve a real conflict on `.claude/agents/orianna.md`. Merge surfaced `plans/approved/personal/2026-04-26-monitor-arming-gate-bugfixes.md` (Orianna-promoted on main in commit `5557451f`) as an "add" under Evelynn's identity. Pre-commit hook `pretooluse-plan-lifecycle-guard.sh` blocked.
- **Problem:** The guard scans staged files for adds/renames/deletes under `plans/{approved,in-progress,implemented,archived}/` and checks the committing identity. It does NOT inspect lineage — a file added by a local merge of an already-Orianna-signed commit on `origin/main` looks identical to a direct add by a non-Orianna agent.
- **Why it hadn't fired before:** All prior plan promotions either (a) were Orianna's own commit (identity allowlisted), or (b) folded into a server-side `gh pr merge --squash` (no local pre-commit hook fires). PR #69 was the first to need a local conflict-resolution merge that brought forward someone else's Orianna-promoted plan adds.
- **Symptom:** Local merge of `origin/main` blocked at commit phase. Workaround: Duong commits with admin identity (`Duongntd` / `harukainguyen1411`), allowlisted by Rule 19.
- **Likelihood / Impact:** Low frequency (only when a stale PR branch hits a real merge conflict AND main has new Orianna-promoted plan adds since branch fork). Medium friction when it hits (forces human intervention; agent cannot self-merge).
- **Fix sketch:** Teach `pretooluse-plan-lifecycle-guard.sh` to exempt staged file-adds whose introducing commit is already in `origin/main` ancestry with an Orianna `Promoted-By:` trailer. Roughly: for each staged add under protected paths, run `git log -1 --diff-filter=A --follow --format=%H -- <path>` against the merge-base ancestry; if the introducing commit is in `origin/main` and carries the trailer, exempt.
- **Status:** Deferred. No plan authored. Action threshold: revisit if this recurs ≥2 more times.
