---
status: in-progress
owner: azir
date: 2026-04-17
title: Deployment Pipeline ADR — Firebase surfaces, TDD gates, CI, release-please, staging, auto-revert
---

# Deployment Pipeline ADR

Architecture-level plan for how the strawberry monorepo deploys. Scope covers the full industry-standard pipeline: scripts as the portable body, GitHub Actions as the thin CI skin, release-please for versioning, a staging environment with gated promotion, and auto-revert on prod smoke failure. Implementation tasks are for Kayn/Aphelios to break out after approval — this plan does not write scripts or workflow YAML.

**Supersedes** `plans/approved/2026-04-13-deployment-pipeline-architecture.md`. That plan targeted the Dark Strawberry web apps (Vite/Firebase Hosting) with Changesets versioning; its component thinking (C1 reproducible builds, C4 gated promotion, C5 env validation, C6 smoke tests, C7 version visibility, C8 rollback, C11 turbo cache correctness) is absorbed and re-expressed here in the Cloud-Functions-first, script-first shape that matches the current state of the repo. Where the two conflict, this ADR wins. Changesets is replaced with release-please; `turbo.json` env-hashing concerns only re-apply when a Vite app surface is added back to the pipeline and are out of scope for the Phase 1 Bee/Functions cutover.

---

## 1. Scope

**In scope today:**

- **Firebase Cloud Functions** under `apps/myapps/functions/` (TypeScript, Node 20, entry `lib/index.js`) targeting project `myapps-b31ea`. Functions are co-located under `apps/myapps/` alongside the other Firebase surfaces for this project (hosting, Firestore rules, Storage rules), and all four surfaces share a single `apps/myapps/firebase.json` (see §1a and §4). See Jayce's audit at `assessments/2026-04-17-deploy-script-audit.md` (PR #120) for the source of this layout decision.
- **Firebase Storage rules** (project `myapps-b31ea`).
- **A staging Firebase project** (separate project ID — see open questions) mirroring the prod surface set.
- **GitHub Actions workflows** (`.github/workflows/test.yml`, `.github/workflows/deploy.yml`, plus the release-please workflow) as thin triggers around the deploy scripts.
- **release-please** monorepo manifest mode, per-app versioning, with `apps/myapps/functions` as the first versioned package (`bee`).
- **Auto-revert** on prod smoke failure.
- A single "deploy surface" abstraction so adding more surfaces later doesn't require redesigning the pipeline.

**Seams to leave (not built now):**

- Additional Firebase projects beyond staging + prod.
- Additional surfaces per project (Firestore rules, Hosting, additional Functions codebases).
- Non-Firebase targets (Cloud Run, GCE, static hosting).
- A monitoring dashboard consuming the structured deploy audit log.
- Preview channels / per-PR ephemeral environments.
- Vite / Firebase Hosting assembly and deploy. Continues via the existing `scripts/composite-deploy.sh` + `release.yml`/`preview.yml` path until a dedicated web-surface ADR supersedes it. This pipeline does not touch the Hosting surface.

**Deliberately out of scope:**

- The autonomous Discord-driven delivery loop (`plans/proposed/2026-04-08-autonomous-delivery-pipeline.md`). That plan *consumes* this one's scripts; it does not replace them.
- Preview environments / per-PR channels. Separate plan.
- Multi-project secret rotation.
- npm publishing, changelog customization beyond release-please defaults, pre-release/alpha/beta tags, lockstep multi-package versioning.

### 1a. Monorepo deploy isolation

The Firebase CLI's deploy surface is determined at invocation time, not by the repo layout. This is load-bearing — internalize it before reading the rest.

1. **Deploy axis.** Every deploy is identified by a `<firebase-project> + <surface>` tuple. The monorepo's folder layout is irrelevant to Firebase.
2. **Scope of a deploy.** `firebase deploy --only <surface> --project <id>` uploads only the artifacts of that surface. Sibling apps under `apps/**` are never packaged, uploaded, or touched.
3. **Per-Firebase-project config, not per-surface config.** Each Firebase project has **one** `firebase.json` at that project's app root (e.g. `apps/myapps/firebase.json` for project `myapps-b31ea`). That single file declares **all** surfaces for the project — `hosting`, `functions`, `firestore`, `storage` — as sibling blocks within the same JSON. There is NOT one `firebase.json` per surface, and there is NOT a monorepo-level `firebase.json` that fans out across multiple Firebase projects. If a future second Firebase project is added, it gets its own app root (e.g. `apps/<other>/`) with its own single `firebase.json` covering its own surfaces. Each encrypted env file (`secrets/env/<project>.env.age`) is likewise per Firebase project.
4. **Surface isolation comes from `--only`, not from config splitting.** Even with all surfaces declared in a single `firebase.json`, each deploy invocation still passes `--only <surface>` + `--project <id>`, so only the named surface is uploaded. The single-config layout is how Firebase canonically expects a project's artifacts to live; isolation is enforced at deploy time.
5. **Per-app tags fire per-app deploys.** release-please in per-package manifest mode means a `feat:` landing in `apps/myapps/functions/**` bumps only the `bee` package, produces only a `bee-vX.Y.Z` tag, and therefore triggers only the Bee deploy workflow. A future `apps/landing` bumping does not touch Bee. Note that because multiple surfaces live under one `apps/myapps/` root, release-please's `include-paths` for the `bee` package must scope to `apps/myapps/functions/**` specifically — not all of `apps/myapps/**` — so that hosting/rules edits don't bump the Bee version.
6. **Shared-package trap (future, flagged not solved).** When `packages/shared/**` lands, a change there must open release PRs for every consumer of that shared package. release-please supports this via `linked-versions` or the `node-workspace` plugin; pick one when the first shared package lands. This ADR flags it and does not design it.
7. **Hard contract in `_lib.sh`.** Every surface script MUST pass `--only <surface>` to `firebase deploy`. Bare `firebase deploy` is forbidden and fails a precondition check in `_lib.sh` (grep the invocation or wrap the CLI).

---

## 2. Environment and secrets strategy

**Problem today.** `apps/myapps/functions/.env.myapps-b31ea` is missing. It must contain `GITHUB_TOKEN`, `BEE_GITHUB_REPO=Duongntd/strawberry`, `BEE_SISTER_UIDS=<haruka-uid>`, `DISCORD_WEBHOOK_URL`. Functions deploy is blocked until it exists. (Actual UID value lives in the encrypted dotenv; see P1.3.)

**Principle.** Encrypted ciphertext in git; plaintext only materialized at deploy time, into a child process env, never into a committed file and never into shell history.

**Layout (proposed):**

| Path | Purpose | Committed? |
|------|---------|-----------|
| `secrets/env/<project>.env.age` | Age-encrypted dotenv per Firebase project | yes (ciphertext) |
| `secrets/env/<project>.env.example` | Template with keys, no values, doc-only | yes |
| `apps/myapps/functions/.env.<project>` | Plaintext dotenv, decrypted on demand | no (gitignored) |
| `secrets/age-key.txt` | Age private key | no (gitignored) |

**Flow.**

1. Duong edits ciphertext via the existing `tools/encrypt.html` flow (or a new `tools/edit-env.sh` that decrypts, opens `$EDITOR`, re-encrypts, and shreds the temp file).
2. Deploy entrypoint invokes `tools/decrypt.sh` to materialize plaintext into the child process environment. It does **not** write `.env` to disk unless `firebase deploy` explicitly needs a file on disk — in which case the file is written to a path inside the gitignored `apps/myapps/functions/` tree, never committed, and removed on exit via a `trap`.
3. Rule 6 hard-enforced: no raw `age -d`, no `cat` on plaintext, no piping of the age key. Pre-commit hook already blocks this; deploy scripts must honor it too.

**Project selection.** The Firebase project is the deploy-time axis. One encrypted env file per project, named by the Firebase project ID (not by environment semantics like "prod" / "staging"). Staging gets its own project ID, its own encrypted env, its own deploy invocation. No magic env-var toggles at deploy time.

**Bootstrapping the missing env now.** The immediate unblock is to create `secrets/env/myapps-b31ea.env.age` from Duong's known values. A dedicated bootstrap task (Kayn's to break out) handles this — it is **not** part of the pipeline design itself, just its first payload.

---

## 3. Test gates — TDD discipline

**Rule: a surface does not deploy if its tests don't pass locally first.** The pipeline enforces this by running tests before the provider CLI is invoked, and bailing on failure. No `--force`, no skip flag.

**Per-surface test matrix:**

| Surface | Unit framework | Integration framework | Required before deploy |
|---------|---------------|----------------------|------------------------|
| Cloud Functions (`apps/myapps/functions/`) | Vitest (recommended) or Jest | `firebase-functions-test` + Firebase emulator suite | unit + integration both green |
| Firebase Storage rules | `@firebase/rules-unit-testing` driving the Firebase emulator | (integration is the unit here) | rules-unit-testing suite green |

Rationale for Vitest over Jest for Functions: faster, native TS, lighter config, and it composes cleanly with the existing `tsconfig.json`. Jest is acceptable if Kayn/Aphelios prefer it for ecosystem reasons — tradeoff is ~2x slower cold start and a heavier config surface. Pick one, do not mix.

**TDD workflow the pipeline assumes:**

1. Write a failing test before changing production code.
2. Make it pass.
3. Run the full surface test suite (`pnpm --filter functions test` or equivalent) locally.
4. Deploy entrypoint re-runs that same suite as the gate. Same command, same config — the local and gate runs must be identical so "works on my machine" cannot smuggle broken code past the gate.

**Commands (shape only, Kayn to bind to concrete tools):**

- `scripts/test-functions.sh` — runs functions unit + integration tests; exits non-zero on any failure. POSIX bash, works on macOS and Git Bash.
- `scripts/test-storage-rules.sh` — boots the Firebase emulator, runs rules-unit-testing, tears down the emulator. Same portability contract.
- `scripts/test-all.sh` — invokes every `scripts/test-*.sh` entrypoint. Used by CI and by agents before opening PRs.

**Non-negotiables.**

- Tests run against the Firebase emulator, never against the live `myapps-b31ea` project. The emulator ports live in `apps/myapps/firebase.json` (amended during P1.1c to cover all four surfaces).
- No mocking of the Firebase Admin SDK in integration tests. Mocks are for unit tests only. Integration tests hit the emulator.
- Flaky tests are bugs, not tolerances. A flaky test gets fixed or quarantined with an issue tracking it — it does not get an automatic retry in the gate.

---

## 4. Deploy command and script layout

**Shape: one thin entrypoint per surface, one orchestrator per project, one top-level deploy script.**

```
scripts/
  deploy.sh                      # existing; becomes the top-level dispatcher
  deploy/
    _lib.sh                      # shared helpers: decrypt env, log audit event, check clean tree, enforce --only
    project.sh                   # deploy ALL surfaces for a given project
    functions.sh                 # deploy Cloud Functions for a given project
    storage-rules.sh             # deploy Storage rules for a given project
    smoke.sh                     # post-deploy HTTP smoke test (Section 7)
    revert.sh                    # look up previous successful tag and redeploy it (Section 7)
  test-functions.sh
  test-storage-rules.sh
  test-all.sh
```

**Contracts.**

- `scripts/deploy.sh <project> [<surface>] [--ref <git-ref>] [--skip-staging] [--yes]` — top-level. If surface omitted, deploys all surfaces for that project. `--ref` checks out a specific ref (used by auto-revert and `workflow_dispatch` hotfix). `--skip-staging` is for hotfixes and is audited (Section 6). Examples: `scripts/deploy.sh myapps-b31ea`, `scripts/deploy.sh myapps-b31ea functions --ref bee-v1.2.2`.
- Each surface script takes exactly one positional arg: the Firebase project ID. Optional flags match the top-level flags that are relevant.
- Each surface script is responsible for: (1) running its own test gate, (2) materializing env via `tools/decrypt.sh`, (3) invoking the Firebase CLI with `--project <id>` **and an explicit `--only` scope** (Section 1a.7), (4) emitting an audit event, (5) invoking `scripts/deploy/smoke.sh` after deploy.
- **Firebase CLI invocation context.** Scripts run from the repo root, but the Firebase CLI needs to resolve `firebase.json` for the target project. Surface scripts `cd "$REPO_ROOT/apps/myapps"` before invoking `firebase deploy`, then restore `cwd` on exit via a `trap`. The alternative — passing `--config apps/myapps/firebase.json` from the repo root — works for `firebase.json` itself but does not reliably handle relative paths *inside* firebase.json (e.g. `"source": "functions"` resolves relative to the config file's dir, which works either way; but `predeploy` scripts and `ignore` globs are more predictable when `cwd` matches the config dir). Choose `cd` + `trap`. Helper `dl_cd_firebase_root <project>` in `_lib.sh` encapsulates this so no surface script hardcodes the path.
- **Every script is POSIX bash, works identically on macOS and Git Bash on Windows** (Rule 10). Platform-specific affordances live under `scripts/mac/` or `scripts/windows/` and are optional hooks, never required for deploy correctness.

**Preconditions enforced by `_lib.sh`:**

- Working tree is clean (or `--allow-dirty` is explicitly passed, which is off by default and off in CI always).
- On `main` branch unless `--allow-branch` is passed, or `--ref` specifies a tag (auto-revert path).
- Required env keys present after decrypt.
- Firebase CLI authenticated: service-account key file if `GOOGLE_APPLICATION_CREDENTIALS` is set (CI path), otherwise the user's logged-in CLI (local path).
- `firebase deploy` invocations in this script tree include `--only <surface>`. Bare `firebase deploy` fails a static grep check.
- Firebase CLI is invoked from `apps/myapps/` (per the `cd` + `trap` rule above) so the single `apps/myapps/firebase.json` is auto-detected; no `--config` flag needed.

**Interaction with existing `scripts/deploy.sh` and `scripts/composite-deploy.sh`.** Both exist today and their current semantics need to be reconciled. Kayn's breakdown must include an audit pass: keep, rename, or absorb. The names above reserve `scripts/deploy.sh` as the new canonical dispatcher — if the existing file does something incompatible, rename the old one first and do not silently overwrite. `composite-deploy.sh` was built for the Vite-app world of the superseded plan and is not invoked in this ADR's design; decide during breakdown whether to delete it or carry it forward for a future web-surface addition.

**Phase-2 policy for `composite-deploy.sh` and Vite/Hosting assembly.** Phase 2 does **NOT** absorb Vite hosting assembly. `scripts/composite-deploy.sh` remains called by `.github/workflows/release.yml` and `.github/workflows/preview.yml` unchanged until a separate web-surface ADR supersedes it. The script stays dormant and carries its deprecation comment through Phase 2. Phase-2 `release.yml`/`preview.yml` rewrites MUST NOT take a dependency on `composite-deploy.sh` beyond the existing unchanged invocation; if those workflows still need Hosting deploys after the Phase-2 rewrite, they continue to call the existing `composite-deploy.sh` **unchanged** and the Hosting surface remains outside the new `scripts/deploy/` tree. The new pipeline does not absorb Vite assembly — attempting to do so violates §1 non-goals.

**Note on top-level VPS scripts.** `scripts/deploy-discord-relay-vps.sh` (the Hetzner-VPS Discord-relay PM2 restart script, renamed in P1.1 from the previous `scripts/deploy.sh`) lives at top level but is **outside** this pipeline. Its body is POSIX-bash (Rule 10 satisfied) even though its runtime target is a Linux VPS. It deploys the Discord-relay VPS, not a Firebase surface, and does not participate in the test gate / audit log / smoke test contract. Flagged here to prevent reader confusion with the upcoming Firebase dispatcher at `scripts/deploy.sh`. A future reorg may move it under `scripts/vps/` — not required now.

---

## 5. CI workflows, service account, and branch protection

CI is in scope for Phase 2 of this plan. The scripts remain the body; the YAML is the skin — a workflow file is at most ~10 lines of orchestration that calls into the same `scripts/*.sh` that run locally. No logic duplicated in YAML.

**Assumption.** `origin` remote is healthy (Duong confirms this is an account-switch issue, not a broken remote). Verified as a Phase-2 prerequisite before any GH Actions work lands.

**Workflows.**

- `.github/workflows/test.yml` — triggers on every PR to `main`. Runs `scripts/test-all.sh`. Required status check on the `main` branch protection rule. PRs cannot merge without it green.
- `.github/workflows/deploy.yml` — triggers on `workflow_dispatch` only. Inputs: `project` (required, e.g. `myapps-b31ea`), `ref` (optional git ref; defaults to `main`), `skip_staging` (optional boolean, default false, audit-logged when true). Used for hotfixes and reruns. Calls `scripts/deploy.sh <project> [<surface>] --ref <ref>`.
- `.github/workflows/release.yml` — triggers on tag push matching `<package>-v*` (e.g. `bee-v1.2.3`). Deploys the staging project first, smoke-tests, then (via a `production` GH Environment gate) deploys prod and smoke-tests. See Section 6.
- `.github/workflows/release-please.yml` — triggers on push to `main`. Runs `googleapis/release-please-action` in manifest mode to open/update release PRs and cut tags on merge.

**Branch protection on `main`.**

- Require PR with at least 1 review (self-review by Duong acceptable for now).
- Require `test.yml` to pass.
- Require linear history disabled (Rule 11 — never rebase). Merge commits allowed.
- Restrict direct pushes: only release-please's automated commits (release PR merges, manifest updates) and Duong-as-admin may push directly to `main`. Agents always PR.

**Firebase service account (both envs).**

- IAM roles (minimum):
  - `roles/firebase.admin` — covers Functions + Storage rules deploy for Firebase-native surfaces.
  - `roles/cloudfunctions.admin` — redundant with firebase.admin for Firebase-CLI-driven deploys but kept explicit for portability if we later deploy via `gcloud`.
  - `roles/storage.admin` — for any bucket-level work beyond rules (rule deploys alone don't need this, but future object-level ops will). Optional for Phase 2; add only if required.
  - `roles/iam.serviceAccountUser` on itself — required for `gcloud`-driven function source uploads when the firebase-tools CLI delegates.
  - **Not** `roles/owner`, **not** `roles/editor`. The principle is least-privilege; grant narrow roles first and widen only when a deploy failure proves a role is missing.
- Key material:
  - Key JSON base64-encoded, stored as GH Actions secret `FIREBASE_SA_KEY_<project>` (one per project; Bee staging and Bee prod get separate SAs).
  - Age private key stored as GH Actions secret `AGE_KEY` (single repo-level secret; both envs decrypt with it).
  - Scripts read via `$GOOGLE_APPLICATION_CREDENTIALS` (which the workflow writes to a temp file from the base64 secret and removes on job exit via a `trap`).
- **Prereq (Duong).** Create the two service accounts in the GCP console for staging and prod projects, grant the roles above, download key JSONs, base64-encode, paste into GH Actions secrets. Azir does not perform or automate this — it's a one-shot human setup.

**Contract: CI and local run the same scripts.**

- No interactive prompts in the critical path — `--yes` skips all confirmations; CI always passes it.
- No `$EDITOR`, `open`, `pbcopy` in the critical path. Those belong in `scripts/mac/` helpers.
- Secrets come from the same encrypted-env pattern in both environments. The `GOOGLE_APPLICATION_CREDENTIALS` presence check selects SA auth; its absence falls back to CLI auth (local dev).

---

## 6. release-please versioning

Duong picked release-please explicitly. This section specifies how.

**Tool and config.**

- `googleapis/release-please-action@v4` (or current stable major), **manifest mode**.
- `release-please-config.json` and `.release-please-manifest.json` at repo root. Manifest mode is mandatory — it supports the per-app versioning axis required for deploy isolation (Section 1a.5).
- **First app:** `apps/myapps/functions`, package name `bee`. Tag format `bee-v1.2.3`. release-please `include-paths` for `bee` must be scoped to `apps/myapps/functions/**` specifically (see §1a.5) so sibling surfaces under `apps/myapps/` don't bump the Bee version. Other apps added later follow the same pattern (e.g. `landing-v0.1.0`). The release-please `package-name: bee` is independent of the npm `name` field in `apps/myapps/functions/package.json` (currently `darkstrawberry-functions`). release-please `include-paths` + `package-name` in the manifest are the binding; npm `name` is not renamed by this ADR. Both names coexist legitimately — release-please tags use `bee`, npm resolution uses `darkstrawberry-functions`.
- First Bee version: see open questions (`0.1.0` vs `1.0.0`).

**Commit convention — resolving the conflict with CLAUDE.md Rule 5.**

CLAUDE.md Rule 5 currently mandates `chore:` / `ops:` as the only allowed prefixes. release-please requires `feat:` / `fix:` / `perf:` / `refactor:` to drive version bumps. These must coexist without ambiguity:

- **`chore:` / `ops:`** — mandatory for plans, memory, learnings, scripts (outside `apps/**`), infra, meta, docs, CI config. Never triggers a release.
- **`feat:` / `fix:` / `perf:` / `refactor:`** — allowed **only** on commits whose diff touches `apps/**`. Drives release-please version bumps per conventional-commits semantics.
- **`feat!:`** or any commit footer containing `BREAKING CHANGE:` — major version bump.
- **Commit-scope validation hook (work item, design deferred).** A pre-commit or pre-push hook inspects the diff and the commit subject:
  - If any file in `apps/**` is touched AND the commit prefix is `chore:` / `ops:` → reject (under-declared).
  - If no file in `apps/**` is touched AND the prefix is `feat:` / `fix:` / `perf:` / `refactor:` → reject (over-declared; release-please would cut an empty release).
  - Mixed diffs (touching both `apps/**` and meta files) — allowed with `feat:` / `fix:` style; the meta change rides along.
  - This is flagged as work for Kayn, not designed here in mechanical detail.
- **CLAUDE.md Rule 5 amendment is a Phase-2 prerequisite.** Rule 5 must be rewritten to describe the two-class commit convention before any `feat:` commit lands on `main`. That amendment is its own `chore:` commit and is the first Phase-2 task.

**Flow.**

1. A developer (or agent via PR) merges a `feat: …` commit that touches `apps/myapps/functions/` into `main`.
2. `release-please.yml` opens or updates the Bee release PR, titled `chore(bee): release 1.3.0`, with an auto-generated CHANGELOG.
3. Duong (or whoever has release authority — see open questions) reviews and merges the release PR.
4. release-please pushes the tag `bee-v1.3.0` to `main`.
5. `release.yml` fires on the tag: deploys to staging, smoke tests, waits for approval, deploys to prod, smoke tests, auto-reverts on failure.

**Audit log integration.** Every record in `logs/deploy-audit.jsonl` gains a `version` field:

- For tag-driven deploys: the tag (`"bee-v1.3.0"`).
- For `workflow_dispatch` hotfixes driven off `main` without a tag: `null`.

**Runtime version visibility.**

- At deploy time, the workflow injects `BEE_VERSION=<tag>` as a function environment variable.
- Functions expose the value either by logging it at cold start (`console.info({ event: "cold_start", version: process.env.BEE_VERSION })`) or via a dedicated `/version` HTTP endpoint that returns `{ version, sha, builtAt }`. Choose one during implementation — the smoke test (Section 7) prefers the HTTP endpoint since it doesn't require log scraping. `/version` is the recommended choice.

**Non-goals for versioning.**

- No npm publishing. Bee is deployed, not published.
- No changelog customization beyond release-please defaults.
- No pre-release / alpha / beta tag channels.
- Per-app independent versioning only — no lockstep `linked-versions` for Phase 2. Revisit when the first shared package lands (Section 1a.6).

---

## 7. Staging environment and gated promotion

**Two environments.**

- **Staging** = a separate Firebase project. Working name `myapps-b31ea-staging` (final ID in open questions — may already be taken; create a new one or reuse an existing staging project Duong has set up). Owns its own `secrets/env/<staging-project>.env.age` and its own service-account key (Section 5).
- **Prod** = `myapps-b31ea`.

Two Firebase projects is strictly more isolation than two environments inside one project. Test data, billing, IAM, emulator defaults all split cleanly. Anti-pattern rejected: no "environment flag" that toggles inside a single project.

**Promotion flow (single workflow, two jobs, one gate).**

`release.yml` is triggered on tag push matching `<pkg>-v*`. Structure:

```
job 1: deploy-staging
  - checkout tag
  - scripts/deploy.sh <staging-project> --ref <tag> --yes
  - scripts/deploy/smoke.sh <staging-project>
  - on failure: exit non-zero (no auto-revert — prod never got it)

job 2: deploy-production
  - needs: deploy-staging
  - environment: production  (GH Environment gate; required reviewer = Duong)
  - checkout tag
  - scripts/deploy.sh myapps-b31ea --ref <tag> --yes
  - scripts/deploy/smoke.sh myapps-b31ea
  - on smoke failure: invoke scripts/deploy/revert.sh (Section 7a)
```

**GitHub Environments.**

- `staging` — no required reviewers; deploy runs automatically once `deploy-staging` job starts.
- `production` — one required reviewer (Duong). No auto-approval.

**`deploy.yml` (hotfix / rerun path).**

- `workflow_dispatch` only.
- Inputs: `project` (required), `ref` (optional; default `main`), `skip_staging` (optional boolean, default false).
- When `skip_staging: true`, the audit record emits `"skipped_staging": true` and the Discord notification flags it. This is the legitimate hotfix door — auditable, not hidden.

**Staging cadence.** Continuous staging on every `main` push vs staging-only on release tag — see open questions. Recommendation: staging only on tag. Continuous staging requires an additional workflow and risks staging churn that doesn't match what prod will get.

**Non-goals.**

- No preview channels (addressed in Section 1 seams).
- No per-PR ephemeral envs.
- No third environment. Two is the ceiling for this plan.

### 7a. Auto-revert on prod smoke failure

**Smoke test (~30 seconds, runs on every deploy).** `scripts/deploy/smoke.sh` performs:

1. HTTP GET `/version`, assert body `{ version }` matches the `BEE_VERSION` the deploy just set. Closes the loop on "is this actually the deploy I think it is."
2. A configurable HTTP assertion list: healthz endpoint (200), an unauthenticated public read (200), an auth-gated read (401/403 without token). The list lives in a small YAML/JSON config file per surface (Kayn picks format during breakdown); extensibility is the point, not the config format.

**On staging smoke failure.** Exit non-zero, block prod. No revert needed — staging's brokenness does not affect prod.

**On prod smoke failure.** `scripts/deploy/revert.sh` runs:

1. Look up the previous successful prod tag. Two sources of truth, in order: (a) `logs/deploy-audit.jsonl` — most recent `status: success` record for the prod project + surface; (b) GitHub Releases API, filtering to releases that actually succeeded.
2. **Guardrail: if no previous successful tag exists** (first-ever deploy, or history lost) → **do NOT revert**. Fail loud, open an issue, page Duong. A revert with no known-good anchor is worse than a broken deploy.
3. Invoke `scripts/deploy.sh myapps-b31ea <surface> --ref <prev-tag> --yes`. This is a full redeploy, not a magic rollback.
4. Open a GitHub issue (title: `Auto-revert: <tag> → <prev-tag>`, body: smoke-failure output).
5. Post a Discord alert with both tags, the failed-smoke reason, and the issue link.
6. Audit log records two records: the failed forward deploy (`status: failure`) AND the revert deploy (`status: success` or `status: failure` of its own smoke).

**Cascade guardrail.** The revert deploy's smoke test runs. If it also fails, **stop and page**. Do not attempt a second revert. One hop back is recoverable; cascading back through N tags is not, and the system is clearly in a state that needs a human.

**Honest caveat (put this in the ADR in plain language, not buried).** Firebase Functions do not have atomic traffic swaps or instant rollback. An "auto-revert" is literally another full deploy, which takes 1–2 minutes. During that window, the broken version serves traffic. This is a catastrophic-failure safety net — it reduces mean time to recovery from "Duong sees it, logs in, redeploys" to "CI handles it in ~2 minutes." It is not zero-downtime.

**Config toggle.** `auto_revert: true | false` in a pipeline config file, default `true`. When `false`, prod smoke failure pages Duong and stops, no revert attempted. Duong may prefer `false` during periods when he wants to diagnose in place instead of having CI move state out from under him.

---

## 8. Observability hook — interface for the future dashboard

The monitoring dashboard is a separate future plan. This ADR defines only the **interface** the dashboard will read from, so nothing we build now has to be retrofitted.

**Two observability streams:**

1. **Deploy audit log** — structured JSONL file, append-only, written by every deploy invocation.
   - Path: `logs/deploy-audit.jsonl` (gitignored — it's per-machine history, not shared state; CI streams its own audit log to a bucket in a future iteration).
   - One record per deploy attempt, written at start and updated at end (or two records: `deploy.started`, `deploy.finished`, following the event-spine style already used elsewhere in the system).
   - Schema (minimum viable fields):
     ```json
     {
       "ts": "2026-04-17T10:00:00Z",
       "event": "deploy.finished",
       "project": "myapps-b31ea",
       "surface": "functions",
       "git_sha": "abc1234",
       "version": "bee-v1.3.0",
       "actor": "duong@local",
       "status": "success",
       "duration_ms": 12345,
       "test_results": { "unit": "pass", "integration": "pass" },
       "smoke_results": { "status": "pass", "checks": ["version", "healthz"] },
       "skipped_staging": false,
       "revert_of": null,
       "error": null
     }
     ```
   - `version` is the release-please tag or `null` for hotfix (Section 6).
   - `revert_of` is the tag that was reverted from, or `null` for normal deploys (Section 7a).
   - `skipped_staging` is true only when a `workflow_dispatch` bypassed staging.
   - Dashboard contract: **read this file, do not write to it.** Anything that mutates the audit log is a bug.

2. **Firebase function logs** — already emitted by the runtime. Dashboard reads via `firebase functions:log` or the Cloud Logging API. No pipeline work needed to enable this; just note it as an input.

**Why JSONL on local disk and not Firestore / Cloud Logging for the audit log.** Local disk is the lowest-complexity venue that survives the "local-only deploy" phase and the "CI-added later" phase equally well — CI can stream its audit log to a bucket, local keeps it on disk, and both expose the same schema to the dashboard via a small reader abstraction later. Writing audit data into Firestore would entangle the deploy pipeline with the product data plane, which is the wrong direction.

**The seam the dashboard will plug into:**

- `scripts/deploy/_lib.sh` owns the audit-log append. Dashboard reads `logs/deploy-audit.jsonl`. That's the entire contract.
- No other component of the pipeline touches the audit log. If the dashboard needs richer data later, the schema grows additively (new fields are safe; removing fields is a breaking change).

---

## 9. Implementation phasing

Phase-level only. Task-level breakdown is Kayn's job after approval.

**Phase 1 — Local deploy pipeline (no CI yet).**

- Script tree (`scripts/deploy/*`, `scripts/test-*.sh`) per Section 4.
- Encrypted env bootstrap for `myapps-b31ea` per Section 2.
- TDD test gates per Section 3 (Vitest + emulator).
- Deploy audit log writer in `_lib.sh` per Section 8.
- Reconciliation of existing `scripts/deploy.sh` and `scripts/composite-deploy.sh`.
- Monorepo deploy isolation contract in `_lib.sh` (Section 1a.7).

Exit criterion: Duong can run `scripts/deploy.sh myapps-b31ea` on his laptop, tests run, deploy succeeds, audit log written.

**Phase 2 — CI + release-please + staging + auto-revert.**

- **Prereq 1 (human):** Duong fixes `origin` remote account switch.
- **Prereq 2 (human):** Duong creates staging Firebase project, confirms ID.
- **Prereq 3 (human):** Duong creates service accounts in GCP console (staging + prod), uploads base64 keys to GH Actions secrets, uploads age key to GH Actions secret.
- **Prereq 4 (this plan chain):** CLAUDE.md Rule 5 amendment commit lands on `main` (Section 6) — widen allowed prefixes, describe scope-validation rule.
- `test.yml`, `deploy.yml`, `release-please.yml`, `release.yml` workflows.
- Branch protection on `main` (require `test.yml` green).
- release-please manifest config; first Bee release.
- Staging project env + staging deploy wiring.
- GH Environments `staging` and `production` with Duong as prod reviewer.
- `scripts/deploy/smoke.sh` with `/version` check + configurable assertion list.
- `scripts/deploy/revert.sh` with guardrails per Section 7a.
- Commit-scope validation hook (flagged work; not designed here).

Exit criterion: a `feat:` commit in `apps/myapps/functions/` → release PR → merge → tag → staging deploy + smoke → approval → prod deploy + smoke → Discord notification. A forced bad deploy triggers auto-revert to the previous tag.

---

## 10. Explicit non-goals

- No autonomous / agent-driven deploy trigger for the production path. Agents can open PRs; promotion through the `production` GH Environment requires Duong.
- No multi-project orchestration beyond the staging→prod promotion defined in Section 7. Each deploy invocation targets exactly one Firebase project.
- No blue/green, canary, or traffic-splitting logic. `firebase deploy` ships all-at-once; auto-revert is a redeploy, not a traffic swap (Section 7a caveat).
- No secret rotation tooling. Rotating a secret means Duong edits the ciphertext and redeploys. Automation comes later.
- No monitoring dashboard. Only the audit-log interface is defined here.
- No preview channels. Separate plan.
- No per-PR ephemeral envs.
- No test suites for surfaces we don't deploy today.
- No npm publishing, no pre-release tag channels, no lockstep multi-package versions, no changelog customization beyond release-please defaults.
- No third environment beyond staging + prod.

---

## 11. Open questions for Duong

1. **Vitest or Jest for Cloud Functions tests?** Recommendation: Vitest (faster, native TS, lighter config). Confirm or override.
2. **Encrypted dotenv vs. Firebase Functions "secret params" (`defineSecret`).** Recommendation: ciphertext-in-git for `GITHUB_TOKEN`, `DISCORD_WEBHOOK_URL`, and any value shared across surfaces; Firebase secret params only if a future surface specifically benefits from Google-managed rotation. Confirm.
3. **Where does the encrypted env file live — `secrets/env/<project>.env.age` or `apps/myapps/functions/.env.<project>.age`?** Recommendation: centralize in `secrets/env/`.
4. **Deploy from `main` only, or any branch with `--allow-branch`?** Recommendation: `main` only by default; `--allow-branch` for explicit hotfixes and experimental deploys, never in CI.
5. **Audit log retention.** Recommendation: no rotation now; revisit when the dashboard lands.
6. **Firebase CLI auth for local deploys — personal Google account, or a project-scoped service account stored encrypted?** Recommendation: personal account locally, service account in CI — the scripts detect which.
7. **`firebase-functions-test` offline mode vs emulator-backed integration — both, or only emulator?** Recommendation: emulator-backed only.
8. **Reconcile `scripts/deploy.sh` and `scripts/composite-deploy.sh` up-front, or retire later?** Recommendation: reconcile up-front — two deploy entrypoints invites confusion.
9. **Release-please bot commits on `main` — acceptable?** (release-please pushes version-bump commits and manifest updates directly to `main` after you merge the release PR.) Recommendation: yes, it's the point of the tool; branch protection carves out its GitHub Actions identity.
10. **First Bee version — `0.1.0` or `1.0.0`?** Recommendation: `0.1.0`. Bee is pre-stable-API; `1.0.0` signals an API contract we're not yet ready to hold.
11. **Release PR auto-merge on green CI, or manual merge by Duong?** Recommendation: **manual**. The release PR is the last human checkpoint before a tag goes out; auto-merge removes it.
12. **Staging project ID — create new `myapps-b31ea-staging`, or reuse an existing staging project?** Confirm. If creating new: Phase-2 prerequisite task.
13. **Continuous staging on every `main` push, OR staging only on release tag?** Recommendation: **tag only**. Per-push staging churn that doesn't match what prod will get.
14. **Smoke test scope — `/version` only, or include an auth'd read?** Recommendation: `/version` + healthz + an unauth read + an auth-gated read (401 assertion). Four cheap checks catch four different failure modes.
15. **Prod deploy approver — Duong only, or any push-rights agent?** Recommendation: **Duong only**. Production promotion is a human-accountable action.
16. **Shared packages versioning (when they exist) — lockstep or independent?** Recommendation: **independent**. Lockstep forces unrelated apps to rev together. Revisit if cross-package breakage becomes a pattern.
17. **Service-account IAM roles — start with `firebase.admin` + `cloudfunctions.admin` + `iam.serviceAccountUser`-on-self, add `storage.admin` only if needed?** Recommendation: yes, widen reactively.
18. **`auto_revert` default true or false?** Recommendation: **true**. Two-minute bad window is less bad than indefinite bad window. Switch off during diagnostic sessions.

---

## Cross-references

- `plans/approved/2026-04-13-deployment-pipeline-architecture.md` — **superseded** by this ADR. Where that plan and this one conflict, this one wins. Specifically: Changesets is replaced by release-please; the Vite/web-app-focused components (env validation plugin, version.json injection, turbo cache hashing, Playwright smoke against web URLs) do not re-apply to the Functions-first pipeline and will be re-derived if a web surface is added.
- `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md` — the autonomous Discord loop that will eventually *call* these deploy scripts. This plan defines the scripts' contract so that loop has something stable to invoke.
- `CLAUDE.md` Rule 5 — requires amendment in Phase 2 to accommodate `feat:` / `fix:` in `apps/**` commits. Phase-2 prerequisite.
- `CLAUDE.md` Rule 6 — secrets discipline, `tools/decrypt.sh` usage.
- `CLAUDE.md` Rule 10 — POSIX-portable bash requirement.
- `architecture/key-scripts.md` — to be updated by the breakdown with the new script inventory.
