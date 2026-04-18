# CI total-red with opaque logs → check GitHub Actions billing first

**Heuristic:** if every required check on every PR goes red at the same instant, and log retrieval fails or returns "queue rejected" style errors, check GitHub Actions billing / spending-limit BEFORE investigating workflows, secrets, or runner images.

**Symptom pattern:**
- Every PR's required checks flip red simultaneously.
- Jobs show as failed/cancelled before any step runs — no step logs to retrieve.
- Error text mentions payment failures, queued-but-not-started, or spending limits.

**Why it looks like a workflow regression:** the timing coincides with recent merges, so the pattern-match is "last merge broke CI." Don't fall for it. A workflow regression would affect specific jobs, not every job on every PR simultaneously.

**Diagnostic shortcut:** `gh api /repos/<org>/<repo>/actions/runs?per_page=1 --jq '.workflow_runs[0].conclusion + " / " + .workflow_runs[0].status'` — if every recent run is `failure / completed` with no step output, and the org has billing configured, billing is the most probable cause.

**Historic cost:** on 2026-04-18 the team spent ~30 minutes investigating workflows before someone checked the billing page. Target for next time: 2 minutes.

**Recovery actions after billing unblocks:** existing queued runs typically resume; if not, empty-commit nudge or `gh workflow run` re-triggers. PRs that were parked with red checks need a new push or `/retest`-equivalent to flip green.
