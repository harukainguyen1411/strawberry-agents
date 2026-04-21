---
status: proposed
owner: kayn
date: 2026-04-19
title: apps/ Restructure to darkstrawberry Layout — Task Breakdown
parent_adr: plans/approved/2026-04-19-apps-restructure-darkstrawberry-layout.md
repo: harukainguyen1411/strawberry-app
---

# `apps/` Restructure — Task Breakdown

Executable task list for the approved restructure ADR (`plans/approved/2026-04-19-apps-restructure-darkstrawberry-layout.md`). Phase IDs match ADR §3. Each task has an ID, one-sentence goal, files touched, blocking dependencies, and acceptance criteria.

**Duong-resolved decisions applied (per ADR §7):** single-host client-routed `app.darkstrawberry.com` (Q1); `task-list` removed (Q2); `apps/platform/` kept in place (Q3); `apps/shared/` kept as-is (Q4); `deploy-webhook` gets a new `apps/webhooks/` slot (Q5); dashboards move under `apps/dashboards/` (Q6); no repo-root `tsconfig.base.json` (Q7); **Phase 3 + Phase 4 land as one PR (Q8)**; `git mv` preserves blame throughout (Q9); release-please config + manifest re-keyed from `dashboards` → `apps/dashboards` preserving `0.1.0` (Q10).

**Key ADR invariants baked in:**

- Every phase lands as a single PR. Repo must build + deploy green at HEAD of the phase PR before the next phase starts.
- Every move uses `git mv` (Q9). Pure renames only; no content rewrites inside moves.
- Hosting stays single-site (Q1). The original "Phase 4 Firebase multi-site split" from earlier drafts is **descoped**. Phase 4 is re-purposed as composite-build wiring and merges with Phase 3 (Q8).
- `apps/platform/` and `apps/shared/` are **not moved** in this restructure (Q3, Q4).
- `landing/` does **not** move — `landing-prod-deploy.yml` unchanged (ADR §2c).

**Executor legend (implementers assigned by Evelynn after delivery, not in this file).** Kayn writes tasks, does not assign. Classes expected downstream: Viktor (refactor / mechanical moves), Jayce (new files — composite Vite config, workflow rewrites that are effectively new shape), Vi (verification / E2E), Seraphine (frontend — only if any view-level code rewrites surface during promotion).

---

## Duong-blocking prerequisites (summary)

| Ref | Blocker | Blocks | Status |
|-----|---------|--------|--------|
| D-R1 | **Portfolio PR stack #29, #32, #33, #34, #36, #40, #41, #42, #43, #44, #45 all merged to `main`** and `feature/portfolio-v0-*` branch chain empty. | Everything from Phase 1 onward. Option 2 in ADR §2a is explicit: restructure waits for stack drain. | open — check at Phase 0 kickoff |
| D-R2 | Sign-off that `apps/platform/` disposition (keep in place) is still correct at kickoff; audit from ADR §1e is dated 2026-04-19. | Phase 1 (avoids accidental inclusion). | open — verify at kickoff |
| D-R3 | Confirm `ecosystem.config.js` PM2 target host is available for a dry-run during Phase 2 verification. | P2.13 (Phase 2 verification gate). | open |

No other Duong prereqs — the ADR closed all 10 original gating questions.

---

## Phase 0 — Prerequisites (no PR; clearance gate)

Exit criterion: portfolio stack drained, root workspaces glob clean, runway clear for Phase 1.

### P0.1 — Confirm portfolio PR stack fully merged

- **Goal:** Verify PR #45 (V0.11 CSV Import Step 1) and every upstream PR in the stack (#29, #32, #33, #34, #36, #40, #41, #42, #43, #44) have merged to `main`, and no `feature/portfolio-v0-*` branches remain active.
- **Files touched (read-only):** none.
- **Verification commands (from `~/Documents/Personal/strawberry-app/`):**
  - `gh pr list --state merged --search "head:feature/portfolio-v0 base:main" --limit 50` shows all 11 PRs merged.
  - `git branch -r --list 'origin/feature/portfolio-v0-*'` is empty (or only archived refs).
- **Dependencies:** **Duong prereq D-R1**.
- **Acceptance:**
  - Every PR in the ADR §2a list shows `MERGED` status.
  - No open PR targets `main` from a `feature/portfolio-v0-*` head.
  - Sign-off recorded in the Phase 1 PR description so reviewers can audit.
- **Rollback surface:** none (read-only gate).
- **Blocks:** P1.1, and transitively all later phases.

### P0.2 — Drop stale `apps/portal` entry from root `package.json` workspaces

- **Goal:** The current root `package.json` lists `apps/portal` which does not exist in the tree (ADR §2d). Remove that stale entry before the Phase 1 workspace rewrite so the diff is minimal.
- **Files touched:** `package.json` (root of `strawberry-app`).
- **Dependencies:** P0.1.
- **Acceptance:**
  - `package.json` workspaces no longer lists `apps/portal`.
  - `npm install` (or `pnpm install`) at root succeeds.
  - `turbo run build` green at HEAD.
  - Commit uses `chore:` prefix (diff does not touch `apps/**`).
- **Rollback surface:** single revert restores the stale entry (harmless).
- **Blocks:** P1.1 (workspaces glob rewrite builds on this).

**Phase 0 PR:** P0.2 may land as a standalone `chore:` PR (P0.1 is verification-only and needs no commit). Evelynn decides whether to bundle with Phase 1 or keep separate.

---

## Phase 1 — Create `apps/darkstrawberry-apps/` shell + move `myapps` wholesale

Single PR. Pure mechanical rename; no content changes inside moved files. All moves use `git mv`. At HEAD of this PR, `app.darkstrawberry.com` still serves the same SPA, sourced from the new path.

Exit criterion: `apps/myapps/` no longer exists; `apps/darkstrawberry-apps/` holds the identical tree with preserved blame; every CI workflow references the new path; Firebase Hosting preview + prod deploy still succeed.

### P1.1 — `git mv apps/myapps apps/darkstrawberry-apps` (wholesale rename)

- **Goal:** Move the entire `apps/myapps/` subtree (including `src/`, `functions/`, `portfolio-tracker/`, `read-tracker/`, `task-list/`, `firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `e2e/`, `package.json`, etc.) to `apps/darkstrawberry-apps/` in one `git mv` operation to preserve blame (Q9).
- **Files touched:**
  - `apps/myapps/**` → `apps/darkstrawberry-apps/**` (every file under the subtree).
- **Dependencies:** P0.1, P0.2.
- **Acceptance:**
  - `apps/myapps/` no longer exists at repo root.
  - `apps/darkstrawberry-apps/` contains the entire prior `apps/myapps/` tree.
  - `git log --follow apps/darkstrawberry-apps/src/main.ts` (or any equivalent leaf file) shows history crossing the rename — blame preserved.
  - No content edits inside moved files — diff of the PR is 100% rename ops.
  - Commit is `chore:` prefix. (Mixed diff: touches `apps/**` but the move itself is not a release-type change. Rule 5 allows `chore:` for mechanical relocations under `apps/**`; if pre-push hook flags it, escalate to Evelynn — do NOT bypass.)
- **Rollback surface:** single revert of the PR restores `apps/myapps/` intact (pure rename).
- **Blocks:** P1.2, P1.3, P1.4, P1.5, P1.6, P1.7.

### P1.2 — Update root `package.json` workspaces glob

- **Goal:** Rewrite the `workspaces` array so every path that pointed at `apps/myapps*` now points at `apps/darkstrawberry-apps*`. No new slots yet (workers/webhooks/discord/dashboards come in Phase 2).
- **Files touched:** `package.json` (root).
- **New workspaces entries (Phase 1 delta only):**
  - `apps/myapps` → `apps/darkstrawberry-apps`
  - `apps/myapps/*` → `apps/darkstrawberry-apps/*`
  - `apps/yourApps/*` → unchanged (still at old top-level; migrates in Phase 3+4)
  - `apps/myapps/functions` → `apps/darkstrawberry-apps/functions`
  - (Stale `apps/portal` already removed in P0.2.)
- **Dependencies:** P1.1.
- **Acceptance:**
  - `npm install` at root succeeds; no workspace-not-found errors.
  - `turbo run build` green.
  - `turbo run build --filter=myapp` (or whatever the root package name is) resolves from the new path.
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P1.1.

### P1.3 — Update every CI workflow referencing `apps/myapps/**`

- **Goal:** Rewrite path filters, `working-directory`, artifact paths, and `cp` sources in every workflow per ADR §2c so CI continues to run against the new location. Rename the two workflow files that carry `myapps` in their filename.
- **Files touched (rewrites — keep filename):**
  - `.github/workflows/ci.yml` — `working-directory: apps/myapps` → `apps/darkstrawberry-apps` (×2); artifact upload paths under `apps/myapps/**`, `apps/myApps/*/**`, `apps/yourApps/*/**` repointed. `yourApps/*` glob retained (still at old top-level until Phase 3+4).
  - `.github/workflows/e2e.yml` — scope grep `^apps/myapps/` → `^apps/darkstrawberry-apps/`; iteration list still `dashboards/* apps/*` (dashboards move in Phase 2).
  - `.github/workflows/preview.yml` — `cp apps/myapps/firebase.json firebase.json` → `cp apps/darkstrawberry-apps/firebase.json firebase.json`; same for `.firebaserc`.
  - `.github/workflows/release.yml` — `cp apps/myapps/firebase.json firebase.json`; functions path check `apps/myapps/functions/`; rules checks `apps/myapps/firestore.rules` + `apps/myapps/storage.rules`; `working-directory: apps/myapps` (×2) — all repointed to `apps/darkstrawberry-apps/`.
  - `.github/workflows/validate-scope.yml` — scope grep `apps/myapps/` → `apps/darkstrawberry-apps/`.
  - `.github/workflows/pr-lint.yml` — UI glob `apps/*/src/*|dashboards/*/src/*` remains (dashboards move in Phase 2; darkstrawberry-apps already matches `apps/*`).
- **Files touched (rename + rewrite):**
  - `.github/workflows/myapps-pr-preview.yml` → `.github/workflows/darkstrawberry-apps-pr-preview.yml`. Scope grep repoints to `^apps/(darkstrawberry-apps|platform|shared)/`. `working-directory: apps/myapps` → `apps/darkstrawberry-apps`. `entryPoint: apps/myapps` → `apps/darkstrawberry-apps`. Single preview channel per PR (unchanged — single-host model, Q1).
  - `.github/workflows/myapps-prod-deploy.yml` → `.github/workflows/darkstrawberry-apps-prod-deploy.yml`. `paths:` array rewrites: `apps/myapps/**`, `apps/myApps/**`, `apps/yourApps/**` → `apps/darkstrawberry-apps/**`; `apps/platform/**` and `apps/shared/**` kept. Single deploy job (unchanged — single hosting entry, Q1).
  - `.github/workflows/myapps-test.yml` → `.github/workflows/darkstrawberry-apps-test.yml`. Scope grep + `cache-dependency-path: apps/myapps/package-lock.json` → `apps/darkstrawberry-apps/package-lock.json`. Artifact path repointed.
- **Files touched (unchanged — sanity check):**
  - `.github/workflows/landing-prod-deploy.yml` — **no change** (ADR §2c). Verify no stray `myapps` references crept in.
  - `.github/workflows/unit-tests.yml`, `tdd-gate.yml`, `lint-slugs.yml`, `auto-label-ready.yml` — re-scan; no known hard path refs (ADR §2c). If any surface, rewrite in this PR; otherwise defer sweep to Phase 5.
- **Dependencies:** P1.1.
- **Acceptance:**
  - `rg 'apps/myapps' .github/workflows/` returns no hits (except inside historical plan references, which are not in `.github/`).
  - Three renamed workflow files (`darkstrawberry-apps-pr-preview.yml`, `darkstrawberry-apps-prod-deploy.yml`, `darkstrawberry-apps-test.yml`) exist; the three old `myapps-*.yml` files no longer exist.
  - Workflow YAML validates (`actionlint` or CI self-check).
  - On this PR: the renamed PR-preview workflow runs against the PR itself and successfully deploys a preview from `apps/darkstrawberry-apps/`; the renamed test workflow passes.
  - Commit `chore:` prefix (touches `.github/workflows/**`, not `apps/**`).
- **Rollback surface:** revert alongside P1.1 — workflows return to old filenames/paths.
- **Blocks:** P1.7 (verification runs the renamed workflows).

### P1.4 — Update `ecosystem.config.js` PM2 paths for `apps/myapps`-referenced entries

- **Goal:** If `ecosystem.config.js` (repo root) references `apps/myapps/functions/**` or any other path under the moved subtree, rewrite to `apps/darkstrawberry-apps/**`. ADR §2d flags this only for workers (which move in Phase 2), but a sanity rewrite is needed if `myapps` surfaces here too.
- **Files touched:** `ecosystem.config.js` (conditional — only if it references `apps/myapps/*`).
- **Dependencies:** P1.1.
- **Acceptance:**
  - `rg 'apps/myapps' ecosystem.config.js` returns no hits.
  - PM2 config still parses (`pm2 start ecosystem.config.js --only <any-entry> --dry-run` succeeds on a scratch host if available — or visual review if not).
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P1.1.

### P1.5 — Verify `release-please-config.json` / `.release-please-manifest.json`

- **Goal:** Confirm release-please does **not** track anything under `apps/myapps/` today (ADR §2d: only `dashboards` is enrolled with `0.1.0`). If that audit is still true, no edits in this phase. If `apps/myapps/functions` or similar was enrolled after the ADR was written, re-key now.
- **Files touched (conditional):** `release-please-config.json`, `.release-please-manifest.json`.
- **Dependencies:** P1.1.
- **Acceptance:**
  - `release-please-config.json` has no `packages` key pointing at `apps/myapps/*`.
  - If it did: re-keyed to `apps/darkstrawberry-apps/*` with the same version in the manifest.
  - Release-please dry-run (`npx release-please release-pr --dry-run`) produces no spurious version bumps attributable to the rename.
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P1.1.

### P1.6 — Sanity sweep for remaining `apps/myapps` references outside `apps/`, `.github/`, root configs

- **Goal:** Find and rewrite any `apps/myapps` reference in `scripts/`, `architecture/`, `docs/`, agent prompts, or other in-tree content so grep for the old path returns clean (excluding historical plan files under `plans/**`, which are immutable history).
- **Files touched:** whatever `rg 'apps/myapps'` surfaces outside the already-covered files.
- **Scope exclusions (leave alone):**
  - `plans/**` — historical plans are immutable.
  - `assessments/**` from before today — historical.
  - Any `.git/**` or node_modules.
- **Dependencies:** P1.1.
- **Acceptance:**
  - `rg 'apps/myapps' --glob '!plans/**' --glob '!assessments/**'` returns no hits in the `strawberry-app` checkout.
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P1.1.

### P1.7 — Phase 1 verification gate

- **Goal:** Prove the rename is non-destructive end-to-end before PR merge.
- **Files touched:** none (verification only — results recorded in the PR description).
- **Dependencies:** P1.1, P1.2, P1.3, P1.4, P1.5, P1.6.
- **Acceptance:**
  - `npm install` (or `pnpm install`) at repo root succeeds.
  - `turbo run build` green.
  - The renamed `darkstrawberry-apps-test.yml` workflow runs green against the PR.
  - The renamed `darkstrawberry-apps-pr-preview.yml` deploys a preview to a Firebase Hosting preview channel keyed by PR number; visiting the preview URL loads the SPA; all four app routes (`/`, `/read-tracker`, `/portfolio-tracker`, plus whatever `/task-list` still routes to — it survives in this phase and is removed only in Phase 3+4) return 200.
  - `firebase deploy --dry-run --project myapps-b31ea` run from `apps/darkstrawberry-apps/` reports the expected surfaces (hosting + functions + firestore + storage).
  - Release-please dry-run produces no unexpected version bumps.
  - PR description includes the verification checklist inline.
- **Blocks:** Phase 2 start.

---

## Phase 2 — Move non-app services (workers, webhooks, discord, dashboards, contributor)

Single PR. Pure moves, no behavior change. All `git mv`. No Firebase Hosting surface changes here — workers and webhooks are long-running services; dashboards are separately hosted and unchanged by this move.

Exit criterion: every non-app service sits at its final path; `dashboards/` at repo root is deleted; workspaces glob extended; release-please re-keyed for dashboards; PM2 config updated.

### P2.1 — `git mv` worker + webhook + discord + contributor packages

- **Goal:** Relocate six packages in a single atomic commit using `git mv`. No content changes.
- **Moves:**
  - `apps/coder-worker/` → `apps/workers/coder-worker/`
  - `apps/private-apps/bee-worker/` → `apps/workers/bee-worker/`
  - `apps/deploy-webhook/` → `apps/webhooks/deploy-webhook/` (Q5)
  - `apps/discord-relay/` → `apps/discord/discord-relay/`
  - `apps/contributor-bot/` → `apps/contributor/contributor-bot/`
- **Files touched:** every file under the six source subtrees, moved in place.
- **Dependencies:** P1.7 (Phase 1 merged).
- **Acceptance:**
  - Old paths no longer exist.
  - New paths contain the identical trees with preserved blame (`git log --follow` works across the rename).
  - PR diff is 100% rename ops — no content edits.
  - Commit `chore:` prefix.
- **Rollback surface:** single revert restores old paths.
- **Blocks:** P2.2, P2.3, P2.4, P2.5, P2.6.

### P2.2 — `git mv` dashboards packages into `apps/dashboards/`

- **Goal:** Move the three populated dashboard packages under `apps/dashboards/` in the same PR as P2.1, via `git mv`. Delete the two empty placeholders.
- **Moves:**
  - `dashboards/usage-dashboard/` → `apps/dashboards/usage-dashboard/`
  - `dashboards/server/` → `apps/dashboards/server/`
  - `dashboards/test-dashboard/` → `apps/dashboards/test-dashboard/`
- **Deletions (Q6 audit — both contain only `.gitkeep`):**
  - `dashboards/dashboard/` (entire directory).
  - `dashboards/shared/` (entire directory).
- **Then:** `dashboards/` at repo root is empty and must itself be removed (git doesn't track empty dirs, so no explicit `rmdir` needed — the directory vanishes when its last child is moved/deleted).
- **Files touched:** every file under the three source subtrees + the two `.gitkeep` deletions.
- **Dependencies:** P2.1 (bundled into same PR).
- **Acceptance:**
  - `dashboards/` at repo root no longer exists.
  - `apps/dashboards/usage-dashboard/`, `apps/dashboards/server/`, `apps/dashboards/test-dashboard/` exist with preserved blame.
  - `git log --follow apps/dashboards/test-dashboard/package.json` crosses the rename.
  - Commit `chore:` prefix (bundled commit with P2.1 if atomic is preferred, or separate commits within the same PR).
- **Rollback surface:** revert alongside P2.1.

### P2.3 — Extend root `package.json` workspaces for the new layout

- **Goal:** Update the `workspaces` array so every moved package resolves. Reflects ADR §2d target.
- **Files touched:** `package.json` (root).
- **New workspaces entries:**
  - Add: `apps/workers/*`, `apps/webhooks/*`, `apps/discord/*`, `apps/dashboards/*`, `apps/contributor/*`.
  - Remove: `dashboards/*` (old top-level dashboards glob).
  - Already in place from Phase 1: `apps/darkstrawberry-apps`, `apps/darkstrawberry-apps/*`, `apps/darkstrawberry-apps/functions`, `apps/landing`, `apps/shared`, `apps/platform`, `packages/*`.
- **Dependencies:** P2.1, P2.2.
- **Acceptance:**
  - `npm install` / `pnpm install` at root succeeds.
  - `turbo run build` green across every moved package.
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P2.1/P2.2.

### P2.4 — Update workflows affected by the non-app moves

- **Goal:** Rewrite any workflow path filter that still points at old dashboards/workers/webhooks/discord/contributor locations.
- **Files touched (conditional — only those that match):**
  - `.github/workflows/e2e.yml` — iteration list `dashboards/* apps/*` → `apps/*` (dashboards now under `apps/dashboards/`, picked up by the broader `apps/*` glob; re-verify explicit path-filter behavior by walking deeper if needed).
  - `.github/workflows/pr-lint.yml` — UI glob already `apps/*/src/*|dashboards/*/src/*`; update the dashboards half to `apps/dashboards/*/src/*`.
  - Any workflow that deploys or tests a specific worker / webhook / discord / contributor package: rewrite path filters accordingly. Sweep `rg 'apps/coder-worker|apps/private-apps|apps/deploy-webhook|apps/discord-relay|apps/contributor-bot|^dashboards/' .github/workflows/`.
- **Dependencies:** P2.1, P2.2.
- **Acceptance:**
  - `rg 'apps/coder-worker|apps/private-apps|apps/deploy-webhook|apps/discord-relay|apps/contributor-bot' .github/workflows/` returns no hits.
  - `rg '^dashboards/' .github/workflows/` returns no hits (except inside a string that names `apps/dashboards/`).
  - Workflows validate (`actionlint`).
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P2.1/P2.2.

### P2.5 — Update `ecosystem.config.js` PM2 app paths for moved workers and webhook

- **Goal:** PM2 entries for `bee-worker`, `coder-worker`, and `deploy-webhook` must point at new paths.
- **Files touched:** `ecosystem.config.js` (root).
- **Path rewrites:**
  - `apps/coder-worker/` → `apps/workers/coder-worker/`
  - `apps/private-apps/bee-worker/` → `apps/workers/bee-worker/`
  - `apps/deploy-webhook/` → `apps/webhooks/deploy-webhook/`
- **Dependencies:** P2.1, **Duong prereq D-R3** (scratch host availability for dry run, if applicable).
- **Acceptance:**
  - `rg 'apps/(coder-worker|private-apps|deploy-webhook|discord-relay|contributor-bot)' ecosystem.config.js` returns no hits.
  - PM2 dry-run `pm2 start ecosystem.config.js --only bee-worker --dry-run` on scratch host (or visual review if host unavailable) succeeds.
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P2.1.

### P2.6 — Re-key `release-please-config.json` and `.release-please-manifest.json` for dashboards

- **Goal:** Release-please keys packages by repo-relative path (ADR §2d, Q10). Move the `dashboards` entry to `apps/dashboards` in both the config and the manifest so version memory (`0.1.0`) is preserved.
- **Files touched:** `release-please-config.json`, `.release-please-manifest.json` (both at repo root).
- **Edit details:**
  - In `release-please-config.json`: rename the `packages` map key from `"dashboards"` to `"apps/dashboards"`. Keep all existing properties of the package entry (`tag-name-prefix`, `release-type`, etc.) untouched.
  - In `.release-please-manifest.json`: rename the key from `"dashboards"` to `"apps/dashboards"`. Keep the value `"0.1.0"` untouched.
- **Dependencies:** P2.2 (dashboards must actually live at `apps/dashboards/` before the config claims they do).
- **Acceptance:**
  - `release-please-config.json` has no `"dashboards"` top-level package key; has `"apps/dashboards"` with identical sub-config.
  - `.release-please-manifest.json` is `{ "apps/dashboards": "0.1.0" }` (plus any other pre-existing entries, unchanged).
  - Release-please dry-run (`npx release-please release-pr --dry-run`) recognizes `apps/dashboards` at version `0.1.0`, reports no spurious bump, and does NOT re-initialize the package from `0.0.0`.
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside P2.2.

### P2.7 — Phase 2 verification gate

- **Goal:** Prove every moved package still builds + tests and no hosted surface regressed.
- **Files touched:** none (verification only).
- **Dependencies:** P2.1, P2.2, P2.3, P2.4, P2.5, P2.6.
- **Acceptance:**
  - `turbo run build` green at repo root (covers every moved package).
  - `turbo run test` green for every moved worker / webhook / dashboard package that has a test suite.
  - `ecosystem.config.js` PM2 dry-run succeeds on scratch host (D-R3) for `bee-worker`, `coder-worker`, `deploy-webhook`.
  - Dashboards server (`@strawberry/dashboards-server`) still serves in local dev — spot-check.
  - Release-please dry-run output: `apps/dashboards` at `0.1.0`, no version bump, no re-init from `0.0.0`.
  - PR description captures the verification checklist inline.
- **Blocks:** Phase 3+4 start.

---

## Phase 3 + Phase 4 — Promote views to top-level apps AND wire composite build (SINGLE PR per Q8)

Single PR. Per Duong Q8 these two phases land together for deploy-integrity — neither a half-promoted SPA nor a half-wired composite build is ever live. This is the first PR in the restructure that changes deployable surfaces.

Exit criterion: three promoted apps (`read-tracker` in `myApps/`, `bee` and `portfolio-tracker` in `yourApps/`) own their own workspaces inside `apps/darkstrawberry-apps/`; the legacy `src/views/` + old sibling scaffolds are deleted; `task-list` is fully removed; `apps/darkstrawberry-apps/firebase.json` declares a single hosting entry that serves the composite build; `app.darkstrawberry.com` renders all three promoted apps via the `apps/platform/` registry.

### P3P4.1 — Promote `ReadTracker` to `apps/darkstrawberry-apps/myApps/read-tracker/`

- **Goal:** Consolidate the embedded view at `apps/darkstrawberry-apps/src/views/ReadTracker/` with the sibling scaffold workspace at `apps/darkstrawberry-apps/read-tracker/` (package name `@ds/read-tracker`) into a single top-level app at `apps/darkstrawberry-apps/myApps/read-tracker/`. Use `git mv` for both the views and the scaffold so blame is preserved; merge any overlapping files (e.g. `package.json`, `vite.config.ts`, `index.html`) taking the more complete version from the scaffold (ADR §1d) with views grafted in as `src/`.
- **Files touched:**
  - `git mv apps/darkstrawberry-apps/read-tracker/**` → `apps/darkstrawberry-apps/myApps/read-tracker/**` (scaffold).
  - `git mv apps/darkstrawberry-apps/src/views/ReadTracker/**` → `apps/darkstrawberry-apps/myApps/read-tracker/src/views/ReadTracker/**` (or chosen target inside the promoted workspace; Seraphine/Jayce decides final subtree shape during execution — acceptance only requires the views land inside the promoted workspace and blame is preserved).
  - Merge resolution in the promoted workspace's `package.json` if both sources had one — keep the scaffold's `@ds/read-tracker` identity and union the dependencies.
- **Dependencies:** P2.7 (Phase 2 merged).
- **Acceptance:**
  - `apps/darkstrawberry-apps/myApps/read-tracker/package.json` exists with name `@ds/read-tracker`.
  - `apps/darkstrawberry-apps/read-tracker/` (sibling scaffold) no longer exists.
  - `apps/darkstrawberry-apps/src/views/ReadTracker/` no longer exists.
  - `git log --follow apps/darkstrawberry-apps/myApps/read-tracker/src/<any-view-file>` crosses both original locations.
  - `turbo run build --filter=@ds/read-tracker` succeeds standalone.
- **Blocks:** P3P4.4 (composite build config).

### P3P4.2 — Promote `bee` to `apps/darkstrawberry-apps/yourApps/bee/`

- **Goal:** Consolidate the embedded view at `apps/darkstrawberry-apps/src/views/bee/` with the top-level scaffold at `apps/yourApps/bee/` (package name `@ds/bee`) into `apps/darkstrawberry-apps/yourApps/bee/`. Per ADR §3 Phase 3+4 description, the top-level `apps/yourApps/bee/` scaffold is more complete; views become its source.
- **Files touched:**
  - `git mv apps/yourApps/bee/**` → `apps/darkstrawberry-apps/yourApps/bee/**` (top-level scaffold).
  - `git mv apps/darkstrawberry-apps/src/views/bee/**` → inside `apps/darkstrawberry-apps/yourApps/bee/src/` at a location decided by the executor.
- **Dependencies:** P2.7.
- **Acceptance:**
  - `apps/darkstrawberry-apps/yourApps/bee/package.json` exists with name `@ds/bee`.
  - `apps/yourApps/bee/` no longer exists.
  - `apps/darkstrawberry-apps/src/views/bee/` no longer exists.
  - Blame preserved across both source locations.
  - `turbo run build --filter=@ds/bee` succeeds standalone.
- **Blocks:** P3P4.4.

### P3P4.3 — Promote `portfolio-tracker` to `apps/darkstrawberry-apps/yourApps/portfolio-tracker/`

- **Goal:** Consolidate the embedded view at `apps/darkstrawberry-apps/src/views/PortfolioTracker/` with the sibling scaffold at `apps/darkstrawberry-apps/portfolio-tracker/` (package name `@ds/portfolio-tracker`) into `apps/darkstrawberry-apps/yourApps/portfolio-tracker/`.
- **Files touched:**
  - `git mv apps/darkstrawberry-apps/portfolio-tracker/**` → `apps/darkstrawberry-apps/yourApps/portfolio-tracker/**`.
  - `git mv apps/darkstrawberry-apps/src/views/PortfolioTracker/**` → inside the promoted workspace's `src/`.
- **Dependencies:** P2.7. **Note:** also requires D-R1 (portfolio stack drained) to be freshly re-confirmed just before the PR opens — if any portfolio PR landed between Phase 0 and this Phase 3+4 PR opening, the executor must rebase-free merge (per Rule 11) and re-run verification.
- **Acceptance:**
  - `apps/darkstrawberry-apps/yourApps/portfolio-tracker/package.json` exists with name `@ds/portfolio-tracker`.
  - Sibling scaffold at `apps/darkstrawberry-apps/portfolio-tracker/` no longer exists.
  - Embedded view at `apps/darkstrawberry-apps/src/views/PortfolioTracker/` no longer exists.
  - Blame preserved across both source locations.
  - `turbo run build --filter=@ds/portfolio-tracker` succeeds standalone.
- **Blocks:** P3P4.4.

### P3P4.TL — Delete `task-list` (embedded view + sibling scaffold)

- **Goal:** Per Duong Q2, `task-list` does not survive the restructure. Delete both the embedded view `apps/darkstrawberry-apps/src/views/TaskList/` and the sibling scaffold `apps/darkstrawberry-apps/task-list/`.
- **Files touched:**
  - Delete: `apps/darkstrawberry-apps/src/views/TaskList/` (entire directory).
  - Delete: `apps/darkstrawberry-apps/task-list/` (entire directory).
- **Dependencies:** P1.1 (the subtree must live at the new path first). Lands in the same PR as P3P4.1/2/3 for atomicity.
- **Acceptance:**
  - Neither path exists anywhere under `apps/darkstrawberry-apps/`.
  - Any route or registry reference to `task-list` is removed (see P3P4.5 platform-registry update).
  - Any test file that referenced `TaskList` is deleted or rewritten to target a surviving app.
  - No stale `@ds/task-list` entry in root `package.json` workspaces (the `apps/darkstrawberry-apps/*` glob stops matching it once deleted).
- **Rollback surface:** revert restores the directories — but user intent is explicit removal (Q2).

### P3P4.4 — Top-level Vite config + composite build wiring

- **Goal:** Create a single top-level Vite config at `apps/darkstrawberry-apps/` that produces one `dist/` importing all three promoted sub-apps via the existing `apps/platform/` registry (Q1, single-host model). Replaces the legacy `apps/darkstrawberry-apps/src/` SPA shell's standalone role.
- **Files touched:**
  - `apps/darkstrawberry-apps/vite.config.ts` (may already exist from the pre-rename Vite setup; rewrite or replace with the composite config).
  - `apps/darkstrawberry-apps/package.json` (build scripts adjusted if needed).
  - `apps/darkstrawberry-apps/index.html` (entry point that boots the platform shell).
  - The legacy `apps/darkstrawberry-apps/src/` shell: keep the minimal bootstrap (main.ts, router bootstrap) that wires into `apps/platform/`; retire the old per-view `src/views/*` content (handled by P3P4.1/2/3/TL).
- **Composite-build contract:**
  - One `vite build` produces one `dist/`.
  - The build imports the three promoted apps via dynamic imports mediated by `apps/platform/src/registry/appRegistry.ts` and `apps/platform/src/core/appLoader.ts`.
  - Code-splitting per promoted app is preserved (one chunk per sub-app).
  - Single entry HTML, single router (client-side), paths route to `myApps/read-tracker`, `yourApps/bee`, `yourApps/portfolio-tracker` (actual URL shape decided during execution; acceptance requires the paths resolve).
- **Dependencies:** P3P4.1, P3P4.2, P3P4.3 (the three promoted workspaces must exist). Also depends on `apps/platform/` staying in place (ADR §1e, Q3).
- **Acceptance:**
  - `turbo run build --filter=<root darkstrawberry-apps workspace name>` produces one `dist/` containing assets for all three promoted apps.
  - Locally, `npm run dev` (or equivalent) in `apps/darkstrawberry-apps/` serves all three apps at their assigned paths.
  - `dist/index.html` references the platform shell bootstrap.
  - Bundle analysis shows three distinct code-split chunks for the three sub-apps.
- **Blocks:** P3P4.5, P3P4.7.

### P3P4.5 — Update `apps/platform/` registry to include the three promoted apps

- **Goal:** The `appRegistry.ts` in `apps/platform/src/registry/` must list the three promoted apps with dynamic-import paths pointing at the new promoted workspace locations. Remove any `task-list` registry entry (Q2).
- **Files touched:** `apps/platform/src/registry/appRegistry.ts` (and possibly `firestoreRegistry.ts` if that mirrors the static list).
- **Dependencies:** P3P4.1, P3P4.2, P3P4.3, P3P4.TL.
- **Acceptance:**
  - Registry lists `read-tracker` (myApps/public), `bee` (yourApps/private), `portfolio-tracker` (yourApps/private).
  - No `task-list` entry anywhere in registry code.
  - Dynamic-import paths in the registry resolve to the promoted workspace entry points (via Vite path aliases if used — update aliases in the composite Vite config P3P4.4 to reach `apps/darkstrawberry-apps/{myApps,yourApps}/*`).
  - `appLoader.ts` successfully resolves each registry entry at runtime in the composite-build dev server.
- **Rollback surface:** revert alongside the whole PR.

### P3P4.6 — Confirm `apps/darkstrawberry-apps/firebase.json` stays single-hosting-entry

- **Goal:** Verify (and edit if needed) that `apps/darkstrawberry-apps/firebase.json` has exactly one `hosting` entry — no `targets` array, no multi-site split — pointing at the composite `dist/`. Per Q1.
- **Files touched:** `apps/darkstrawberry-apps/firebase.json`, `apps/darkstrawberry-apps/.firebaserc` (verify no `targets` block).
- **Dependencies:** P3P4.4 (composite build produces the `dist/` this file points at).
- **Acceptance:**
  - `firebase.json` `hosting` key is a single object (not an array of targets).
  - `.firebaserc` has no `targets` block.
  - `firebase deploy --only hosting --dry-run --project myapps-b31ea` (from `apps/darkstrawberry-apps/`) lists exactly one site: `darkstrawberry-apps` (or the currently-configured site ID).
  - `firebase.json` still declares all four surfaces (hosting, functions, firestore, storage) per the deployment-pipeline canonical layout.
- **Rollback surface:** revert alongside the whole PR.

### P3P4.7 — Update preview workflow `cp` source (post-rename Phase-1 workflow already renamed)

- **Goal:** The `preview.yml` step `cp apps/myapps/firebase.json firebase.json` was already rewritten in Phase 1 (P1.3). Verify it still works against the composite build and that the preview channel successfully deploys the composite `dist/`.
- **Files touched:** `.github/workflows/preview.yml` (verification only; no edit expected unless Phase 1 missed a reference).
- **Dependencies:** P3P4.4, P3P4.6.
- **Acceptance:**
  - On this PR, the preview workflow runs green and produces a preview channel keyed by PR number.
  - Visiting the preview URL renders the platform shell; all three promoted apps (`read-tracker`, `bee`, `portfolio-tracker`) load when navigated to.
  - No 404s at router transition to any of the three apps.
  - `task-list` path returns 404 (expected — removed).
- **Rollback surface:** revert alongside the whole PR.

### P3P4.8 — Per-app Playwright E2E smoke specs

- **Goal:** Each promoted app has at least one smoke-level Playwright spec that loads the app in the composite build and asserts the top-level render succeeds. Per ADR §6 Phase 3+4 testing strategy. Reuse existing `apps/darkstrawberry-apps/e2e/` specs as the starting point.
- **Files touched:** `apps/darkstrawberry-apps/e2e/<app>.spec.ts` (three new or updated files — one per promoted app).
- **Dependencies:** P3P4.4, P3P4.5, P3P4.7.
- **Acceptance:**
  - `apps/darkstrawberry-apps/e2e/read-tracker.spec.ts`, `.../bee.spec.ts`, `.../portfolio-tracker.spec.ts` exist.
  - Each spec loads the app via the composite build, asserts the top-level component renders, and asserts no console errors.
  - All three specs pass in CI as part of the `e2e.yml` gate (Rule 15).
  - No spec targets `task-list` (removed).
- **Rollback surface:** revert alongside the whole PR.

### P3P4.9 — Phase 3+4 verification gate (combined, single PR)

- **Goal:** Whole-PR verification before merge. Because Phase 3 + Phase 4 cannot be partially rolled back (Q8), the gate must be strict.
- **Files touched:** none (verification only; record in PR description).
- **Dependencies:** P3P4.1, P3P4.2, P3P4.3, P3P4.TL, P3P4.4, P3P4.5, P3P4.6, P3P4.7, P3P4.8.
- **Acceptance:**
  - `turbo run build --filter=@ds/read-tracker`, `--filter=@ds/bee`, `--filter=@ds/portfolio-tracker` all pass standalone.
  - Composite build at `apps/darkstrawberry-apps/` produces a single `dist/` with three code-split chunks.
  - Playwright E2E green for each promoted app (P3P4.8).
  - Preview channel for this PR serves the composite build; all three app paths resolve; `task-list` path 404s.
  - `firebase deploy --only hosting --dry-run --project myapps-b31ea` from `apps/darkstrawberry-apps/` lists exactly one site.
  - Firestore Security Rules emulator smoke (from the portfolio V0.3 harness, if present) still passes after the functions/rules paths move — **ADR §6 Phase 3+4 spot-check.**
  - QA agent (Rule 16) runs full Playwright flow with video + screenshots; report filed under `assessments/qa-reports/` and linked in PR body (required for UI PRs).
  - Post-deploy smoke (Rule 17) against staging/prod asserts 200 on `/`, `/read-tracker`, `/bee`, `/portfolio-tracker` (or whatever platform router paths resolve to) after the prod deploy.
  - PR description embeds the full verification checklist.
- **Blocks:** Phase 5 start.

**Phase 3+4 rollback surface:** Whole-PR revert restores the composite-SPA state at `apps/darkstrawberry-apps/` (as it stood at HEAD of Phase 2). Firebase Hosting retains prior deploys; revert + redeploy restores the previous site. No partial cherry-pick is permitted — the PR must be reverted whole.

---

## Phase 5 — Cleanup and renames

Single PR. Deletes of now-empty shells, comment/README sweeps, lint-glob guardrail.

Exit criterion: no stray references to `apps/myapps`, `apps/yourApps` (top-level), `apps/private-apps`, `dashboards/` (top-level) anywhere in the tree except inside historical plan files.

### P5.1 — Delete empty `apps/private-apps/` and old top-level `apps/yourApps/`

- **Goal:** Both shells are empty after Phase 2 and Phase 3+4 respectively. Remove.
- **Files touched:**
  - Delete `apps/private-apps/` (if the directory still exists as an empty shell; `git` doesn't track empty dirs, so this may already be gone after Phase 2).
  - Delete `apps/yourApps/` (old top-level; empty after Phase 3+4 because `bee` moved to `apps/darkstrawberry-apps/yourApps/bee/`).
- **Dependencies:** P3P4.9 (Phase 3+4 merged).
- **Acceptance:**
  - Neither directory exists.
  - No workspaces glob in root `package.json` still references either (remove if any lingering entry).
  - Commit `chore:` prefix.
- **Rollback surface:** revert alongside Phase 5 PR.

### P5.2 — Belt-and-suspenders delete of `apps/darkstrawberry-apps/task-list/`

- **Goal:** In case the Phase 3+4 PR missed the sibling-scaffold deletion (ADR §3 Phase 5 explicitly mentions this as a fallback), re-verify and delete.
- **Files touched:** `apps/darkstrawberry-apps/task-list/` (delete if it somehow survived).
- **Dependencies:** P3P4.TL.
- **Acceptance:**
  - `rg 'task-list' apps/darkstrawberry-apps/ --glob '!**/node_modules/**'` returns no hits (or only unrelated occurrences — e.g. the word "task-list" inside a comment unrelated to the removed app).
  - Commit `chore:` prefix.

### P5.3 — Sweep for stragglers: `myapps` (lowercase) + old top-level dashboards references

- **Goal:** Update workflows, scripts, comments, READMEs, agent prompts, docs that still say `myapps`, `yourApps` (top-level), `private-apps`, or `dashboards/` (repo root) to the new paths.
- **Files touched:** whatever `rg` surfaces across the tree. Exclude `plans/**` and pre-2026-04-19 `assessments/**` (historical).
- **Sweep globs to run:**
  - `rg '\bapps/myapps\b' --glob '!plans/**' --glob '!assessments/2026-0[1-3]*/**' --glob '!assessments/2026-04-[0-1]*/**'`
  - `rg '\bapps/yourApps\b' --glob '!plans/**' --glob '!apps/darkstrawberry-apps/**' --glob '!assessments/**'` (the new `apps/darkstrawberry-apps/yourApps/` is the legitimate usage; this sweep should find only the old top-level references)
  - `rg '\bapps/private-apps\b' --glob '!plans/**' --glob '!assessments/**'`
  - `rg '^dashboards/' --glob '*.md' --glob '*.yml' --glob '*.json' --glob '*.js' --glob '*.ts'` — excluding `plans/**`.
- **Dependencies:** P3P4.9.
- **Acceptance:**
  - All four sweep commands return no hits (except inside legitimate new-path contexts — e.g. `apps/darkstrawberry-apps/yourApps/` is fine).
  - Workflows still pass (`actionlint` clean).
  - Commit `chore:` prefix.

### P5.4 — Update `docs/` and `architecture/` references

- **Goal:** Refresh architecture docs to describe the new layout. Out of the restructure's scope to rewrite any ADR that references the old paths (those are immutable history), but `architecture/**` docs that describe the current system must be updated.
- **Files touched:** any `architecture/*.md` or `docs/*.md` file in the `strawberry-app` checkout that references the old layout. Obvious candidates: `architecture/cross-repo-workflow.md`, `architecture/infrastructure.md`, `architecture/key-scripts.md`, any deployment architecture doc.
- **Dependencies:** P3P4.9.
- **Acceptance:**
  - Architecture docs describe `apps/darkstrawberry-apps/{myApps,yourApps}/*`, `apps/workers/*`, `apps/webhooks/*`, `apps/discord/*`, `apps/dashboards/*`, `apps/contributor/*`, `apps/platform/`, `apps/shared/`.
  - No architecture doc still asserts that `apps/myapps` is the current layout.
  - Commit `chore:` prefix.

### P5.5 — Add `apps/darkstrawberry-apps/` child-directory lint guardrail

- **Goal:** Per ADR §5, prevent new directories under `apps/darkstrawberry-apps/` that are not one of `myApps/`, `yourApps/`, `functions/`, `src/`, `e2e/`, `node_modules/`, `dist/`, and a small allowlist of config files. Enforces the camelCase-bucket convention.
- **Files touched:** `.github/workflows/lint-slugs.yml` OR `.github/workflows/validate-scope.yml` (Ornn/executor picks the better home based on what's already in each workflow).
- **Dependencies:** P5.1, P5.2, P5.3, P5.4 (layout must be clean before the lint is turned on, else it would fail immediately).
- **Acceptance:**
  - A failing test case: adding a scratch directory `apps/darkstrawberry-apps/extra/` and opening a PR fails the lint with a clear message.
  - A passing test case: adding `apps/darkstrawberry-apps/myApps/new-app/` passes the lint.
  - The lint is declared a required status check if appropriate (coordinate with Ornn's branch-protection policy — may defer to a follow-up if branch-protection edits are out of scope for this PR).
  - Commit `chore:` prefix.

### P5.6 — Phase 5 verification gate

- **Goal:** Clean-sweep confirmation.
- **Files touched:** none (verification only).
- **Dependencies:** P5.1, P5.2, P5.3, P5.4, P5.5.
- **Acceptance:**
  - `git status` clean in the PR branch worktree.
  - No orphaned workflow files (`rg 'myapps|private-apps' .github/workflows/` returns no hits except inside renamed filenames that themselves say `darkstrawberry-apps`).
  - Sweep commands from P5.3 return no hits.
  - `turbo run build` green.
  - `validate-scope.yml` (and any new lint added in P5.5) passes against the PR branch.
  - PR description captures the verification inline.

---

## Out of scope (explicitly not tasked in this plan)

Per ADR §1 / §4 / §7, these are NOT to be implemented in this restructure:

- Promotion of `apps/platform/` to a `darkstrawberry-apps/` sub-app — deferred until it grows a `package.json` + Vite config (ADR §1e, Q3).
- Folding `apps/shared/` anywhere — stays at `apps/shared/` (Q4).
- Creating a repo-root `tsconfig.base.json` — deferred to a separate plan (ADR §2d, Q7).
- Enrolling any new package in release-please beyond the existing `dashboards → apps/dashboards` re-key (Q10).
- Firebase multi-site split, per-app subdomains, DNS changes (Q1).
- Rebasing the portfolio PR stack onto the new layout (ADR §2a Option 1 rejected).
- Rewriting historical plan files (`plans/**`) to use new paths.
- PM2 host provisioning beyond dry-run verification (D-R3).

If an executor finds themselves about to do any of the above, stop and ping Evelynn.

---

## Task count by phase

- **Phase 0:** 2 tasks (P0.1 verification, P0.2 workspaces cleanup).
- **Phase 1:** 7 tasks (P1.1 wholesale rename, P1.2 workspaces, P1.3 workflows, P1.4 PM2, P1.5 release-please sanity, P1.6 residual sweep, P1.7 verification).
- **Phase 2:** 7 tasks (P2.1 worker/webhook/discord/contributor moves, P2.2 dashboards moves + empty-shell deletions, P2.3 workspaces, P2.4 workflows, P2.5 PM2, P2.6 release-please re-key, P2.7 verification).
- **Phase 3+4 (single PR per Q8):** 9 tasks (P3P4.1 promote read-tracker, P3P4.2 promote bee, P3P4.3 promote portfolio-tracker, P3P4.TL delete task-list, P3P4.4 composite Vite config, P3P4.5 platform registry update, P3P4.6 firebase.json sanity, P3P4.7 preview workflow, P3P4.8 E2E specs, P3P4.9 combined verification).
- **Phase 5:** 6 tasks (P5.1 empty shell deletes, P5.2 task-list backup delete, P5.3 straggler sweep, P5.4 docs, P5.5 lint guardrail, P5.6 verification).

**Total: 31 tasks across 5 PRs (Phase 3+4 is one PR, not two — Q8).** 3 Duong prereqs (D-R1, D-R2, D-R3), remainder agent tasks.

---

## Dependency summary — critical path

**Critical path:**
D-R1 → P0.1 → P0.2 → **P1.1** → P1.2 → P1.3 → P1.7 → **P2.1** → P2.2 → P2.3 → P2.6 → P2.7 → **P3P4.1–3 ∥** → P3P4.4 → P3P4.5 → P3P4.7 → P3P4.8 → **P3P4.9** → P5.1/2/3/4 → P5.5 → P5.6.

**Parallel windows:**

- **Inside Phase 1:** P1.4 (PM2), P1.5 (release-please sanity), P1.6 (sweep) all run in parallel with P1.2/P1.3 once P1.1 is committed. P1.7 gates them.
- **Inside Phase 2:** P2.1 and P2.2 are bundled into one PR but may be separate commits. P2.4 (workflows) and P2.5 (PM2) and P2.6 (release-please) run in parallel with each other once P2.1/P2.2 are committed. P2.7 gates them.
- **Inside Phase 3+4:** P3P4.1, P3P4.2, P3P4.3 can be done in parallel (three independent promotions) — but all feed the same PR. P3P4.TL (task-list delete) runs in parallel. Once all four are in, P3P4.4 (composite build) and P3P4.5 (platform registry) serialize. Then P3P4.6, P3P4.7, P3P4.8 run in parallel. P3P4.9 gates everything.
- **Inside Phase 5:** P5.1, P5.2, P5.3, P5.4 run in parallel. P5.5 waits for the layout to be clean. P5.6 gates.

**Hard serial points:**

1. Phase 1 PR merged **before** Phase 2 PR opens. (ADR §3: each phase is gated by the previous phase landing.)
2. Phase 2 PR merged **before** Phase 3+4 PR opens.
3. Phase 3+4 PR merged **before** Phase 5 PR opens.
4. **No rebase across phases** (Rule 11). If main advances during a phase PR's life, merge main into the phase branch — never rebase.

---

## Ambiguities resolved by Kayn (flagged for executor awareness)

1. **"Non-app services" move order inside Phase 2.** ADR §3 lists the six moves as a flat set. Kayn bundles them into P2.1 (workers + webhook + discord + contributor) + P2.2 (dashboards) to give the dashboards-specific actions (empty-shell deletes, release-please re-key in P2.6) a clean boundary. Executor may combine into one commit or two within the single Phase 2 PR.
2. **Promoted-app workspace subtree shape.** ADR §1d and §3 name the destinations (`apps/darkstrawberry-apps/myApps/read-tracker/` etc.) but do not prescribe how to merge the embedded view content with the sibling scaffold when both exist. Kayn's acceptance criterion is "the top-level scaffold wins for `package.json`, views become `src/`" — Seraphine/Jayce refines the subtree shape during execution.
3. **Commit-prefix rule on mechanical moves under `apps/**`.** Rule 5 on the `strawberry-app` repo requires `feat:`/`fix:`/`perf:`/`refactor:`/`chore:` for `apps/**` diffs. Kayn lands every move commit as `chore:` — justification: the move itself is not a functional change, and release-please only tracks `apps/dashboards` (Q10) which gets re-keyed, not re-released. If the pre-push hook flags any of these as under-declared, the executor escalates to Evelynn — **do not bypass the hook.**
4. **`apps/yourApps/bee/` top-level scaffold vs embedded view merge resolution.** ADR §3 Phase 3+4 says "the top-level scaffold is more complete; views become its source." Kayn's P3P4.2 acceptance makes this load-bearing — the top-level scaffold's `package.json`, `vite.config.ts`, `index.html` win; the embedded `src/views/bee/` is grafted into the scaffold's `src/` tree at a location decided during execution.
5. **Pre-Phase-1 workspaces cleanup.** ADR §3 Phase 0 says "Root `package.json` `workspaces` drops stale `apps/portal` entry." Kayn promoted this to a standalone task (P0.2) so the Phase 1 diff is minimal and the stale-entry removal has a clean rollback boundary.

## Gaps requiring Duong input before execution starts

1. **D-R1 (portfolio stack drain).** The ADR was written with the stack still in flight. Evelynn must re-confirm at Phase 1 kickoff that every listed PR has merged and no `feature/portfolio-v0-*` branches remain. If a PR is still open, Phase 1 waits.
2. **D-R3 (PM2 scratch host).** P2.5 acceptance wants a PM2 dry-run on a scratch host. If none is available, executor falls back to visual review — Duong confirms the fallback at Phase 2 kickoff.
3. **QA agent availability for P3P4.9.** Rule 16 requires a QA agent to run full Playwright + Figma diff on UI PRs. The Phase 3+4 PR qualifies. Evelynn / Duong must confirm QA capacity (Caitlyn or equivalent) before the PR opens — or the PR body linter will reject.
4. **`apps/platform/` promotion deferral stability.** ADR §1e, Q3 defers the `apps/platform/` promotion to a future plan. If Duong's view on this changes between now and Phase 3+4 (e.g. platform grows a `package.json` mid-flight), the composite-build wiring in P3P4.4 may need rework. Kayn's plan assumes platform stays at its current non-workspace state; if that changes, flag to Evelynn before P3P4.4.

No other gaps. Ready for Evelynn to assign executors and kick off.
