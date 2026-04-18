---
date: 2026-04-18
topic: Reconciling Dependabot batch tasks against live state before executing
batches: B4b (hono no-op), B4c (build-toolchain no-op), B4g (vitest 2→3)
---

## Always reconcile plan-scoped batches against live state before cutting a worktree

Multiple batches from plans/in-progress/2026-04-17-dependabot-remediation.md turned out to be no-ops by 2026-04-18 because earlier work had already resolved them. The reconciliation check takes ~5 minutes and saves cutting a worktree for nothing.

**Check sequence:**

1. **Live Dependabot alerts.** `gh api --paginate "/repos/<org>/<repo>/dependabot/alerts?per_page=100" > /tmp/all.json`, then filter by the batch's package name(s) and manifest. Historical-state=fixed rows confirm alert already closed; zero state=open rows on a scoped package means nothing to do. (Warning: `gh api ... | jq ... | head -N` can SIGPIPE to empty output — always write to file first.)

2. **Current installed versions.** `jq -r '.packages | to_entries[] | select(.key | test("^node_modules/(pkg1|pkg2)$")) | "\(.key)  \(.value.version)"' <manifest>/package-lock.json`. Compare to the first-patched-version in each alert.

3. **package.json vs lockfile drift.** `jq '.devDependencies.<pkg>' <manifest>/package.json` vs the root-package constraint `jq '.packages[""].devDependencies.<pkg>' <manifest>/package-lock.json`. Mismatch means someone bumped package.json without regenerating the lockfile — a subsequent `npm install` will resolve to the package.json version, not what the plan assumed.

**Two no-ops this session:**

- **B4b (hono family, apps/myapps)**: all 18 historical hono/@hono/node-server alerts state=fixed; current versions hono@4.12.14 and @hono/node-server@1.19.14 exceed all first-patched versions. No open alerts.
- **B4c (vite+rollup+esbuild build toolchain, apps/myapps)**: only alert #66 in scope (vite med, fix 6.4.2); rollup@4.59.0 and esbuild@0.25.0 already at targets; package.json already declares `vite ^7.3.2` (commit e9f1b25 B8 pre-landed it without regenerating the lockfile). Any `npm install` would resolve vite 7, colliding head-on with B16a/PR #141 — making an independent B4c bump impossible without reverting B8.

Record both with a short note appended to the plan row so the reconciliation history survives.

## Detect duplicate Dependabot PRs before executing either

Dependabot's grouped-update feature can file two PRs for the same net change, titled by different "ancestor" direct deps. They can look independent in the PR list but be byte-identical in lockfile.

**Check:** `diff <(git diff main..pr-<a> -- <manifest>/package-lock.json) <(git diff main..pr-<b> -- <manifest>/package-lock.json)`. Empty diff = duplicates. Also diff the package.json changes — if both change only one line identically, they are the same work.

PRs #98 and #99 in bee-worker were exactly this: both bumped `vitest ^2.1.0 → ^4.1.4`, byte-identical lockfile diffs, different titles (#98 called it "esbuild + vitest", #99 "vite + vitest"). One CI pass, one CI fail — the split was a flake, not evidence of safety.

## Dependabot grouping can silently extend scope past plan intent

Plan B4g scoped `vitest 2→3.x` (code-change-required due to vitest 3 API drift). Dependabot PRs #98/#99 proposed `vitest 2→4`, crossing an extra major boundary. The grouped PR title doesn't flag the scope jump — you have to read the package.json diff.

Pattern: when a Dependabot PR proposes bumping a direct devDependency, check the major it lands on vs the plan's approved major; if different, close the PR and ship a plan-scoped replacement referencing the scope mismatch in the close comment.

## bee-worker confirmed standalone (not a workspace member)

Root `package.json` `workspaces` array includes `apps/portal`, `apps/myapps`, `apps/landing`, `apps/shared`, `apps/myapps/*`, `apps/yourApps/*`, `apps/myapps/functions`, `dashboards/*` — not `apps/private-apps/*`. So `apps/private-apps/bee-worker` can regen its lockfile standalone per ekko's discord-relay learning: delete lockfile, `npm install --package-lock-only` in the app dir, no workspaces-remove/restore dance.

Empirical result for vitest 2→3 bump in bee-worker: -320 net lockfile lines, matching ekko's discord-relay figure.

## No test files = vitest 2→3 API risks are N/A

bee-worker has zero `*.test.*` / `*.spec.*` files. All vitest 2→3 API-level risks (`vi.mocked` deprecation, `mockReset` default change, `test.concurrent` suite-level deprecation) do not apply. `vitest run` with no test files exits 1 in both vitest 2.1 and 3.2 (confirmed via tmp probe) — this is not a regression introduced by the bump.

Document in the PR body so reviewers don't chase the exit-1 as a failure.
