# B16a — PR supersession recon before merging dependabot majors

When a dependabot PR has sat open while related batches merged, its diff may no longer reflect reality. Before touching a stale dependabot PR for a dep that was partially addressed on main:

1. `gh api repos/<org>/<repo>/dependabot/alerts/<N>` → read `.dependency.manifest_path`. This is the authoritative thing the PR must actually touch to close the alert.
2. Compare main's current `package.json` + relevant lockfiles against the PR's diff base. If main already contains the PR's manifest edits (another batch pre-landed them), the PR's package.json hunks will no-op on rebase and the real work reduces to whatever lockfile still drifts.
3. Propose supersession to team lead rather than rebasing the dependabot PR. Dependabot branches are brittle under rebase; a fresh `deps/<batch>-<date>` branch with the minimal lockfile regen is cleaner and smaller blast radius.

**B16a specifics:** PR #141 (vite 5→7 myapps). Commit e9f1b25 had already landed the manifest change (vite ^7.3.2 + plugin-vue ^6.0.6) in `apps/myapps/package.json` via B8. Alert #66's manifest_path was `apps/myapps/package-lock.json` — the per-app lockfile, still pinning vite 5.4.21. The fix reduced to `cd apps/myapps && npm install --package-lock-only`. No package.json edit needed.

**Why this matters:** rebasing a dependabot PR through a conflict when the conflict means "your change already happened" wastes reviewer cycles and produces a confusing diff. Recon first, propose supersession, then do the minimal work.
