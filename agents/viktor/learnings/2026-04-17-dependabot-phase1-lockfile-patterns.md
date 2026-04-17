# Dependabot Phase 1 — Lockfile Patterns and Gotchas

## npm overrides + lockfile regen always starts fresh

npm `overrides` in `package.json` are only honoured when the lockfile is regenerated from scratch. Updating an existing lockfile with `npm install --package-lock-only` leaves pinned transitive versions untouched. Always delete the lockfile before running install when overrides need to take effect.

**Why:** npm's lockfile-first resolution strategy freezes all versions; overrides only participate at initial resolution time.

## Workspace membership blocks standalone lockfile regen

Any app listed in root `workspaces` cannot generate its own `package-lock.json` — npm absorbs it into the root. Apps that need standalone lockfiles (for `npm ci` in CI workflows) must be temporarily removed from root workspaces during regen, then restored in the same commit.

**Approved pattern (B2, B3):** remove from workspaces → `rm package-lock.json` in app dir → `npm install --package-lock-only` from app dir → restore workspaces. All in one working set, committed together.

**Exception (myapps):** this pattern was blocked by a hook for `apps/myapps` due to blast-radius concern. Team-lead authorised it explicitly for B2/B3 apps but for myapps directed surgical lockfile surgery instead.

## Floating-version drift on full lockfile regen

Every full regen picks up floating-range upgrades that have been published since the last install. For small lockfiles (functions, bee-worker) this produces a handful of packages that can be pinned back with extra overrides. For large lockfiles (myapps — 16,895 lines, 200+ drifted packages), pinning is not feasible.

**Pattern for small lockfiles:** run drift check (`git show main:path | python3` comparison), identify drifted packages, add them to overrides, regen again.

**Pattern for large lockfiles (myapps):** use targeted lockfile surgery (see below).

## Targeted lockfile surgery — authorised exception for myapps

For `apps/myapps/package-lock.json`, full regen produces 200+ unreviewed transitive bumps making the PR unreviewable. Team-lead authorised surgical patching as an exception to the plan's "no manual lockfile edits" rule, with these guardrails:

1. Source `version`, `resolved`, `integrity` exclusively from `npm view <pkg>@<ver> dist.integrity dist.tarball`
2. Verify with `npm ci --ignore-scripts` after patching — if integrity fails, stop
3. Include raw `npm view` output in PR description as evidence
4. Explicitly list every field change in PR description (field, before, after)
5. Scope strictly: only the security-targeted packages

**This pattern applies to all B4b–B4f myapps batches.**

## Dependabot alert auto-closure requires the manifest file to exist

Dependabot alerts reference specific manifest paths. If `apps/myapps/package-lock.json` is deleted (e.g. absorbed into root), alerts pointing to it will not auto-close on merge — they require manual dismissal. Never delete a standalone lockfile that workflows depend on via `npm ci` / `cache-dependency-path`.

## Workflow dependency audit before touching any lockfile

Before regenerating any app's lockfile, check `.github/workflows/` for:
- `cache-dependency-path:` references
- `working-directory:` + `npm ci` combinations
- `hashFiles(...)` references

All three workflows for myapps (`myapps-prod-deploy.yml`, `myapps-test.yml`, `myapps-pr-preview.yml`) hard-reference `apps/myapps/package-lock.json`. Deleting it would break prod deploys immediately.
