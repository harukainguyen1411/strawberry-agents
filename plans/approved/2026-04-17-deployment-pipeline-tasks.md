---
status: approved
owner: kayn
date: 2026-04-17
title: Deployment Pipeline — Task Breakdown (Phases 1 & 2)
parent_adr: plans/approved/2026-04-17-deployment-pipeline.md
---

# Deployment Pipeline — Task Breakdown

Executable task list for the approved deployment-pipeline ADR (`plans/approved/2026-04-17-deployment-pipeline.md`). Two numbered phases match ADR §9. Each task has an ID, one-sentence goal, executor, files, dependencies, and acceptance criteria.

**Duong-resolved decisions applied** (all 18 open questions accepted per Azir's recommendations): Vitest; ciphertext-in-git under `secrets/env/<project>.env.age`; `main`-only deploy with `--allow-branch` escape; personal CLI auth locally / SA in CI; emulator-backed integration only; reconcile existing scripts up-front; release-please bot permitted on `main` under branch protection; first Bee version `0.1.0`; manual release-PR merge; new staging project `myapps-b31ea-staging`; staging on tag only; 4-check smoke; Duong-only prod approver; independent per-package versioning; SA IAM = firebase.admin + cloudfunctions.admin + iam.serviceAccountUser (self), storage.admin reactive; `auto_revert` default true.

**Executor legend.** Jayce = new files / greenfield. Viktor = refactor / reconcile existing. Vi = test authoring + e2e verification. Seraphine = frontend (n/a this plan). Ornn = DevOps / repo-meta config (commit hooks, branch protection, CLAUDE.md edits, GH Actions YAML infra that is meta not app-logic). Where a task could be Jayce or Ornn, the rule is: YAML workflow files with non-trivial orchestration shape → Jayce (they're new greenfield artifacts); repo-meta infra like hooks, branch protection, rule rewrites → Ornn.

Note: Seraphine (frontend) has no tasks in this plan — flagged explicitly so Evelynn doesn't expect a handoff there.

---

## Duong-blocking prerequisites (summary)

These must be done by Duong before the dependent agent tasks can proceed. Listed here for scheduling visibility; also embedded as numbered tasks below.

| Ref | Blocker | Blocks |
|-----|---------|--------|
| D1 | Fix `origin` remote (account-switch 404). | All of Phase 2 that pushes/pulls from GitHub. |
| D2 | Create staging Firebase project `myapps-b31ea-staging`, confirm final ID. | P2.6, P2.7, P2.10, P2.13. |
| D3 | Create prod + staging service accounts in GCP console, grant the three IAM roles, download key JSONs. | P2.4 (GH Actions secrets upload), P2.10, P2.11. |
| D4 | Provide the four secret values (`GITHUB_TOKEN`, `BEE_GITHUB_REPO`, `BEE_SISTER_UIDS`, `DISCORD_WEBHOOK_URL`) into the ciphertext flow for P1.3. | P1.3, and therefore any local deploy of `myapps-b31ea` Functions. |
| D5 | Sign off on the amended CLAUDE.md Rule 5 wording in P2.2 before it lands. | P2.2 merge, and therefore any `feat:`/`fix:` commit in `apps/**`. |

---

## Phase 1 — Local deploy pipeline (no CI yet)

Exit criterion: `scripts/deploy.sh myapps-b31ea` runs locally, test gates fire, Functions deploy succeeds, audit-log record written.

### P1.0 — Audit existing `scripts/deploy.sh` + `scripts/composite-deploy.sh`

- **Executor:** Jayce
- **Goal:** Inventory current behaviour of both scripts, document which callers reference them, and produce a reconciliation plan (rename, absorb, or retire) before any new script overwrites them.
- **Files touched (read-only):** `scripts/deploy.sh`, `scripts/composite-deploy.sh`, any caller sites (grep the repo).
- **Files created:** `architecture/deploy-script-audit.md` — short audit note listing: current behaviour of each script, all callers, proposed disposition (rename / delete / keep / absorb), and the migration path.
- **Dependencies:** none. First task in Phase 1.
- **Acceptance:**
  - `architecture/deploy-script-audit.md` exists and names every caller of each script across the repo (agents, plans, docs, other scripts).
  - Proposed rename for the existing `scripts/deploy.sh` (which is a VPS Discord-relay deploy, **not** a Firebase deploy) preserves its behaviour — likely `scripts/deploy-discord-relay-vps.sh` or similar.
  - `scripts/composite-deploy.sh` disposition is stated explicitly: delete (no Vite surfaces in Phase 1/2) vs carry forward as dormant.
  - No code changes in this task — it is an audit only. Execution of the rename/delete happens in P1.1.

### P1.1 — Reconcile and rename existing scripts per audit

- **Executor:** Viktor
- **Goal:** Execute the disposition decided in P1.0 — rename/retire the old `scripts/deploy.sh`, update all callers, land a clean namespace before P1.2 introduces the new dispatcher.
- **Files touched:** `scripts/deploy.sh` (move), `scripts/composite-deploy.sh` (delete or leave), any caller files the audit identified.
- **Dependencies:** P1.0.
- **Acceptance:**
  - The old `scripts/deploy.sh` is renamed (or retained with a temporary wrapper-warning) per P1.0's disposition.
  - All caller references updated.
  - `scripts/deploy.sh` path is free for the new dispatcher (P1.2).
  - Commit message is `chore:` prefix.

### P1.2 — Build `scripts/deploy/_lib.sh` shared helpers

- **Executor:** Jayce
- **Goal:** Author the shared library that every surface script sources — env decrypt, audit-log append, preconditions (clean tree, branch check, `--only` enforcement), CLI auth detection.
- **Files created:** `scripts/deploy/_lib.sh`.
- **Files touched:** none else yet.
- **Dependencies:** P1.1.
- **Acceptance:**
  - `_lib.sh` exposes functions: `dl_require_clean_tree`, `dl_require_main_or_branch_flag`, `dl_decrypt_env <project>`, `dl_audit_log_start`, `dl_audit_log_finish`, `dl_require_firebase_only_flag`, `dl_detect_firebase_auth` (SA-file vs personal-CLI).
  - Static grep check: script fails if a caller invokes bare `firebase deploy` without `--only` (ADR §1a.6).
  - Env-decrypt path uses `tools/decrypt.sh` exclusively (Rule 6); never runs raw `age -d`.
  - POSIX bash, no zsh-isms, works on Git Bash on Windows (Rule 10).
  - `shellcheck` passes.

### P1.3 — Bootstrap `secrets/env/myapps-b31ea.env.age`

- **Executor:** Jayce (scripting), Duong (provides values via D4)
- **Goal:** Create the encrypted dotenv for the prod Firebase project using Duong's four known values (`GITHUB_TOKEN`, `BEE_GITHUB_REPO=Duongntd/strawberry`, `BEE_SISTER_UIDS=0DJzc86i5MP74jAwwT4YjvbcAub2`, `DISCORD_WEBHOOK_URL`), unblocking Functions deploy.
- **Files created:** `secrets/env/myapps-b31ea.env.age` (ciphertext, committed), `secrets/env/myapps-b31ea.env.example` (template, committed, no values).
- **Dependencies:** P1.2 (uses `_lib.sh`'s decrypt wiring indirectly); **Duong prereq D4** must supply the values into the ciphertext flow.
- **Acceptance:**
  - Ciphertext committed; plaintext never committed (pre-commit hook confirms).
  - `.example` file documents all four keys with empty values.
  - `tools/decrypt.sh secrets/env/myapps-b31ea.env.age` returns the four expected keys (no values printed to terminal during test — use a mode that exits 0 on success without logging plaintext).
- **Duong-blocked:** yes — waiting on D4.

### P1.4 — First failing Vitest test against an existing Function (TDD proof-of-life)

- **Executor:** Vi
- **Goal:** Land one deliberately-failing Vitest test against an existing `apps/functions` export, verify it fails, then make it pass. Proves the test harness is wired end-to-end before the rest of Phase 1 builds on it.
- **Files created:** `apps/functions/vitest.config.ts` (or equivalent), `apps/functions/src/__tests__/smoke.test.ts` (or chosen location), `apps/functions/package.json` changes if needed to add Vitest.
- **Dependencies:** none (can run parallel to P1.0–P1.2; but sequence it after P1.1 if `apps/functions` build is in flux).
- **Acceptance:**
  - `pnpm --filter functions test` runs Vitest and exits non-zero initially (failing test committed), then exits zero after the fix commit.
  - Test asserts real behaviour of an existing function export, not a tautology.
  - Two commits — both `chore:` (the failing test and the fix are in `apps/functions/__tests__/`, which is non-production test code; see Phase 2 scope validation for when `feat:` would apply).

### P1.5 — Build `scripts/test-functions.sh`

- **Executor:** Jayce
- **Goal:** Portable entrypoint that runs Vitest unit + emulator-backed integration tests for `apps/functions`; exits non-zero on any failure; same command local and (future) CI.
- **Files created:** `scripts/test-functions.sh`.
- **Dependencies:** P1.4 (needs a Vitest baseline to invoke).
- **Acceptance:**
  - `bash scripts/test-functions.sh` runs `pnpm --filter functions test` (or equivalent) with emulator boot + teardown when integration suite is present.
  - No `--force`, no skip flags.
  - POSIX bash, `shellcheck` clean.
  - Emulator-backed integration only (no `firebase-functions-test` offline mode).

### P1.6 — Build `scripts/test-storage-rules.sh`

- **Executor:** Jayce
- **Goal:** Portable entrypoint that boots the Firebase emulator, runs `@firebase/rules-unit-testing`, tears down.
- **Files created:** `scripts/test-storage-rules.sh`, any fixtures needed.
- **Dependencies:** P1.2 (for `_lib.sh` helpers if shared) — otherwise independent.
- **Acceptance:**
  - `bash scripts/test-storage-rules.sh` exits zero against the current storage rules.
  - Writes and cleans up emulator state; never touches the live `myapps-b31ea` project.
  - POSIX bash, `shellcheck` clean.

### P1.7 — Build `scripts/test-all.sh`

- **Executor:** Jayce
- **Goal:** Single invocation that runs every `scripts/test-*.sh` entrypoint and aggregates exit codes.
- **Files created:** `scripts/test-all.sh`.
- **Dependencies:** P1.5, P1.6.
- **Acceptance:**
  - Runs both `test-functions.sh` and `test-storage-rules.sh`, exits non-zero if either fails.
  - Prints a short summary at the end (which suites passed, timings).
  - POSIX bash.

### P1.8 — Build `scripts/deploy/functions.sh`

- **Executor:** Jayce
- **Goal:** Surface script for Cloud Functions — runs test gate, decrypts env, invokes `firebase deploy --only functions --project <id>`, writes audit event.
- **Files created:** `scripts/deploy/functions.sh`.
- **Dependencies:** P1.2, P1.3, P1.5.
- **Acceptance:**
  - Refuses to deploy if `scripts/test-functions.sh` fails.
  - Uses `_lib.sh` helpers throughout (no duplicated logic).
  - `firebase deploy` invocation includes both `--only functions` and `--project <id>`.
  - On success, appends one `deploy.finished` record with `status: success` to `logs/deploy-audit.jsonl` per ADR §8 schema.
  - On failure, appends `status: failure` with the error.

### P1.9 — Build `scripts/deploy/storage-rules.sh`

- **Executor:** Jayce
- **Goal:** Surface script for Firebase Storage rules — test gate, `firebase deploy --only storage --project <id>`, audit.
- **Files created:** `scripts/deploy/storage-rules.sh`.
- **Dependencies:** P1.2, P1.3, P1.6.
- **Acceptance:** symmetric to P1.8 but for storage rules surface.

### P1.10 — Build `scripts/deploy/project.sh`

- **Executor:** Jayce
- **Goal:** Per-project orchestrator that deploys all surfaces for a given Firebase project, in a defined order.
- **Files created:** `scripts/deploy/project.sh`.
- **Dependencies:** P1.8, P1.9.
- **Acceptance:**
  - `bash scripts/deploy/project.sh myapps-b31ea` invokes functions then storage-rules in that order.
  - Bails on first surface failure; does not continue to subsequent surfaces.
  - Each surface writes its own audit record; no duplicate records from the orchestrator.

### P1.11 — Build new top-level `scripts/deploy.sh` dispatcher

- **Executor:** Jayce
- **Goal:** Canonical entrypoint `scripts/deploy.sh <project> [<surface>] [--ref <git-ref>] [--skip-staging] [--allow-branch] [--allow-dirty] [--yes]` per ADR §4.
- **Files created:** `scripts/deploy.sh` (new file at the path freed by P1.1).
- **Dependencies:** P1.1 (path free), P1.10.
- **Acceptance:**
  - With no `<surface>` arg, delegates to `scripts/deploy/project.sh`.
  - With `<surface>` arg, delegates to `scripts/deploy/<surface>.sh`.
  - `--ref <tag>` checks out that ref in a worktree via `scripts/safe-checkout.sh` (Rule 3 — never raw `git checkout`).
  - `--allow-branch`, `--allow-dirty`, `--skip-staging` all audit-logged when set.
  - POSIX bash.

### P1.12 — End-to-end Phase 1 dry run

- **Executor:** Vi
- **Goal:** Verify the full local pipeline works: `scripts/deploy.sh myapps-b31ea` runs tests, deploys Functions to the real prod project, audit log shows one success record.
- **Files touched:** none (verification only); may create a short checklist in `architecture/deploy-script-audit.md` or a dedicated verification note if useful.
- **Dependencies:** P1.3, P1.11 (and transitively all of Phase 1).
- **Acceptance:**
  - Functions deploy to `myapps-b31ea` succeeds from Duong's laptop.
  - `logs/deploy-audit.jsonl` has a record with `project: "myapps-b31ea"`, `surface: "functions"`, `status: "success"`, non-null `git_sha`, `version: null` (no tag yet).
  - `/version` endpoint (if P1.x added one) returns correct sha; if not yet added, this check deferred to Phase 2.
  - Tests pass both before and after deploy with no changes.

### P1.13 — Update `architecture/key-scripts.md`

- **Executor:** Viktor
- **Goal:** Refresh the script-inventory doc with the new `scripts/deploy/` tree and the rename of the old `deploy.sh`.
- **Files touched:** `architecture/key-scripts.md`.
- **Dependencies:** P1.1, P1.11.
- **Acceptance:**
  - Doc lists every new script with a one-line purpose.
  - Old `scripts/deploy.sh` (if renamed) is listed under its new name.
  - Commit is `chore:`.

---

## Phase 2 — CI + release-please + staging + auto-revert

Exit criterion: a `feat:` commit in `apps/functions/` → release PR → merge → tag → staging deploy + smoke → Duong approval → prod deploy + smoke → Discord notification. A forced bad prod deploy triggers auto-revert to the previous tag.

### P2.0a — **Duong prereq:** fix `origin` remote

- **Executor:** Duong (human).
- **Goal:** Unbreak the GitHub remote that currently 404s due to account switch.
- **Dependencies:** none.
- **Acceptance:** `git fetch origin` and `git push origin main` both succeed from Duong's laptop.
- **Blocks:** all Phase 2 GitHub-Actions tasks.

### P2.0b — **Duong prereq:** create staging Firebase project

- **Executor:** Duong (human).
- **Goal:** Create `myapps-b31ea-staging` in the Firebase console with the Blaze plan matching prod; confirm final project ID to Kayn/Evelynn.
- **Dependencies:** none.
- **Acceptance:** Project exists; Duong confirms ID (may end up as `myapps-b31ea-staging` or similar if that ID is taken).
- **Blocks:** P2.6, P2.10 staging wiring.

### P2.0c — **Duong prereq:** create service accounts in GCP console

- **Executor:** Duong (human).
- **Goal:** For each of prod + staging: create a deploy service account, grant `roles/firebase.admin` + `roles/cloudfunctions.admin` + `roles/iam.serviceAccountUser` (on itself), download the key JSON, base64-encode, hand off to the age-encrypted store (or directly paste into GH Actions secret). Also upload the repo-level `AGE_KEY` secret.
- **Dependencies:** P2.0b (staging project must exist).
- **Acceptance:**
  - GH Actions secrets exist: `FIREBASE_SA_KEY_myapps-b31ea`, `FIREBASE_SA_KEY_<staging-id>`, `AGE_KEY`.
  - `roles/storage.admin` deferred — add reactively only if a deploy fails asking for it.
  - Keys never pasted into chat, tickets, or committed files.
- **Blocks:** P2.10, P2.11.

### P2.1 — Amend CLAUDE.md Rule 5

- **Executor:** Ornn
- **Goal:** Rewrite the allowed-commit-prefix rule to describe the two-class convention: `chore:` / `ops:` for non-app-code; `feat:` / `fix:` / `perf:` / `refactor:` allowed ONLY when the diff touches `apps/**`; `feat!:` or `BREAKING CHANGE:` for majors.
- **Files touched:** `CLAUDE.md` (root).
- **Dependencies:** Duong prereq D5 (sign-off on wording).
- **Acceptance:**
  - Rule 5 wording describes both prefix classes, the `apps/**` gating rule, and the mixed-diff allowance from ADR §6.
  - Commit is `chore:` prefix (ironic but correct — meta edit).
  - No downstream task unblocked until this merges on `main`.
- **Blocks:** every Phase-2 task that would author a `feat:`/`fix:` commit (realistically, P2.14 e2e test).
- **Duong-blocked:** yes — waiting on D5.

### P2.2 — Update pre-push / pre-commit hook to enforce commit-scope rule

- **Executor:** Ornn
- **Goal:** Implement the scope-validation hook per ADR §6: reject `apps/**` diffs with `chore:`/`ops:` (under-declared); reject non-`apps/**` diffs with `feat:`/`fix:`/`perf:`/`refactor:` (over-declared); allow mixed diffs with release-type prefixes.
- **Files touched:** `scripts/pre-commit-*.sh` (add new file or extend existing), pre-push hook installer if one exists, `.git/hooks/` wiring via existing install flow.
- **Dependencies:** P2.1 (rule must exist before the hook enforces it).
- **Acceptance:**
  - Commits to `apps/functions/src/**` with `chore:` prefix are rejected with a clear message.
  - Commits to `plans/**` with `feat:` prefix are rejected similarly.
  - Mixed diff (touches both `apps/**` and `plans/**`) with `feat:` prefix is allowed.
  - Hook is POSIX bash, runs on Git Bash on Windows.
  - Existing test-plan hook infra (if any) is updated or a unit-test-style fixture is added.

### P2.3 — `release-please-config.json` + `.release-please-manifest.json`

- **Executor:** Jayce
- **Goal:** Configure release-please in manifest mode with `bee` as the first package pointing at `apps/functions`; tag format `bee-v1.2.3`; initial version `0.1.0`.
- **Files created:** `release-please-config.json`, `.release-please-manifest.json` (both at repo root).
- **Dependencies:** P2.1 (commit-convention aligned).
- **Acceptance:**
  - Config has one package: `apps/functions` → `bee`, `release-type: node`, `tag-separator: '-'`, `include-v-in-tag: true`.
  - Manifest has `apps/functions: "0.1.0"`.
  - No `linked-versions`, no shared-package lockstep.
  - No changelog customization.
  - No pre-release channels.

### P2.4 — `.github/workflows/release-please.yml`

- **Executor:** Jayce
- **Goal:** Workflow that runs `googleapis/release-please-action@v4` on push to `main`.
- **Files created:** `.github/workflows/release-please.yml`.
- **Dependencies:** P2.3, Duong prereq D1.
- **Acceptance:**
  - Triggers on push to `main`.
  - Uses manifest-mode config.
  - Commits release PRs under the `github-actions[bot]` or dedicated release-please identity that the branch-protection rule (P2.9) will exempt.

### P2.5 — `.github/workflows/test.yml`

- **Executor:** Jayce
- **Goal:** PR gate — runs `scripts/test-all.sh` on every PR to `main`.
- **Files created:** `.github/workflows/test.yml`.
- **Dependencies:** P1.7 (scripts exist), Duong prereq D1.
- **Acceptance:**
  - Triggers on `pull_request` targeting `main`.
  - Single job runs `bash scripts/test-all.sh`.
  - Uses `AGE_KEY` secret only if tests require decrypted env (they shouldn't in Phase 2; flag if they do).
  - Declared as required status check (enforcement in P2.9).

### P2.6 — Bootstrap `secrets/env/<staging-id>.env.age`

- **Executor:** Jayce
- **Goal:** Create the encrypted dotenv for the staging Firebase project. Values are the staging-equivalents of the four prod values — likely a staging-only Discord webhook URL and a staging `BEE_SISTER_UIDS` (or same UIDs if Duong wants shared test identities). Duong provides the values.
- **Files created:** `secrets/env/<staging-id>.env.age`, `secrets/env/<staging-id>.env.example`.
- **Dependencies:** P2.0b (staging project exists), P1.3 (template/flow proven).
- **Acceptance:** symmetric to P1.3 for the staging project.
- **Duong-blocked:** yes — waiting on D2 and on Duong supplying staging values.

### P2.7 — Build `scripts/deploy/smoke.sh`

- **Executor:** Jayce
- **Goal:** Post-deploy smoke test with four checks: `/version` body matches deployed `BEE_VERSION`; healthz returns 200; unauthenticated public read returns 200; auth-gated endpoint returns 401/403 without token.
- **Files created:** `scripts/deploy/smoke.sh`, a small config file (YAML or JSON, Jayce picks) listing per-surface assertion URLs, e.g. `scripts/deploy/smoke.config.json` or `.yaml`.
- **Dependencies:** P2.10 requires it; also requires a `/version` endpoint to exist (see P2.7a).
- **Acceptance:**
  - All four checks implemented and each returns a clear pass/fail on exit.
  - Config file is extensible — adding a fifth URL/assertion does not require editing `smoke.sh` itself.
  - POSIX bash, uses `curl` with explicit timeouts (no hangs).
  - Emits `smoke_results` payload consumable by the audit-log event.

### P2.7a — Add `/version` HTTP endpoint to Bee

- **Executor:** Jayce
- **Goal:** Implement a `/version` HTTPS function that returns `{ version, sha, builtAt }` reading from injected env vars `BEE_VERSION`, `BEE_GIT_SHA`, `BEE_BUILT_AT`.
- **Files touched:** `apps/functions/src/` (new file or extension of existing index), tests in `apps/functions/src/__tests__/`.
- **Dependencies:** P2.1 (this commit touches `apps/**` so needs the amended Rule 5 to allow a `feat:` prefix).
- **Acceptance:**
  - Endpoint deployed and returns the three fields.
  - Unit test covers the shape; integration test (emulator) covers a live invocation.
  - Commit is `feat:` (first real `feat:` commit — validates the scope-hook from P2.2).

### P2.8 — Build `scripts/deploy/revert.sh`

- **Executor:** Jayce
- **Goal:** Auto-revert per ADR §7a — look up previous successful prod tag, redeploy it, open issue, post Discord alert, cascade-guard to stop after one hop.
- **Files created:** `scripts/deploy/revert.sh`.
- **Dependencies:** P1.11 (dispatcher exists for the redeploy), P2.7 (to know what smoke failure looks like).
- **Acceptance:**
  - Reads `logs/deploy-audit.jsonl` for the most recent prior `status: success` record on the target project + surface; falls back to GitHub Releases API.
  - If no prior successful tag exists: exits non-zero, opens an issue, pages Duong via Discord, does NOT attempt a blind revert.
  - Invokes `scripts/deploy.sh <prod-project> <surface> --ref <prev-tag> --yes`.
  - Writes two audit records (the failed forward deploy AND the revert deploy, each with its own `revert_of` field).
  - Cascade-guard: if the revert's own smoke test fails, stops; does NOT try a second revert.
  - Config toggle read from a config file (Jayce picks format), default `auto_revert: true`.

### P2.9 — `.github/workflows/release.yml`

- **Executor:** Jayce
- **Goal:** Tag-triggered workflow — staging-first, GitHub Environment approval gate on `production`, prod deploy, post-deploy smoke, auto-revert on failure per ADR §7.
- **Files created:** `.github/workflows/release.yml`.
- **Dependencies:** P2.3, P2.6, P2.7, P2.8, Duong prereqs D1/D2/D3.
- **Acceptance:**
  - Triggered on tag push matching `bee-v*` (extensible to `*-v*` for future packages).
  - Two jobs: `deploy-staging` (no reviewer) then `deploy-production` (`environment: production`, required reviewer = Duong only per P2.12).
  - Each job checks out the tag, invokes `scripts/deploy.sh <project> --ref <tag> --yes`, then `scripts/deploy/smoke.sh <project>`.
  - On prod smoke failure, invokes `scripts/deploy/revert.sh`.
  - Writes `GOOGLE_APPLICATION_CREDENTIALS` from the base64 SA secret to a temp file via `trap … cleanup` on job exit.
  - No continuous staging on `main` push — tag-trigger only.

### P2.10 — `.github/workflows/deploy.yml` (hotfix / rerun)

- **Executor:** Jayce
- **Goal:** `workflow_dispatch`-only workflow for hotfix and rerun paths.
- **Files created:** `.github/workflows/deploy.yml`.
- **Dependencies:** P1.11, Duong prereqs D1/D3.
- **Acceptance:**
  - Inputs: `project` (required), `ref` (optional, default `main`), `skip_staging` (optional boolean, default false).
  - Invokes `scripts/deploy.sh <project> --ref <ref> [--skip-staging] --yes`.
  - When `skip_staging: true`, audit record emits `skipped_staging: true` and Discord alert flags it.
  - No `push` trigger — dispatch only (no autonomous prod deploys).

### P2.11 — Configure GitHub Environments `staging` and `production`

- **Executor:** Ornn
- **Goal:** Create the two environments in repo settings; `staging` has no reviewers, `production` has required reviewer = Duong. Scope the SA-key secrets to the right environments.
- **Files touched:** no code; uses `gh api` to configure, documented in `architecture/` or a commit message.
- **Dependencies:** Duong prereqs D1/D3.
- **Acceptance:**
  - `gh api repos/:owner/:repo/environments/production` shows Duong as required reviewer.
  - `gh api repos/:owner/:repo/environments/staging` shows no reviewers.
  - `FIREBASE_SA_KEY_myapps-b31ea` scoped to `production`; staging SA key scoped to `staging`.

### P2.12 — Branch protection on `main`

- **Executor:** Ornn (with Camille-style advice baked into the task — check `architecture/pr-rules.md` for any existing policy before overriding).
- **Goal:** Enable required status check on `test.yml`, require PR with ≥1 review (self-review by Duong acceptable), disable linear-history / allow merge commits (Rule 11 — never rebase), restrict direct pushes to release-please bot identity + Duong-as-admin.
- **Files touched:** no code; uses `gh api`. Existing helper `scripts/setup-branch-protection.sh` may be updated.
- **Dependencies:** P2.5, Duong prereq D1.
- **Acceptance:**
  - `gh api repos/:owner/:repo/branches/main/protection` shows `test.yml` as a required status check.
  - Direct pushes fail for everyone except release-please bot and Duong.
  - Linear history is NOT required (so merge commits work).
  - PR with non-green `test.yml` cannot be merged.
  - If `scripts/setup-branch-protection.sh` exists, it's updated to reflect this policy — run `scripts/setup-branch-protection.sh` as part of verification.

### P2.13 — Wire staging project into `_lib.sh` project detection

- **Executor:** Viktor
- **Goal:** Update `scripts/deploy/_lib.sh` (and anything else that enumerates projects) so the staging project ID is a known, first-class target — env file path resolves correctly, audit records have correct project field, smoke config has staging URLs.
- **Files touched:** `scripts/deploy/_lib.sh`, `scripts/deploy/smoke.config.*` (add staging URL block).
- **Dependencies:** P2.0b, P2.6, P2.7.
- **Acceptance:**
  - `scripts/deploy.sh <staging-id>` resolves env path to `secrets/env/<staging-id>.env.age`.
  - Smoke config has staging entries for all four checks.
  - Audit log record on a staging deploy shows `project: "<staging-id>"`.

### P2.14 — End-to-end Phase 2 verification

- **Executor:** Vi
- **Goal:** Push a real `feat:` commit to a throwaway branch, open PR, merge to main, verify release PR opens, merge release PR, verify tag → staging deploy → smoke → approval → prod deploy → smoke → audit entry → Discord notification. Then force a bad deploy and verify auto-revert.
- **Files touched:** a throwaway test function in `apps/functions/src/` (reverted at end), a deliberate broken commit to trigger revert path.
- **Dependencies:** P2.1 through P2.13 all merged; Duong available to approve the `production` environment prompt.
- **Acceptance:**
  - Green path verified: tag triggers staging → gate → prod → smoke green.
  - Audit log has two success records (staging, prod) with correct `version`, `git_sha`, `smoke_results`.
  - `/version` on prod returns the new tag.
  - Discord notification posted.
  - Red path verified: a deliberately-broken deploy triggers `revert.sh`, previous tag restored, issue opened, Discord alert posted, audit log has all three records (failed forward, revert success).
  - Cleanup commits land with correct prefixes per the new Rule 5 + P2.2 hook.

---

## Out of scope (explicitly not tasked in this plan)

Per ADR §1 / §10, these are NOT to be implemented in Phase 1 or Phase 2:

- Preview channels / per-PR ephemeral environments.
- Canary / blue-green / traffic-splitting.
- Monitoring dashboard (only the audit-log interface is defined).
- npm publishing for any package.
- Pre-release / alpha / beta tag channels.
- Shared-package lockstep versioning or `linked-versions` / `node-workspace` plugin (revisit when first shared package lands).
- Third environment beyond staging + prod.
- Secret rotation automation.

If an executor finds themselves about to do any of the above, stop and ping Evelynn.

---

## Task count by phase

- **Phase 1:** 14 tasks (P1.0 through P1.13).
- **Phase 2:** 18 tasks (P2.0a, P2.0b, P2.0c, P2.1 through P2.14, with P2.7a as a subtask of P2.7).
- **Total:** 32 tasks across the plan (3 are Duong-prereq human tasks, 29 are agent tasks).

## Dependency summary (critical path)

Phase 1 critical path: **P1.0 → P1.1 → P1.2 → P1.3 (Duong D4) → P1.8 → P1.10 → P1.11 → P1.12**.
Parallel tracks in Phase 1: P1.4→P1.5 (testing track), P1.6, P1.13.

Phase 2 critical path: **Duong D1/D2/D3/D5 → P2.1 → P2.2 → P2.3 → P2.4 → P2.7a → P2.9 → P2.14**.
Parallel tracks in Phase 2: P2.5, P2.6, P2.7, P2.8, P2.10, P2.11, P2.12, P2.13.
