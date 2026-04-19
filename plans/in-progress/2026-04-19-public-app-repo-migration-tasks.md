---
status: in-progress
owner: kayn
date: 2026-04-19
title: Public app-repo migration — Task Breakdown
parent_adr: plans/approved/2026-04-19-public-app-repo-migration.md
acceptance_gates: assessments/2026-04-18-migration-acceptance-gates.md
---

# Public app-repo migration — Task Breakdown

Executable task list for the approved migration ADR
(`plans/approved/2026-04-19-public-app-repo-migration.md`). Six numbered phases
match ADR §4 (Phase 0 through Phase 6). Each task has an ID of the form
`P<phase>.<step>`, a goal, an owner, inputs/outputs, acceptance gate (tied to
Caitlyn's acceptance-criteria checklist at
`assessments/2026-04-18-migration-acceptance-gates.md` — gate IDs of the form
`P<phase>-G<n>` and `M-G<n>`), rollback point reference (ADR §6.3), and
prerequisite task IDs.

---

## Team composition (Evelynn's call)

- **Ekko** — owns Phases 0, 1, 4 + Phase 2 grep-sweep + secondary-slug
  checks + branch-protection template fix (dual-green queue merges,
  history filter + gitleaks audit, PR replay). Explicitly **not** doing
  the runtime parametrization rewrites — those are Viktor's (refactoring
  specialty).
- **Viktor** — owns Phases 3 and 5 + Phase 2 parametrization tasks
  (P2.P1-P2.P6 and the regression-guard hook). No runtime string or
  workflow in the scratch tree contains a literal repo slug when Viktor
  hands off to Ekko for the Phase 3 push.
- **Duong** — owns Phase 0 preflight (§4.0), Phase 3 step 7 Firebase binding
  cutover, Phase 3 step 8 sign-off for first-workflow red-or-green decision,
  Phase 6 purge confirmation after 7 days of stable operation.
- **Reviewers** — **Kayn** (this planner) and **Senna + Lucian** (Senna: code-quality + security; Lucian: plan/ADR fidelity) on
  every PR in both repos across the migration.

Azir's §10 handoff named Ekko + Caitlyn; that allocation is overridden by
Evelynn to Ekko + Viktor. Caitlyn's acceptance-gate checklist is already
landed at `assessments/2026-04-18-migration-acceptance-gates.md` (57
gates, commit beb0902).

**Scope change (Duong, 2026-04-19):** Phase 2 is no longer "sed-rewrite
old slug to new slug." Duong wants **zero hardcoded repo slugs anywhere**
in runtime code, workflows, scripts, and prompts — so a future rename is
frictionless. Each of Ekko's 17 hits from the dry-run report is
parametrized rather than rewritten. See Phase 2 tasks below; original
P2.2 / P2.3 are retired in favour of P2.P1-P2.P6 + P2.Z.

**Formal TDD skipped for this migration per ADR §8.** Acceptance-criteria
gates replace xfail tests. Every task's "Acceptance gate" field names which
gate it must satisfy in Caitlyn's checklist
(`assessments/2026-04-18-migration-acceptance-gates.md`, 57 gates total).

---

## Duong-blocking prerequisites (summary)

These must be done by Duong before the dependent tasks can proceed.

| Ref | Blocker | Blocks | Phase |
|-----|---------|--------|-------|
| D1 | Create empty public repo `harukainguyen1411/strawberry-app` (no README/LICENSE/gitignore). | P3.1 | 0 |
| D2 | In new repo → Actions → General → Allow all actions; default workflow permissions = read+write. | P3.8 | 0 |
| D3 | Enable Dependabot alerts + security updates on new repo. | P3.6 | 0 |
| D4 | Install Firebase CI/CD GitHub App on `harukainguyen1411/strawberry-app`. | P3.7 | 0 |
| D5 | Confirm repo name `strawberry-app` and LICENSE decision (ADR §8: none, source-available). | P0.0 | 0 |
| D6 | Enter each of the 17 GitHub secrets into strawberry-app when Viktor prompts in P3.2. | P3.2 | 3 |
| D7 | Sign off on Phase 3 step 8 first-workflow result — if red, invoke rollback (ADR §6.3). | P3.8 | 3 |
| D8 | Firebase GitHub App binding cutover: disconnect from strawberry, confirm strawberry-app. | P3.7 | 3 |
| D9 | 7-day green-operation window confirmation before Phase 6 purge. | P6.1 | 6 |
| D10 | Phase 0 CI-override sign-off — if CI minutes still 0, authorise one-time `--admin` merge (ADR §8 decision 5). | P0.2 | 0 |

---

## Phase 0 — Merge the dual-green queue (in strawberry)

Exit criterion: every dual-green PR in strawberry either merged to main or
explicitly deferred to Phase 4 replay. Whatever is on main after Phase 0 is
the base commit for the public-repo squash.

### P0.0 — Preflight confirmation

- **Owner:** Duong (via Evelynn) — agents verify only.
- **Inputs:** ADR §4.0, §8.
- **Outputs:** Confirmation that D1-D5 preflight items are done; go-ahead for
  Ekko to start P0.1.
- **Acceptance gate:** ADR §4.0 items 1-6 checked off — preflight is a
  precondition to P0-G* gates, not itself a gated check (D1-D5 completion
  is the gate substitute).
- **Rollback point:** ADR §6.3 row "After phase 0" — no rollback needed yet.
- **Blockers:** D1-D5 (Duong-in-loop).
- **Duong-in-loop:** YES.

### P0.1 — Enumerate the dual-green queue

- **Owner:** Ekko.
- **Inputs:** current `gh pr list --state open --repo Duongntd/strawberry`
  output; ADR §1 enumerates 11-13 PR IDs as reference but the actual set is
  discovered fresh at session start.
- **Outputs:** ordered list (by `updatedAt` ascending) of PR numbers with
  per-PR fields: check-state (green/red), reviewDecision (approved/other),
  draft flag. Written to `assessments/2026-04-19-migration-pr-queue.md`.
- **Acceptance gate:** list file exists and every currently-open PR in
  Duongntd/strawberry is represented — feeds P0-G1 (merged or explicitly
  skipped) and P0-G2 (no APPROVED+green PR left open).
- **Rollback point:** ADR §6.3 row "After phase 0" — none.
- **Blockers:** P0.0.
- **Duong-in-loop:** no.

### P0.2 — Merge the green+approved queue (squash merges)

- **Owner:** Ekko.
- **Inputs:** P0.1 queue file.
- **Outputs:** each qualifying PR merged via
  `gh pr merge <N> --squash --delete-branch`; local main pulled between each
  merge to avoid cascading rebases. Final state: strawberry main has absorbed
  every green+approved PR.
- **Acceptance gate:** satisfies **P0-G1** (every qualifying PR merged or
  documented-skip) and **P0-G2** (no APPROVED+green PR left open). If
  `--admin` path was taken, **P0-G5** (incident note) also applies.
- **Rollback point:** ADR §6.3 row "After phase 0" — no remote rollback
  needed; merges are the desired end state.
- **Blockers:** P0.1, D10 (if CI minutes are still 0, Duong must authorise
  one-time `--admin` merges and an incident log is filed — ADR §8
  decision 5).
- **Duong-in-loop:** conditional (only if admin-merge path is taken).

### P0.3 — Freeze strawberry main

- **Owner:** Ekko.
- **Inputs:** post-P0.2 main SHA.
- **Outputs:** announcement in Evelynn-coordinator channel: "strawberry main
  frozen at `<SHA>` for migration — no new merges until Phase 6." The SHA is
  the base-commit-of-record for the squash. Record in the PR queue file from
  P0.1.
- **Acceptance gate:** satisfies **P0-G3** (local main = origin/main) and
  **P0-G4** (cut-line SHA recorded in session journal).
- **Rollback point:** ADR §6.3 row "After phase 0" — none.
- **Blockers:** P0.2.
- **Duong-in-loop:** no.

---

## Phase 1 — History filter + secret audit (fresh scratch clone)

Exit criterion: a local `/tmp/strawberry-app` checkout exists with a single
squashed commit, zero private paths, gitleaks clean.

### P1.1 — Bare clone strawberry into scratch

- **Owner:** Ekko.
- **Inputs:** post-P0.3 frozen strawberry main.
- **Outputs:** `/tmp/strawberry-filter.git` bare clone; working checkout at
  `/tmp/strawberry-app` derived from it.
- **Acceptance gate:** satisfies **P1-G1** (scratch clone exists at a
  non-live path; agent cwd not inside `/Users/duongntd99/Documents/Personal/strawberry`).
- **Rollback point:** ADR §6.3 row "After phase 1" — discard `/tmp/strawberry-app`.
- **Blockers:** P0.3.
- **Duong-in-loop:** no.

### P1.2 — Install `git-filter-repo`

- **Owner:** Ekko.
- **Inputs:** macOS host; `brew` available.
- **Outputs:** `git-filter-repo --version` succeeds; binary on PATH.
- **Acceptance gate:** version print is ≥ 2.38 — environmental
  prerequisite to **P1-G3** (squash must succeed).
- **Rollback point:** ADR §6.3 row "After phase 1" — none (environmental).
- **Blockers:** P1.1.
- **Duong-in-loop:** no.

### P1.3 — Squash to single commit + strip private paths

- **Owner:** Ekko.
- **Inputs:** `/tmp/strawberry-app` checkout; ADR §2.3 private-path list and
  §2.5 architecture triage table.
- **Outputs:** orphan-branch commit that contains only public-repo contents
  — ADR §5.1 squash method (`git checkout --orphan clean && git add -A &&
  git commit --reuse-message=HEAD && git branch -M clean main --force`).
  Private paths deleted per §2.3: `agents/`, `plans/`, `assessments/`,
  `secrets/`, `tasklist/`, `incidents/`, `design/`, `mcps/`, `strawberry-b14/`,
  `strawberry.pub/`, `apps/private-apps/` **except** `apps/private-apps/bee-worker`
  which **moves to public** (ADR §8 decision 6), root `CLAUDE.md`,
  `agents/evelynn/CLAUDE.md`.
- **Acceptance gate:** satisfies **P1-G2** (no private paths remain) and
  **P1-G3** (single squash commit); additionally
  `test -d /tmp/strawberry-app/apps/private-apps/bee-worker` succeeds
  (feeds **M-G14** at Phase 6 verification) and **P1-G7** (no `*.age` in
  scratch tree).
- **Rollback point:** ADR §6.3 row "After phase 1" — discard `/tmp/strawberry-app`.
- **Blockers:** P1.2.
- **Duong-in-loop:** no.

### P1.4 — Re-add sanitized `architecture/` files under `docs/architecture/`

- **Owner:** Ekko.
- **Inputs:** ADR §2.5 table (public / private / redact-and-publish triage
  per file); source copies live in the original strawberry checkout (not the
  scratch tree, since P1.3 deleted `architecture/`).
- **Outputs:** `docs/architecture/` in scratch tree containing:
  `deployment.md`, `firebase-storage-cors.md`, `git-workflow.md`,
  `pr-rules.md`, `testing.md`, `key-scripts.md`, `platform-parity.md`,
  `platform-split.md`, `system-overview.md`, pruned `README.md`. Each sanitized
  per §2.5 notes (strip references to specific agents / private tooling / ID
  numbers). Private-default files remain absent.
- **Acceptance gate:** satisfies **P1-G8** — 9 public files at
  `docs/architecture/` present (`deployment.md`, `git-workflow.md`,
  `pr-rules.md`, `testing.md`, `firebase-storage-cors.md`,
  `system-overview.md`, `platform-parity.md`, `platform-split.md`,
  `key-scripts.md`, `README.md` — note: 10 files counting README), 12
  private files absent; plus a `grep -r 'Ekko\|Caitlyn\|Ornn\|Azir\|Evelynn'
  docs/architecture/` returns zero lines (sanitization).
- **Rollback point:** ADR §6.3 row "After phase 1" — discard `/tmp/strawberry-app`.
- **Blockers:** P1.3.
- **Duong-in-loop:** no.

### P1.5 — Prune `scripts/` per §2.2

- **Owner:** Ekko.
- **Inputs:** ADR §2.2 path-level exception table.
- **Outputs:** scratch-tree `scripts/` contains only the public-only and
  dual-tracked entries: `scripts/deploy/**`, `scripts/mac/**`,
  `scripts/windows/**`, `scripts/gce/**`, `scripts/composite-deploy.sh`,
  `scripts/scaffold-app.sh`, `scripts/seed-app-registry.sh`,
  `scripts/health-check.sh`, `scripts/migrate-firestore-paths.sh`,
  `scripts/vps-setup.sh`, `scripts/deploy-discord-relay-vps.sh`,
  `scripts/setup-branch-protection.sh`, `scripts/verify-branch-protection.sh`,
  `scripts/setup-github-labels.sh`, `scripts/setup-discord-channels.sh`,
  `scripts/gh-audit-log.sh`, `scripts/gh-auth-guard.sh`,
  `scripts/install-hooks.sh`, `scripts/hooks/pre-commit-secrets-guard.sh`,
  `scripts/hooks/pre-commit-unit-tests.sh`, `scripts/hooks/pre-push-tdd.sh`,
  `scripts/hooks/pre-commit-artifact-guard.sh`. Private-only scripts from
  §2.2 (e.g. `safe-checkout.sh`, `plan-promote.sh`, `plan-*.sh`,
  `evelynn-memory-consolidate.sh`, `new-agent.sh`, etc.) are deleted.
- **Acceptance gate:** `ls scripts/` contains no private-row entries from
  §2.2; `scripts/hooks/` has the four public-tracked hook files; feeds
  **M-G13** (dual-tracked `pre-commit-secrets-guard.sh` byte-identical
  between repos at migration-complete).
- **Rollback point:** ADR §6.3 row "After phase 1" — discard `/tmp/strawberry-app`.
- **Blockers:** P1.3.
- **Duong-in-loop:** no.

### P1.6 — Tune public `.gitignore`

- **Owner:** Ekko.
- **Inputs:** existing strawberry `.gitignore`; ADR §2.4 dual-tracked
  treatment.
- **Outputs:** scratch-tree `.gitignore` pruned — drop agent/plan-specific
  lines (e.g. `agents/*/transcripts/*`, `tasklist/`, `plans/.drive-ids/`);
  keep code-level ignores plus explicit `secrets/`, `.env*`, `node_modules/`,
  build/coverage artefacts.
- **Acceptance gate:** a fresh `npm install` + `turbo run build --dry-run`
  at repo root produces no ignored-file warnings — feeds **P1-G6** (build
  topology). Note: `npm install` (not `npm ci`) is intended per **P1-G6**
  guidance until the `ulid` lockfile desync flagged in
  `assessments/2026-04-18-migration-dryrun.md` is refreshed.
- **Rollback point:** ADR §6.3 row "After phase 1" — discard.
- **Blockers:** P1.3.
- **Duong-in-loop:** no.

### P1.7 — Seed public-facing top-level docs

- **Owner:** Ekko.
- **Inputs:** ADR §2.1 row "README.md" (rewrite) and §2.4 contributor-docs
  row; §8 decision 2 (LICENSE: none — source-available, all rights reserved).
- **Outputs:** new public `README.md` at repo root explaining Dark Strawberry
  at a high level + run-locally snippet + "contributions not yet open" blurb;
  new `CONTRIBUTING.md` stub saying contributions not currently accepted; no
  `LICENSE` (source-available, all rights reserved per ADR §8 decision 2 —
  note this choice in README so it's unambiguous); no `CODE_OF_CONDUCT.md`
  yet (deferred with contributions). Top-level `package.json` has its
  `"private": true` flag removed (ADR §2.1).
- **Acceptance gate:** all three paths exist (README, CONTRIBUTING,
  top-level package.json without `private: true`); README does not reference
  any agent name — no dedicated P-G gate; supports the public-facing
  surface audited under **M-G1**.
- **Rollback point:** ADR §6.3 row "After phase 1" — discard.
- **Blockers:** P1.3, D5 (LICENSE confirmation).
- **Duong-in-loop:** confirmed in D5.

### P1.8 — Run gitleaks on filtered tree (current state)

- **Owner:** Ekko.
- **Inputs:** scratch tree after P1.3-P1.7; pre-existing allowlist from
  `agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md`
  (repo slug `Duongntd/strawberry` is a known false-positive under
  generic-api-key).
- **Outputs:** `/tmp/gitleaks.json` — report of current-state scan.
- **Acceptance gate:** satisfies **P1-G4** (`jq 'length' /tmp/gitleaks.json`
  returns `0` or only allowlisted entries). Any real finding → **STOP**
  and escalate to Evelynn + Duong; rotate before resuming. Feeds **M-G8**.
- **Rollback point:** ADR §6.3 row "After phase 1" — discard.
- **Blockers:** P1.3, P1.4, P1.5, P1.6, P1.7 (all must be committed in the
  single squash before the scan is meaningful).
- **Duong-in-loop:** on-exception (if real findings surface).

### P1.9 — Run gitleaks on reflog/history

- **Owner:** Ekko.
- **Inputs:** same scratch tree; ADR §4.2 step 5 command
  `gitleaks detect --source=. --log-opts="--all" --redact --report-path=/tmp/gitleaks-history.json`.
- **Outputs:** `/tmp/gitleaks-history.json`. Under the squash strategy (ADR
  §5.1) history is trivially one commit, but the command still checks the
  reflog and stash.
- **Acceptance gate:** satisfies **P1-G5** (`jq 'length'
  /tmp/gitleaks-history.json` returns `0`); on exception same STOP rule as
  P1.8. Feeds **M-G8**.
- **Rollback point:** ADR §6.3 row "After phase 1" — discard.
- **Blockers:** P1.8.
- **Duong-in-loop:** on-exception.

---

## Phase 2 — Parametrize repo references (scratch tree)

**Scope override (Duong, 2026-04-19):** Phase 2 is no longer a sed-rewrite
of `Duongntd/strawberry` → `harukainguyen1411/strawberry-app`. Instead,
every hardcoded slug in runtime code, workflows, scripts, and prompts is
replaced with an environment-sourced / config-constant / template-expansion
reference so that future repo renames cost a single env-var change per
environment rather than a sweep. A regression-guard hook (P2.Z) keeps
hardcoded slugs from re-entering.

Exit criterion: `grep -rE 'harukainguyen1411/strawberry|Duongntd/strawberry'
--include='*.ts' --include='*.tsx' --include='*.js' --include='*.sh'
--include='*.yml' --include='*.yaml'` in the scratch tree returns zero
hits outside a documented allowlist (README examples, architecture doc
illustrative snippets, test fixtures); `turbo run build --dry-run` passes;
the new guard hook is installed.

### P2.1 — Grep sweep for slug references (discovery only)

- **Owner:** Ekko.
- **Inputs:** scratch tree from Phase 1; ADR §6.2 expected hit list;
  `assessments/2026-04-18-migration-dryrun.md` §3 17-file enumeration.
- **Outputs:** complete grep report (path + line number + snippet) saved
  to `/tmp/migration-slug-audit.md`. Covers both `Duongntd/strawberry`
  and any pre-existing `harukainguyen1411/strawberry-app` literal that
  slipped in during earlier drafts. Extensions covered:
  `*.sh`, `*.ts`, `*.tsx`, `*.js`, `*.yml`, `*.yaml`, `*.md`, `*.json`.
  Each hit is categorised per dispatch below (runtime TS/JS, workflow,
  shell, LLM prompt, doc, issue-URL) so Viktor's handoff package
  enumerates which task (P2.P1-P2.P6) each hit goes to.
- **Acceptance gate:** report exists; every file in the dry-run §3
  17-file list appears in the report with a category; precondition to
  **P2-G1** (zero hits after parametrize), **P2-G2** (17-file subset
  cleared).
- **Rollback point:** ADR §6.3 row "After phase 2" — discard report.
- **Blockers:** P1.9.
- **Duong-in-loop:** no.

### P2.P1 — Parametrize runtime TypeScript / JavaScript

- **Owner:** Viktor.
- **Inputs:** P2.1 report rows tagged `runtime-ts`; specifically
  `apps/myapps/functions/src/beeIntake.ts`,
  `apps/myapps/functions/src/index.ts`,
  `apps/private-apps/bee-worker/src/config.ts`, plus any additional hits
  from the report.
- **Outputs:** each hit reads the repo slug from `process.env.GITHUB_REPOSITORY`
  at runtime. For Cloud Functions: use `process.env.GITHUB_REPOSITORY`
  (set at deploy time via `firebase functions:config:set`, or read from
  Cloud Functions' implicit env when deployed via GitHub Actions —
  confirm the actual mechanism with Jayce/Vi before finalising; the
  contract is that the value is **never** a string literal in source).
  For bee-worker: `process.env.GITHUB_REPOSITORY` directly (it's a
  standard GitHub Actions runner env — bee-worker already pulls env in
  its config bootstrap). Each app has a **single** config constant in
  **one** file (`config.ts` / equivalent) that exports the value; other
  modules import from that constant — no duplication. Commit message:
  `chore: parametrize repo slug for runtime TypeScript surfaces`.
- **Acceptance gate:** `grep -rln 'harukainguyen1411/strawberry\|Duongntd/strawberry'
  apps/ --include='*.ts' --include='*.tsx' --include='*.js'` returns
  zero hits; each affected app has exactly one config-constant
  declaration site; feeds **P2-G1**, **P2-G2** (runtime-TS subset of
  the 17-file list cleared).
- **Rollback point:** ADR §6.3 row "After phase 2" — `git reset --hard
  HEAD~1`.
- **Blockers:** P2.1.
- **Duong-in-loop:** no.

### P2.P2 — Parametrize GitHub workflow YAML

- **Owner:** Viktor.
- **Inputs:** P2.1 report rows tagged `workflow`; specifically
  `.github/workflows/landing-prod-deploy.yml` and any other workflow
  files flagged.
- **Outputs:** every workflow reference to the repo slug uses
  `${{ github.repository }}` template expansion — no literal slugs in
  the YAML. Commit message: `chore: parametrize repo slug in GitHub
  workflows`.
- **Acceptance gate:** `grep -rln 'harukainguyen1411/strawberry\|Duongntd/strawberry'
  .github/workflows/` returns zero hits; every flagged workflow now
  resolves its slug via the GitHub context; feeds **P2-G1**.
- **Rollback point:** ADR §6.3 row "After phase 2" — `git reset --hard
  HEAD~1`.
- **Blockers:** P2.1.
- **Duong-in-loop:** no.

### P2.P3 — Parametrize shell scripts

- **Owner:** Viktor.
- **Inputs:** P2.1 report rows tagged `shell`; specifically
  `scripts/setup-branch-protection.sh`,
  `scripts/verify-branch-protection.sh`,
  `scripts/gce/setup-coder-vm.sh`, `scripts/gce/setup-bee-vm.sh`, plus
  any other hits.
- **Outputs:** each script derives the slug from `$1` positional arg,
  falling back to `git remote get-url origin` (parse `owner/name` from
  the URL) when no arg given. Usage string updated to document the arg.
  Commit message: `chore: parametrize repo slug across shell scripts`.
- **Acceptance gate:** `grep -rln 'harukainguyen1411/strawberry\|Duongntd/strawberry'
  scripts/ --include='*.sh'` returns zero hits; each script's `-h`/`--help`
  (or usage line) documents the slug arg; each script continues to pass
  `shellcheck`; feeds **P2-G1**.
- **Rollback point:** ADR §6.3 row "After phase 2" — `git reset --hard
  HEAD~1`.
- **Blockers:** P2.1.
- **Duong-in-loop:** no.

### P2.P4 — Placeholder-ize LLM prompts

- **Owner:** Viktor.
- **Inputs:** P2.1 report rows tagged `prompt`; specifically
  `apps/coder-worker/system-prompt.md` (R14 critical).
- **Outputs:** every slug literal replaced with `{{REPO_SLUG}}` template
  placeholder; the coder-worker runtime performs the substitution from
  env before the prompt is sent to the model. Substitution point must
  be documented in `apps/coder-worker/README.md` (or equivalent). Commit
  message: `chore: placeholder-ize repo slug in coder-worker prompt`.
- **Acceptance gate:** `grep -c 'Duongntd/strawberry\|harukainguyen1411/strawberry'
  apps/coder-worker/system-prompt.md` returns 0;
  `grep -c '{{REPO_SLUG}}' apps/coder-worker/system-prompt.md` returns
  ≥ 1; the substitution site in coder-worker code exists and is
  tested (follow-on work once public — not blocking this task);
  feeds **P2-G1**, mitigates R14.
- **Rollback point:** ADR §6.3 row "After phase 2" — `git reset --hard
  HEAD~1`.
- **Blockers:** P2.1.
- **Duong-in-loop:** no.

### P2.P5 — Env-parametrize Discord-relay issue URL

- **Owner:** Viktor.
- **Inputs:** P2.1 report row for `apps/discord-relay/src/discord-bot.ts`
  (issue-filing URL — R8).
- **Outputs:** the issue URL is composed from `process.env.GITHUB_REPOSITORY`
  at runtime. If the relay already has a config module (likely), the
  slug lives there; otherwise introduce one. Commit message:
  `chore: env-source repo slug in discord-relay issue URL`.
- **Acceptance gate:** `grep -c 'Duongntd/strawberry\|harukainguyen1411/strawberry'
  apps/discord-relay/src/` returns 0; the bot still compiles
  (`tsc --noEmit` clean inside its workspace); mitigates R8; feeds
  **P2-G1**.
- **Rollback point:** ADR §6.3 row "After phase 2" — `git reset --hard
  HEAD~1`.
- **Blockers:** P2.1.
- **Duong-in-loop:** no.

### P2.P6 — Audit docs for illustrative-only slug mentions

- **Owner:** Viktor.
- **Inputs:** P2.1 report rows tagged `doc` (README, `docs/architecture/*.md`).
- **Outputs:** each doc mention either (a) replaced with
  `owner/repo`-style placeholder or `$GITHUB_REPOSITORY` env-example
  form, or (b) kept as an explicit illustrative example and added to
  `scripts/hooks/check-no-hardcoded-slugs.sh` allowlist with a rationale
  comment. Plan-permalink mentions in `docs/architecture/*.md` (per ADR
  §7 convention, private-strawberry plan URLs are allowed) are kept in
  full `github.com/Duongntd/strawberry/blob/main/plans/...` form and
  allowlisted. Commit message: `chore: audit doc slug mentions and
  register illustrative allowlist`.
- **Acceptance gate:** every remaining slug mention in README /
  `docs/**/*.md` is either placeholder form OR an explicit permalink to
  a plan file in private strawberry OR listed in the guard hook's
  allowlist file; feeds **P2-G1**, **P2-G4** (permalink-form preserved).
- **Rollback point:** ADR §6.3 row "After phase 2" — `git reset --hard
  HEAD~1`.
- **Blockers:** P2.1.
- **Duong-in-loop:** no.

### P2.Z — Add regression-guard hook

- **Owner:** Viktor.
- **Inputs:** none beyond ADR §2.2 hook dual-tracking note and the per-
  extension guidance above.
- **Outputs:** new `scripts/hooks/check-no-hardcoded-slugs.sh` — POSIX
  bash, runs on pre-commit (and as a CI lint step), greps for literal
  `harukainguyen1411/strawberry` and `Duongntd/strawberry` across
  `*.ts`, `*.tsx`, `*.js`, `*.yml`, `*.yaml`, `*.sh`; fails the commit
  if any hit is found **outside** the allowlist file
  `scripts/hooks/slug-allowlist.txt` (one path-or-path-glob per line,
  with rationale in a comment — populated by P2.P6 docs pass with
  plan-permalink entries + README example forms). `scripts/install-hooks.sh`
  is updated to wire the new hook into the pre-commit bundle alongside
  the secrets-guard and unit-test hooks. CI step added to
  `.github/workflows/` (cheapest landing: a lint job in an existing
  workflow — Ekko can pick the specific workflow file during dispatch).
  Commit message: `feat: hardcoded-slug regression guard + install-hooks
  wiring`.
- **Acceptance gate:**
  - `scripts/hooks/check-no-hardcoded-slugs.sh` exists, is executable,
    passes `shellcheck`, and is POSIX-portable (Rule 10).
  - Running it from the scratch-tree root after P2.P1-P2.P6 land exits 0
    (all hits handled or allowlisted).
  - A synthetic smoke — temporarily insert a literal slug into a
    scratch-tree `.ts` file, run the hook, confirm exit ≠ 0; remove the
    seed. Documented in the task commit body.
  - `scripts/install-hooks.sh` invocation attaches the hook into the
    pre-commit chain (`.git/hooks/pre-commit` includes a dispatch to
    the new script).
  - CI lint step wired in an existing workflow so the guard runs on
    every PR.
- **Rollback point:** ADR §6.3 row "After phase 2" — revert the commit;
  the guard is additive and its absence doesn't break existing behaviour.
- **Blockers:** P2.P1, P2.P2, P2.P3, P2.P4, P2.P5, P2.P6 (guard must
  pass over the fully-parametrized tree, so it lands after all
  parametrization tasks).
- **Duong-in-loop:** no.

### P2.3 — Cross-grep secondary patterns

- **Owner:** Ekko.
- **Inputs:** ADR §4.3 step 4 — also search for `strawberry.git` and bare
  `strawberry` in URL contexts (`github.com/.../strawberry`,
  `clone .../strawberry.git`) that wouldn't be caught by the
  `owner/repo`-shaped grep in P2.1.
- **Outputs:** secondary grep report; any additional hits handed to
  Viktor for treatment via the appropriate P2.P* category (e.g.
  `strawberry.git` in a script → P2.P3 re-open).
- **Acceptance gate:** satisfies **P2-G3** (no `github.com/Duongntd/strawberry.git`
  URLs remain in runtime code / scripts / workflows) and **P2-G4**
  (any residual `strawberry` mention in docs is in plan-permalink form
  per §7 convention, or is allowlisted in the P2.Z guard).
- **Rollback point:** ADR §6.3 row "After phase 2" — discard any
  follow-up Viktor commits, redo.
- **Blockers:** P2.Z.
- **Duong-in-loop:** no.

### P2.4 — Verify build topology post-parametrize

- **Owner:** Ekko.
- **Inputs:** scratch tree after P2.3.
- **Outputs:** `npm install` succeeds; `turbo run build --dry-run`
  succeeds; `node_modules/` restored for smoke (gitignored). Confirms
  that env-sourcing the slug didn't introduce an import cycle or a
  missing config export in any app.
- **Acceptance gate:** satisfies **P1-G6** (build topology) re-verified
  post-parametrize and **P2-G6** (`turbo run build --dry-run` exits 0).
  Additionally: `scripts/hooks/check-no-hardcoded-slugs.sh` exits 0 when
  run from scratch-tree root (P2.Z regression).
- **Rollback point:** ADR §6.3 row "After phase 2" — if build breaks,
  inspect which parametrize change shadowed an import; amend the
  relevant P2.P* commit.
- **Blockers:** P2.3.
- **Duong-in-loop:** no.

### P2.5 — Fix `.github/branch-protection.json` template

- **Owner:** Ekko.
- **Inputs:** existing `branch-protection.json` (required contexts:
  `validate-scope`, `preview` — only 2); target state per
  `plans/approved/2026-04-17-branch-protection-enforcement.md` §1 (5
  required contexts: `validate-scope`, `preview`, `tdd-gate`,
  `unit-tests`, `e2e`, `qa`); R15 in ADR §3.
- **Outputs:** updated `.github/branch-protection.json` in scratch tree
  with the 5 required contexts, `strict: true`, 1 required review,
  `enforce_admins` per that plan. Single commit: `chore: align
  branch-protection template with enforcement plan §1`.
- **Acceptance gate:** precondition to **P3-G5** (stored template) and
  **P3-G6** (live rule on `main`); the 5 contexts from the enforcement
  plan — `Playwright E2E`, `QA report present (UI PRs)`,
  `regression-test check`, `unit-tests`, `xfail-first check` — must all
  be declared with `strict: true`, `required_approving_review_count: 1`,
  `enforce_admins: true`, `require_last_push_approval: true`. This is a
  **hard Phase 3 blocker** — per R15, do not re-apply protection until
  fixed.
- **Rollback point:** ADR §6.3 row "After phase 2" — `git reset --hard
  HEAD~1`.
- **Blockers:** P2.4.
- **Duong-in-loop:** no.

---

## Phase 3 — Push, re-provision, re-protect (strawberry-app)

Exit criterion: strawberry-app has one green workflow run across all required
checks; all 17 secrets are set; branch protection matches the enforcement
plan; Firebase GitHub App is bound to strawberry-app.

### P3.1 — Push scratch tree to `harukainguyen1411/strawberry-app`

- **Owner:** Viktor.
- **Inputs:** post-P2.5 scratch tree; empty remote at
  `github.com/harukainguyen1411/strawberry-app` (D1).
- **Outputs:** `git remote add origin https://github.com/harukainguyen1411/strawberry-app.git
  && git push -u origin main` succeeds; remote main SHA matches scratch-tree
  main SHA.
- **Acceptance gate:** satisfies **P3-G1** (`gh repo view` returns
  `visibility: PUBLIC`) and **P3-G2** (`main` SHA on strawberry-app
  equals scratch-tree HEAD SHA). Feeds **M-G1**.
- **Rollback point:** ADR §6.3 row "After phase 3 step 1-3" — delete the
  remote repo (Duong via Console).
- **Blockers:** P2.5, D1.
- **Duong-in-loop:** only for rollback (repo deletion).

### P3.2 — Re-provision the 17 GitHub secrets

- **Owner:** Viktor (orchestration) + Duong (secret entry per D6).
- **Inputs:** ADR §6.1 secret enumeration table.
- **Outputs:** each of the 17 secrets set in
  `harukainguyen1411/strawberry-app` via `gh secret set <NAME> --repo
  harukainguyen1411/strawberry-app --body-file -` with values pasted once by
  Duong from local file / Firebase Console / GCP IAM / re-mint. Explicit set
  covers: `AGE_KEY`, `AGENT_GITHUB_TOKEN`, `BOT_WEBHOOK_SECRET`,
  `CF_ACCOUNT_ID`, `CF_API_TOKEN`, `FIREBASE_SERVICE_ACCOUNT`,
  `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`, `GCP_SA_KEY_PROD`,
  `GCP_SA_KEY_STAGING`, and 7× `VITE_FIREBASE_*`. `BEE_SISTER_UIDS`
  verified with Duong in-session (ADR §4.4 step 2 note).
- **Acceptance gate:** satisfies **P3-G3** (17 secret names present per
  §6.1) and **P3-G4** (every secret's `updatedAt` ≥ Phase 3 start
  timestamp — rules out stale copies). Feeds **M-G2**.
- **Rollback point:** ADR §6.3 row "After phase 3 step 1-3" — harmless if
  new repo deleted.
- **Blockers:** P3.1, D6.
- **Duong-in-loop:** YES (value entry).

### P3.3 — Re-mint fine-grained PAT + encrypt

- **Owner:** Viktor.
- **Inputs:** `harukainguyen1411` account (Duong action via Console to mint);
  repo scope = strawberry-app only.
- **Outputs:** new PAT minted by Duong and handed to Viktor via
  `tools/decrypt.sh`-compatible flow; Viktor re-encrypts at
  `secrets/encrypted/github-triage-pat.txt.age` in **private strawberry**
  (Rule 6 — never uses raw `age -d`, never reads decrypted value into
  context). Old PAT invalidated. Active agent sessions using the token are
  notified (via Evelynn inbox) to refresh.
- **Acceptance gate:** satisfies **P3-G11** (PAT ciphertext committed to
  private strawberry at `secrets/encrypted/github-triage-pat.txt.age`
  with a commit SHA dated on/after migration day). Plus a smoke that
  `tools/decrypt.sh` returns non-empty and a test `gh api /user` using
  the new token succeeds (executed only in a child process, never logged).
- **Rollback point:** ADR §6.3 row "After phase 3 step 1-3" — revoke new
  PAT via Console, restore old PAT from backup ciphertext.
- **Blockers:** P3.1.
- **Duong-in-loop:** YES (PAT mint is a GitHub Console action).

### P3.4 — Apply branch protection to strawberry-app

- **Owner:** Viktor.
- **Inputs:** pushed `.github/branch-protection.json` with 5 required
  contexts (from P2.5); existing `scripts/setup-branch-protection.sh` in the
  pushed tree; ADR §4.4 step 4; R15.
- **Outputs:** `scripts/setup-branch-protection.sh harukainguyen1411/strawberry-app`
  executed against new remote; `scripts/verify-branch-protection.sh`
  confirms state matches.
- **Acceptance gate:** satisfies **P3-G5** (stored template matches),
  **P3-G6** (live rule on `main` matches the enforcement-plan §1
  5-context spec with `strict: true`, 1 review, `enforce_admins: true`,
  `require_last_push_approval: true`), and **P3-G7**
  (`verify-branch-protection.sh` exits 0). Feeds **M-G3**.
- **Rollback point:** ADR §6.3 row "After phase 3 step 4-6" — harmless if
  new repo deleted.
- **Blockers:** P3.1, P2.5.
- **Duong-in-loop:** no.

### P3.5 — Apply GitHub labels

- **Owner:** Viktor.
- **Inputs:** pushed `scripts/setup-github-labels.sh`.
- **Outputs:** `./scripts/setup-github-labels.sh
  harukainguyen1411/strawberry-app` (or equivalent invocation) idempotently
  seeds the label set.
- **Acceptance gate:** satisfies **P3-G8** (label count on strawberry-app
  ≥ label count on strawberry).
- **Rollback point:** ADR §6.3 row "After phase 3 step 4-6" — harmless.
- **Blockers:** P3.1.
- **Duong-in-loop:** no.

### P3.6 — Verify Dependabot config wired

- **Owner:** Viktor.
- **Inputs:** pushed `.github/dependabot.yml`; D3 (Dependabot alerts +
  security updates enabled by Duong).
- **Outputs:** `gh api /repos/harukainguyen1411/strawberry-app/vulnerability-alerts`
  returns 204 (enabled); Dependabot's first ecosystem scan visible in the
  Insights tab within 24 h.
- **Acceptance gate:** vulnerability-alerts check returns 204; no
  misconfig warnings in Dependabot tab — no dedicated P-G gate (R9
  accepted risk per ADR). Verified as part of Phase 3 operational
  readiness.
- **Rollback point:** ADR §6.3 row "After phase 3 step 4-6" — harmless.
- **Blockers:** P3.1, D3.
- **Duong-in-loop:** D3 preflight.

### P3.7 — Firebase GitHub App binding cutover (Duong action)

- **Owner:** Duong (via Viktor coordination).
- **Inputs:** Firebase Console access to Dark Strawberry project; D4
  preflight already installed the app on strawberry-app; ADR §4.4 step 7;
  R5.
- **Outputs:** App disconnected from `Duongntd/strawberry`; confirmed
  connected to `harukainguyen1411/strawberry-app`.
- **Acceptance gate:** satisfies **P3-G9** (Firebase app installed on
  strawberry-app) AND **P3-G10** (Firebase app NOT installed on
  strawberry — prevents dual-deploy). Feeds **M-G5**.
- **Rollback point:** ADR §6.3 row "After phase 3 step 7" — re-bind to
  strawberry via Console.
- **Blockers:** P3.1, D4, D8.
- **Duong-in-loop:** YES.

### P3.8 — First workflow run (no-op bump)

- **Owner:** Viktor.
- **Inputs:** strawberry-app main after P3.2-P3.7.
- **Outputs:** trivial PR bumping `version` in root `package.json`; PR run
  exercises all required status checks; merged via squash-merge after Kayn +
  Senna + Lucian review (or one-time admin-merge per ADR §8 decision 5 if CI minutes
  still 0 — this is the only sanctioned admin merge post-cutover and
  requires D7 sign-off + incident log). Staging deploy runs on merge and is
  green.
- **Acceptance gate:** satisfies **P3-G12** (first workflow run green
  across all 5 required contexts) and **P3-G13** (one green staging
  deploy from strawberry-app). Feeds **M-G1**, **M-G2**, **M-G6**. If
  red → **STOP** and trigger ADR §6.3 row "After phase 3 step 8 red"
  rollback.
- **Rollback point:** ADR §6.3 row "After phase 3 step 8 red" — revert
  Firebase binding (undo P3.7) and leave strawberry canonical.
- **Blockers:** P3.2, P3.3, P3.4, P3.5, P3.6, P3.7, D7.
- **Duong-in-loop:** YES (red/green sign-off — D7).

### P3.9 — Green prod deploy from strawberry-app main

- **Owner:** Viktor.
- **Inputs:** post-P3.8 staging-green main; release-please automation or
  trivial prod trigger depending on current workflow shape.
- **Outputs:** one green prod deploy of any app in the monorepo from
  strawberry-app main, proving the prod binding path works end-to-end.
- **Acceptance gate:** a green prod-deploy workflow run exists against
  `main` — directly feeds **P6-G2** (prod green confirmed at Phase 6
  stability window) and **M-G6** (one green prod deploy from
  strawberry-app main).
- **Rollback point:** same as P3.8 — revert Firebase binding and restore
  strawberry as canonical deployer.
- **Blockers:** P3.8.
- **Duong-in-loop:** on-exception.

---

## Phase 4 — Replay open non-green PRs

Exit criterion: every PR that was open in strawberry at migration time (draft,
red, or unmerged-but-expected) has either been re-opened in strawberry-app or
closed with a migration comment. Dependabot PRs are not replayed.

### P4.1 — Compute replay set

- **Owner:** Ekko.
- **Inputs:** P0.1 enumerated queue; post-P0.2 state (merged PRs removed
  from consideration).
- **Outputs:** list of PR numbers that remained open in strawberry after
  Phase 0 (draft / red / non-approved). Written to the same
  `assessments/2026-04-19-migration-pr-queue.md` file under a "Replay"
  section.
- **Acceptance gate:** list exists; each entry has branch name, head SHA,
  original author-of-record — precondition to **P4-G1** mapping file.
- **Rollback point:** ADR §6.3 row "After phase 4" — close newly-opened
  PRs in strawberry-app; leave strawberry PRs as-was.
- **Blockers:** P0.2, P3.9.
- **Duong-in-loop:** no.

### P4.2 — Push each replay branch to strawberry-app

- **Owner:** Ekko.
- **Inputs:** P4.1 replay list.
- **Outputs:** for each branch: checked out in a worktree (via
  `scripts/safe-checkout.sh` — never raw `git checkout`, per Rule 3);
  pushed to `origin` on strawberry-app with the same branch name; no force
  push to main.
- **Acceptance gate:** `gh api /repos/harukainguyen1411/strawberry-app/branches`
  lists each replayed branch — precondition to **P4-G1** and **P4-G3**
  (original author attribution preserved via co-author trailers).
- **Rollback point:** ADR §6.3 row "After phase 4" — delete the replayed
  branches via `gh api`.
- **Blockers:** P4.1.
- **Duong-in-loop:** no.

### P4.3 — Open replay PRs and cross-link

- **Owner:** Ekko.
- **Inputs:** pushed branches from P4.2; original PR titles/bodies from
  strawberry.
- **Outputs:** new PRs opened in strawberry-app via `gh pr create`, each
  PR body citing the original strawberry PR number and linking to the
  migration plan (`plans/approved/2026-04-19-public-app-repo-migration.md`).
  The original strawberry PR is closed (not merged) with the migration
  comment from ADR §4.5 step 1d. Reviewers: Kayn + Senna + Lucian per team spec.
- **Acceptance gate:** satisfies **P4-G1** (mapping file
  `tasklist/migration-pr-map.md` covers every open-at-Phase-0-start
  strawberry PR), **P4-G2** (each closed strawberry PR has migration
  comment referencing strawberry-app or the plan), **P4-G3** (author
  attribution preserved), and **P4-G5** (no code-path PR remains open on
  strawberry). Skip Dependabot PRs per **P4-G4**. Feeds **M-G7** and
  **M-G15**.
- **Rollback point:** ADR §6.3 row "After phase 4" — close new PRs,
  re-open old ones in strawberry.
- **Blockers:** P4.2.
- **Duong-in-loop:** no (unless review approval needed).

---

## Phase 5 — Agent and plan update (private strawberry)

Exit criterion: agent memory, core CLAUDE.md files, and high-traffic
architecture docs reference strawberry-app for code and strawberry for plans
with no broken post-migration PR links.

### P5.1 — Rewrite post-migration PR links in agent memory

- **Owner:** Viktor.
- **Inputs:** private strawberry main; ADR §4.6 step 1.
- **Outputs:** across all `agents/*/memory/MEMORY.md`, find/replace:
  - `github.com/Duongntd/strawberry/pull` →
    `github.com/harukainguyen1411/strawberry-app/pull`
  - `Duongntd/strawberry` (in code context only — preserve historical
    narrative)
    → `harukainguyen1411/strawberry-app`
  Transcripts under `agents/*/transcripts/` are **not** touched (they are
  historical records per ADR §4.6 step 1).
- **Acceptance gate:** satisfies **P5-G1** (no post-migration
  `github.com/Duongntd/strawberry/pull/` references; any surviving match
  is historical and pre-Phase-0-cut-line) and **P5-G2** (code-context
  slugs updated; transcripts untouched per spec). Feeds **M-G9**.
- **Rollback point:** ADR §6.3 row "After phase 5" — revert the commit.
- **Blockers:** P3.9 (can't reference strawberry-app until it's live).
- **Duong-in-loop:** no.

### P5.2 — Update core CLAUDE.md files + architecture docs

- **Owner:** Viktor.
- **Inputs:** root `CLAUDE.md`, `agents/evelynn/CLAUDE.md`,
  `architecture/git-workflow.md`, `architecture/pr-rules.md`.
- **Outputs:** each file explicitly names both repos — strawberry
  (agent-infra, private) and strawberry-app (code, public) — with the
  relationship described. Commit message:
  `chore: azir migration — name both repos explicitly across core rules`.
- **Acceptance gate:** satisfies **P5-G4** — each of the four files
  references both repos and both the "agent-infra" / code-repo roles.
  Feeds **M-G9**.
- **Rollback point:** ADR §6.3 row "After phase 5" — revert the commit.
- **Blockers:** P5.1.
- **Duong-in-loop:** no.

### P5.3 — Add `architecture/cross-repo-workflow.md`

- **Owner:** Viktor.
- **Inputs:** ADR §7 cross-repo conventions.
- **Outputs:** new `architecture/cross-repo-workflow.md` in private
  strawberry documenting all 8 conventions from §7. Same commit as P5.2 or
  immediately after.
- **Acceptance gate:** satisfies **P5-G3** (`cross-repo-workflow.md`
  exists with ≥ 5 mentions of `strawberry-app`) and **P5-G7**
  (`architecture/README.md` indexes the new doc). Feeds **M-G10**.
- **Rollback point:** ADR §6.3 row "After phase 5" — revert.
- **Blockers:** P5.2.
- **Duong-in-loop:** no.

### P5.4 — Audit plan-promote script commentary

- **Owner:** Viktor.
- **Inputs:** `scripts/plan-promote.sh`, `scripts/plan-publish.sh`,
  `scripts/plan-unpublish.sh`, `scripts/_lib_gdoc.sh`; ADR §4.6 step 4.
- **Outputs:** any path-specific logic referencing `apps/` is updated to
  note that apps live in strawberry-app now (comment-only; these scripts
  stay in private strawberry per §2.2).
- **Acceptance gate:** satisfies **P5-G6** (`bash -n
  scripts/plan-promote.sh` exits 0); no functional change (comment-only
  edits); `shellcheck` still passes.
- **Rollback point:** ADR §6.3 row "After phase 5" — revert.
- **Blockers:** P5.3.
- **Duong-in-loop:** no.

### P5.5 — Commit the migration batch to private strawberry

- **Owner:** Viktor.
- **Inputs:** P5.1-P5.4 outputs staged.
- **Outputs:** single commit
  `chore: azir migration — update agent memory and architecture docs for
  two-repo split` pushed to strawberry main (or via PR per §4 — plans go
  directly to main, this is doc-only so it can too; confirm with Evelynn
  if unsure).
- **Acceptance gate:** satisfies **P5-G5** — `git log --oneline
  --grep="migration — update agent memory"` returns ≥ 1 commit authored
  on/after migration day.
- **Rollback point:** ADR §6.3 row "After phase 5" — revert the commit.
- **Blockers:** P5.4.
- **Duong-in-loop:** no.

---

## Phase 6 — Archive old code paths in strawberry

Exit criterion: after 7 days of stable strawberry-app operation, code paths
are purged from strawberry; strawberry's `main` remains a readable archival
ref back to the migration-freeze SHA. ADR §4.7 decision 2: do **not** rename
strawberry.

### P6.0 — 7-day stability window

- **Owner:** Duong (via Evelynn coordination).
- **Inputs:** P3.9 prod-deploy-green timestamp.
- **Outputs:** 7-day wall-clock watch; Evelynn maintains a lightweight
  status log. No red prod deploys in window, no migration rollbacks
  triggered.
- **Acceptance gate:** satisfies **P6-G1** (≥ 7 × 86400 seconds since
  Phase 3 cutover timestamp in Caitlyn's journal), **P6-G2** (≥ 1 green
  staging + ≥ 1 green prod + 0 failures in window), **P6-G3** (no
  rollback workflow invocations), **P6-G4** (no unresolved
  strawberry-app incident reports). Duong explicit go-ahead (D9).
- **Rollback point:** ADR §6.3 row "After phase 6" — Phase 6 is the only
  pseudo-irreversible step; this watch is the final stop before it.
- **Blockers:** P3.9.
- **Duong-in-loop:** YES (D9).

### P6.1 — Purge migrated code paths from strawberry

- **Owner:** Viktor.
- **Inputs:** strawberry main; migration freeze-SHA from P0.3 as the
  reference "last commit with full code"; ADR §4.7 step 3 disposition.
- **Outputs:** single commit
  `chore: azir — purge code paths migrated to strawberry-app` deleting
  `apps/`, `dashboards/`, `.github/workflows/`, and the top-level build
  config files that moved to strawberry-app (per §2.1 —
  `turbo.json`, `tsconfig.json`, `eslint*`, `firestore.rules`,
  `firestore.indexes.json`, `release-please-config.json`,
  `ecosystem.config.js`, top-level `package.json` / `package-lock.json`
  — confirm each with §2.1 table before deletion). `scripts/` prunes to
  the private-only set per §2.2 (remove public-migrated scripts, keep
  plan-lifecycle + agent tooling). Pushed directly to strawberry main
  (plans / non-code commits go direct per Rule 4).
- **Acceptance gate:** satisfies **P6-G5** (`purge code paths migrated to
  strawberry-app` commit exists), **P6-G6** (`apps/`, `dashboards/`,
  `.github/workflows/`, `turbo.json`, `firestore.rules`,
  `ecosystem.config.js` all absent from strawberry), **P6-G7** (post-purge
  strawberry main still green), and **M-G17** (agent-infra paths
  preserved: `agents/`, `plans/`, `assessments/`, `secrets/`, `tasklist/`,
  `incidents/`, `design/`, `mcps/`). Feeds **M-G11** (Duong can merge a
  trivial PR in strawberry-app without hitting CI limits — the core
  reason this plan exists) and **M-G14** (bee-worker lives in
  strawberry-app post-purge).
- **Rollback point:** ADR §6.3 row "After phase 6" — restore purged paths
  from the pre-purge commit via `git revert`. Only Phase 6 is
  pseudo-irreversible after 7 more days of operation.
- **Blockers:** P6.0, D9.
- **Duong-in-loop:** YES (D9).

### P6.2 — Update strawberry README + archival pointer

- **Owner:** Viktor.
- **Inputs:** post-P6.1 strawberry main.
- **Outputs:** top-level `README.md` in strawberry (if any) now describes
  strawberry as the private agent-infra repo only, with a pointer to
  strawberry-app for code. If no README exists, create one.
- **Acceptance gate:** README (if present) names both repos and their
  responsibilities — supporting **P5-G4**-style distinction carried into
  strawberry's top-level surface.
- **Rollback point:** ADR §6.3 row "After phase 6" — revert commit.
- **Blockers:** P6.1.
- **Duong-in-loop:** no.

---

## Dispatch order — parallelism and critical path

### Strictly sequential spine (critical path)

```
P0.0 → P0.1 → P0.2 → P0.3
  → P1.1 → P1.2 → P1.3
      ↓
    { P1.4, P1.5, P1.6, P1.7 }   (parallelisable — Window A)
      ↓
    P1.8 → P1.9
      ↓
    P2.1
      ↓
    { P2.P1, P2.P2, P2.P3, P2.P4, P2.P5, P2.P6 }   (parallelisable — Window B)
      ↓
    P2.Z → P2.3 → P2.4 → P2.5
      ↓
    P3.1 → { P3.2, P3.3, P3.4, P3.5, P3.6 }   (parallelisable — Window C)
      ↓
    P3.7 → P3.8 → P3.9
      ↓
    P4.1 → P4.2 → P4.3
      ↓
    P5.1 → P5.2 → P5.3 → P5.4 → P5.5
      ↓
    P6.0 → P6.1 → P6.2
```

### Parallel windows

**Window A — Phase 1 private-path cleanup (after P1.3 lands on scratch tree):**
- `P1.4` (re-add sanitized architecture/)
- `P1.5` (prune scripts/)
- `P1.6` (tune .gitignore)
- `P1.7` (seed public README + CONTRIBUTING)

All four touch disjoint paths in the scratch tree, all land as independent
commits on the squashed branch before P1.8 runs gitleaks. Single-owner
(Ekko), tasks can be batched in any order.

**Window B — Phase 2 parametrization fan-out (after P2.1 report hands off
to Viktor):**
- `P2.P1` — runtime TypeScript / JavaScript (myapps functions + bee-worker)
- `P2.P2` — GitHub workflow YAML
- `P2.P3` — shell scripts (branch-protection + GCE VM bootstrap scripts)
- `P2.P4` — LLM prompts (coder-worker system-prompt)
- `P2.P5` — discord-relay issue URL
- `P2.P6` — doc audit + allowlist population

All six touch disjoint path categories, all owned by Viktor. Each is a
small commit; they can land as six separate commits (preferred — easier
to review) or as one batched PR (acceptable if the commits are
logically separated in the PR). Must converge before P2.Z (guard hook)
runs against the full tree. Ekko stays out of Window B — keeps slug
rewrites from getting entangled with history-filter commits.

**Window C — Phase 3 re-protection after push (after P3.1 succeeds):**
- `P3.2` (secrets) — Duong-blocking, takes longest
- `P3.3` (PAT reissue) — Duong-blocking in parallel
- `P3.4` (branch protection) — independent, needs P2.5's template fix
- `P3.5` (labels) — independent
- `P3.6` (Dependabot verification) — independent, needs D3 preflight

Viktor can fan out — run P3.2 + P3.3 with Duong over a shared session,
while P3.4, P3.5, P3.6 run as automated script calls in the same terminal.
All must converge before P3.7 Firebase cutover.

**Window D — Phase 5 doc updates (after P3.9 strawberry-app is live):**
- `P5.1` (agent memory rewrites)
- `P5.2` (core CLAUDE.md + architecture/*)
- `P5.3` (new cross-repo doc)
- `P5.4` (plan-promote commentary)

These touch disjoint files in private strawberry. Viktor can land them as
one combined PR/commit (P5.5) — they're grouped for batching, not ordered
by dependency.

### Not parallelisable — hard serial points

- **P0.2 → P0.3 → P1.1** is hard serial: the freeze SHA is the input to
  the bare clone.
- **P2.1 → Window B** is hard serial: Viktor needs the categorized grep
  report before dispatching the six parametrization sub-tasks.
- **Window B → P2.Z** is hard serial: the regression guard must be run
  against the fully-parametrized tree, so it lands after all six
  parametrize commits.
- **P2.Z → P2.3 → P2.4** is hard serial: Ekko's secondary grep + build
  verification run against Viktor's fully-parametrized + guard-installed
  tree. Handoff point between Viktor and Ekko in Phase 2.
- **P2.5 → P3.4** is hard serial: branch-protection template must be
  corrected before it's re-applied.
- **P3.1 → Window C** is hard serial: the remote must exist before
  secrets/protection/labels can be set against it.
- **P3.7 → P3.8** is hard serial: Firebase binding must be on
  strawberry-app before the first workflow run is meaningful for the
  deploy gate.
- **P3.9 → {P4.1, P5.1}** is hard serial but then fans out: once
  strawberry-app has a green prod deploy, Phase 4 replay and Phase 5
  doc-rewrites can run **in parallel across owners** — P4.x stays with
  Ekko in strawberry-app context, P5.x goes to Viktor in strawberry
  context. Different repos, different worktrees, no interference.

### Owner-concurrent schedule (happy path)

| Clock | Ekko | Viktor | Duong |
|-------|------|--------|-------|
| T0 | — | — | P0.0 / D1-D5 preflight |
| T0 + 20m | P0.1 → P0.2 → P0.3 | standby | D10 sign-off if needed |
| T1 | P1.1 → P1.7 (Window A) | standby | — |
| T1 + 30m | P1.8, P1.9 | standby | on-exception |
| T2 | P2.1 (grep + categorize) | standby | — |
| T2 + 10m | standby | P2.P1 ∥ P2.P2 ∥ P2.P3 ∥ P2.P4 ∥ P2.P5 ∥ P2.P6 (Window B) | — |
| T2 + 40m | standby | P2.Z (guard hook + CI wiring) | — |
| T2 + 55m | P2.3 → P2.4 → P2.5 | standby | — |
| T3 | standby | P3.1 | — |
| T3 + 10m | standby | P3.2 (with D6) ∥ P3.3 ∥ P3.4 ∥ P3.5 ∥ P3.6 (Window C) | D6 pasting |
| T3 + 55m | standby | P3.7 (Duong action) | D8 binding |
| T4 | standby | P3.8 → P3.9 | D7 red/green call |
| T4 + 30m | P4.1 → P4.2 → P4.3 | P5.1 → P5.2 → P5.3 → P5.4 → P5.5 (Window D) | — |
| T5 (end-of-day) | all hands standby | | — |
| T5 + 7 days | — | P6.1 → P6.2 | D9 sign-off |

Every PR across both repos is reviewed by **Kayn + Senna + Lucian** per team spec;
merges happen via standard squash-merge (not `--admin`) except the
sanctioned one-time override in P0.2 if CI minutes are still 0 (ADR §8
decision 5 — requires D10).

**Handoff note (Phase 2):** Ekko produces the categorized grep report
in P2.1, then Viktor takes over for Window B parametrization + P2.Z
guard. Ekko returns for P2.3 (secondary-grep sweep), P2.4 (build
verify), and P2.5 (branch-protection template). Two handoffs in the
same phase — make them explicit in the session channel so neither
owner stalls waiting on the other.

---

## Acceptance-gate cross-reference

Caitlyn's acceptance-gate checklist
(`assessments/2026-04-18-migration-acceptance-gates.md`) defines **57
gates** total. This table maps each task ID to the gates it must satisfy
on success (✓ = primary satisfier; F = feeds a migration-complete gate;
— = no dedicated gate, precondition for a downstream one).

| Task | Gates satisfied | Feeds |
|------|-----------------|-------|
| P0.0 | — (D1-D5) | |
| P0.1 | precondition to P0-G1, P0-G2 | |
| P0.2 | P0-G1 ✓, P0-G2 ✓, P0-G5 (if admin path) | |
| P0.3 | P0-G3 ✓, P0-G4 ✓ | |
| P1.1 | P1-G1 ✓ | |
| P1.2 | precondition to P1-G3 | |
| P1.3 | P1-G2 ✓, P1-G3 ✓, P1-G7 ✓ | M-G14 |
| P1.4 | P1-G8 ✓ | |
| P1.5 | — (scripts pruned) | M-G13 |
| P1.6 | feeds P1-G6 | |
| P1.7 | — (public surface) | M-G1 |
| P1.8 | P1-G4 ✓ | M-G8 |
| P1.9 | P1-G5 ✓ | M-G8 |
| P2.1 | precondition to P2-G1, P2-G2 (categorized report) | |
| P2.P1 | contributes to P2-G1, P2-G2 (runtime-TS subset) | |
| P2.P2 | contributes to P2-G1 (workflows subset) | |
| P2.P3 | contributes to P2-G1, P2-G2 (shell-scripts subset) | |
| P2.P4 | contributes to P2-G1 (prompt — R14 mitigated) | |
| P2.P5 | contributes to P2-G1 (discord-relay — R8 mitigated) | |
| P2.P6 | contributes to P2-G4 (plan-permalink form preserved) | |
| P2.Z | P2-G5 ✓ (commit exists); installs guard that protects P2-G1 long-term | |
| P2.3 | P2-G3 ✓, P2-G4 ✓ | |
| P2.4 | P1-G6 ✓, P2-G6 ✓ | |
| P2.5 | precondition to P3-G5, P3-G6 | M-G3 |
| P3.1 | P3-G1 ✓, P3-G2 ✓ | M-G1, M-G4 |
| P3.2 | P3-G3 ✓, P3-G4 ✓ | M-G2 |
| P3.3 | P3-G11 ✓ | |
| P3.4 | P3-G5 ✓, P3-G6 ✓, P3-G7 ✓ | M-G3 |
| P3.5 | P3-G8 ✓ | |
| P3.6 | — (Dependabot verified) | |
| P3.7 | P3-G9 ✓, P3-G10 ✓ | M-G5 |
| P3.8 | P3-G12 ✓, P3-G13 ✓ | M-G1, M-G2, M-G6 |
| P3.9 | precondition to P6-G2 | M-G6 |
| P4.1 | precondition to P4-G1 | |
| P4.2 | precondition to P4-G1, P4-G3 | |
| P4.3 | P4-G1 ✓, P4-G2 ✓, P4-G3 ✓, P4-G4 ✓, P4-G5 ✓ | M-G7, M-G15 |
| P5.1 | P5-G1 ✓, P5-G2 ✓ | M-G9 |
| P5.2 | P5-G4 ✓ | M-G9 |
| P5.3 | P5-G3 ✓, P5-G7 ✓ | M-G10 |
| P5.4 | P5-G6 ✓ | |
| P5.5 | P5-G5 ✓ | |
| P6.0 | P6-G1 ✓, P6-G2 ✓, P6-G3 ✓, P6-G4 ✓ | |
| P6.1 | P6-G5 ✓, P6-G6 ✓, P6-G7 ✓ | M-G11, M-G14, M-G17 |
| P6.2 | — (private README updated) | |

Migration-complete gates **M-G12** (no `--admin` merge post-protection)
and **M-G16** (no `.age` files committed to public) are system-level
checks verified by Kayn + Senna + Lucian on review of every PR; they are not
satisfied by a single task but by discipline across the whole run.
**M-G13** (dual-tracked secrets-guard hook byte-identical) is verified
at the moment strawberry-app receives its first hook refresh from
strawberry — convention-level gate, not task-level.
