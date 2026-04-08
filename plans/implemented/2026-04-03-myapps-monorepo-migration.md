---
status: draft
owner: pyke
gdoc_id: 1tp49ByEtMXURBPnQj1TuetyOV6OxPb55GI5Iej7yvIA
gdoc_url: https://docs.google.com/document/d/1tp49ByEtMXURBPnQj1TuetyOV6OxPb55GI5Iej7yvIA/edit
---

# Myapps → Strawberry Monorepo Migration

Merge the `myapps` repo into `strawberry` under `apps/myapps/`, preserving full git history.

## Prerequisites

- [ ] Install `git-filter-repo`: `brew install git-filter-repo`
- [ ] Ensure local `strawberry` main is clean and up to date with origin
- [ ] Clone a fresh copy of `myapps` for the rewrite (do NOT rewrite the working copy)
- [ ] Back up: `git tag pre-monorepo-migration` on both repos

## Step 1 — Rewrite myapps history into subdirectory

```bash
# Fresh clone (throwaway — filter-repo rewrites in place)
git clone https://github.com/Duongntd/myapps.git /tmp/myapps-rewrite
cd /tmp/myapps-rewrite

# Rewrite all paths to live under apps/myapps/
git filter-repo --to-subdirectory-filter apps/myapps
```

After this, every file in every commit appears under `apps/myapps/`. All SHAs are rewritten.

## Step 2 — Merge into strawberry

```bash
cd ~/Documents/Personal/strawberry
git checkout main
git pull origin main

# Add the rewritten repo as a remote
git remote add myapps-import /tmp/myapps-rewrite
git fetch myapps-import

# Create a feature branch
git checkout -b feature/import-myapps

# Merge with unrelated histories
git merge myapps-import/main --allow-unrelated-histories -m "feat: import myapps with full git history"

# Clean up remote
git remote remove myapps-import
```

## Step 3 — Verify folder structure

Expected layout after merge:

```
strawberry/
├── agents/
├── apps/
│   └── myapps/
│       ├── .github/workflows/   (moved in Step 5)
│       ├── src/
│       ├── e2e/
│       ├── public/
│       ├── firebase.json
│       ├── .firebaserc
│       ├── firestore.rules
│       ├── package.json
│       ├── vite.config.ts
│       └── ...
├── mcps/
├── services/
├── scripts/
├── plans/
├── CLAUDE.md
└── README.md
```

Verification:
- [ ] `git log --oneline apps/myapps/src/` shows full myapps history
- [ ] `git blame apps/myapps/src/App.vue` (or equivalent) shows original authors/dates
- [ ] No files from myapps leaked outside `apps/myapps/`

## Step 4 — Firebase configuration

The myapps Firebase project is `myapps-b31ea`. Two options:

**Option A (recommended): Keep firebase config inside apps/myapps/**
- No changes to `firebase.json` or `.firebaserc` — they stay at `apps/myapps/`
- Deploy with: `cd apps/myapps && npm run build && firebase deploy`
- Build output stays at `apps/myapps/dist`

**Option B: Root-level firebase config**
- Move `.firebaserc` to repo root
- Create root `firebase.json` pointing `hosting.public` to `apps/myapps/dist`
- Update `firestore.rules` path to `apps/myapps/firestore.rules`

Option A is simpler and avoids polluting the monorepo root with app-specific config.

- [ ] Confirm Firebase deploy works: `cd apps/myapps && firebase deploy --only hosting`
- [ ] Confirm Firestore rules deploy: `cd apps/myapps && firebase deploy --only firestore`

## Step 5 — CI/CD workflow migration

myapps has two workflows: `ci.yml` and `deploy-release.yml`.

```bash
# Move workflows to strawberry's .github/workflows/ with prefix
mkdir -p .github/workflows
cp apps/myapps/.github/workflows/ci.yml .github/workflows/myapps-ci.yml
cp apps/myapps/.github/workflows/deploy-release.yml .github/workflows/myapps-deploy.yml

# Remove the nested .github from apps/myapps (GitHub only reads root .github)
rm -rf apps/myapps/.github
```

Update both workflows:
- [ ] Add path filter: `on.push.paths: ['apps/myapps/**']` and `on.pull_request.paths: ['apps/myapps/**']`
- [ ] Set `defaults.run.working-directory: apps/myapps` (or add `working-directory` to each step)
- [ ] Verify `npm ci`, `npm run build`, `npm run test` commands work from `apps/myapps/`
- [ ] Verify Firebase deploy step uses correct working directory
- [ ] Update any artifact paths (e.g., coverage reports, build outputs)

## Step 6 — Cleanup & final verification

- [ ] Update `apps/myapps/.gitignore` — remove entries now handled by root `.gitignore` (if any)
- [ ] Update `apps/myapps/README.md` — note it's now part of the strawberry monorepo
- [ ] Run `cd apps/myapps && npm ci && npm run build` — confirm build works
- [ ] Run `cd apps/myapps && npm run test` — confirm tests pass
- [ ] Run `cd apps/myapps && npx playwright test` — confirm e2e (if configured)
- [ ] Push feature branch, create PR
- [ ] CI passes on the PR

## Step 7 — Post-merge

- [ ] Archive the original `myapps` repo on GitHub (Settings → Archive)
- [ ] Update any bookmarks, deploy scripts, or documentation pointing to the old repo
- [ ] Remove `/tmp/myapps-rewrite` clone

## Rollback

If anything goes wrong before merge to main:

```bash
# Delete the feature branch
git checkout main
git branch -D feature/import-myapps

# Everything is back to normal — main was never touched
```

If already merged to main:

```bash
# Revert the merge commit
git revert -m 1 <merge-commit-sha>
```

The `pre-monorepo-migration` tag on both repos serves as the restore point.

## Trade-offs noted

| Aspect | Impact |
|---|---|
| SHA rewrite | All myapps commit SHAs change. Old references (issues, PRs) in the myapps repo won't link to the new SHAs |
| Repo size | Strawberry gains myapps' full history (~453KB). Negligible |
| Firebase | No config changes needed if deploying from `apps/myapps/` |
| CI minutes | Path filters prevent unnecessary runs. No cost increase |
