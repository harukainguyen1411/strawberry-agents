# jayce Memory

- [2026-04-17 B8 vite 7 bump](../learnings/2026-04-17-b8-vite7-direct-bump.md) — workspace lockfile conflict resolution, plugin-vue compat, test mock patterns, alert scope (direct vs transitive)
- [2026-04-18 D2 POST /api/runs](../learnings/2026-04-18-d2-post-runs-xfail-vitest-mocking.md) — it.failing→it.fails fix, INGEST_TOKEN env pattern for middleware tests, cross-worktree dep bundling
- [2026-04-18 B16a PR supersession recon](../learnings/2026-04-18-b16a-pr-supersession-recon.md) — check alert manifest_path + current main state before rebasing stale dependabot PRs
- [2026-04-18 Rule-3 raw-worktree precedent](../learnings/2026-04-18-raw-worktree-add-rule3-precedent.md) — raw `git worktree add` OK with team-lead authorization; wrapper guard is convenience, rule 1 is the invariant
- [2026-04-18 unit-tests workflow npm install](../learnings/2026-04-18-unit-tests-workflow-npm-install.md) — missing npm install in CI workflow; CWD-relative require fix; first-PR latent bug pattern

## Sessions
- 2026-04-18: Assigned B16 (task #8); B16a worktree created, recon surfaced PR #141 supersession path; stood down on GitHub Actions billing block before any commit/push.
- 2026-04-18 (session 2): D2 POST /api/runs (PR #177) + D1 report-run.sh fixes (PR #169) + B3 signed-urls CI fixes (PR #154). All three PRs pushed; awaiting Jhin/Azir review + Duong merge.
