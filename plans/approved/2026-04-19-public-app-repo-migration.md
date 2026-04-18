---
status: approved
owner: azir
date: 2026-04-19
title: Public app-repo migration — split strawberry into private agent-infra + public apps for unlimited Actions minutes
links:
  - plans/approved/2026-04-17-branch-protection-enforcement.md
  - plans/approved/2026-04-13-deployment-pipeline-architecture.md
  - plans/approved/2026-04-17-tdd-workflow-rules.md
  - plans/in-progress/2026-04-17-deployment-pipeline.md
  - architecture/git-workflow.md
  - architecture/deployment.md
  - architecture/security-debt.md
---

# Public app-repo migration

## 1. Context and decision

Strawberry has burned its full 3000/3000 GitHub Actions free minutes for the month. Duong will not raise the $20/mo budget; minutes reset in 13 days. 11 dual-green PRs (#146, #148, #152, #153, #154, #161, #165, #169, #170, #175, #177, #180, #182 — 13 IDs tracked, list may drift) cannot merge because required status checks cannot dequeue. This is the critical-path blocker for Phase 1 exit.

**Public repositories on github.com receive unlimited Actions minutes.** The cheapest unblock is to split the repo: keep agent-infra private (memory, plans, transcripts, encrypted secrets) and publish the code (apps, dashboards, workflows, scripts) under a new public repo.

**Decision:** two-repo split.
- **`Duongntd/strawberry`** stays private. Becomes pure agent-infra: `agents/`, `plans/`, `assessments/`, repo-root `CLAUDE.md`, `agents/evelynn/CLAUDE.md`, `secrets/encrypted/`, most of `architecture/`.
- **`harukainguyen1411/strawberry-app`** (new, public). Hosts `apps/`, `dashboards/`, `.github/workflows/`, `scripts/`, top-level build config, selected `docs/`, selected `architecture/` docs rewritten as public docs.

Naming rationale: `strawberry-app` over `strawberry-apps` (singular reads as the monorepo), over `mmp-tooling` (unbranded, loses continuity), over `dashboards` (too narrow — portal/myapps/landing/functions ship from the same repo). It preserves the strawberry brand, reads as "the thing users can run," and doesn't pretend to be project-specific.

**What this plan is not:** not a re-architecture. The monorepo layout (`apps/*`, `dashboards/*`, `scripts/*`, root `package.json` + turbo + workspaces) survives intact in the new repo. The split is along privacy boundaries, not functional boundaries. Post-migration, the two repos are loosely coupled: plans reference commit SHAs and PR URLs in strawberry-app, strawberry-app commits reference plan paths in strawberry.

---

## 2. Scope — what goes where

### 2.1 Moves to `harukainguyen1411/strawberry-app` (public)

| Path | Notes |
|------|-------|
| `apps/**` | Portal, myapps, landing, functions, shared, discord-relay, coder-worker, deploy-webhook, contributor-bot, **bee-worker** (apps/private-apps/bee-worker — moved to public per Duong 2026-04-18). |
| `dashboards/**` | test-dashboard, dashboard, server, shared |
| `.github/workflows/**` | All 14 workflows |
| `.github/branch-protection.json` | Template; re-applied via `scripts/setup-branch-protection.sh` |
| `.github/dependabot.yml` | |
| `.github/pull_request_template.md` | |
| `.github/scripts/**` | `notify-discord-*.js` |
| `scripts/**` | All except `scripts/hooks/` — see §2.2 |
| `tools/**` | `decrypt.sh` and helpers. **Without** `secrets/age-key.txt`; public users can't decrypt but the tool itself is not sensitive. |
| `package.json`, `package-lock.json` | Top-level workspace manifest. Remove `"private": true` flag. |
| `tsconfig.json`, `eslint*`, `turbo.json`, `firestore.rules`, `firestore.indexes.json`, `release-please-config.json`, `ecosystem.config.js` | Build and deploy config |
| `.gitignore` | Pruned — drop agent/plan-specific lines |
| `README.md` | **Rewrite.** New public-facing README: what Dark Strawberry is, how to run locally, how to contribute (or "contributions not yet open"). |
| `docs/**` | `delivery-pipeline-setup.md`, `vps-setup.md`, `windows-services-runbook.md`, `workspace-agent-setup-guide.md`, `superpowers/` — audit each first. |
| Selected `architecture/*.md` | `deployment.md`, `git-workflow.md`, `pr-rules.md`, `testing.md`, `firebase-storage-cors.md`, `system-overview.md` (sanitized — strip agent refs), `platform-split.md`, `platform-parity.md`. Move under `docs/architecture/` in the public repo. |

### 2.2 Path-level exceptions and splits

| Path | Action |
|------|--------|
| `scripts/hooks/pre-commit-secrets-guard.sh` | Copy to both repos. Public repo uses same gitleaks ruleset; agent-infra repo's copy is the source of truth for tuning. |
| `scripts/hooks/pre-commit-unit-tests.sh`, `pre-push-tdd.sh`, `pre-commit-artifact-guard.sh` | Public repo only — they operate on `apps/`/`dashboards/`. |
| `scripts/install-hooks.sh` | Both repos. Each installs its own hook bundle. |
| `scripts/safe-checkout.sh`, `scripts/plan-promote.sh`, `scripts/plan-publish.sh`, `scripts/plan-unpublish.sh`, `scripts/plan-fetch.sh`, `scripts/_lib_gdoc.sh` | Private repo only — plan lifecycle is agent-infra. |
| `scripts/evelynn-memory-consolidate.sh`, `scripts/list-agents.sh`, `scripts/new-agent.sh`, `scripts/lint-subagent-rules.sh`, `scripts/strip-skill-body-retroactive.py`, `scripts/hookify-gen.js` | Private repo only — agent tooling. |
| `scripts/deploy/**`, `scripts/mac/**`, `scripts/windows/**`, `scripts/gce/**`, `scripts/composite-deploy.sh`, `scripts/scaffold-app.sh`, `scripts/seed-app-registry.sh`, `scripts/health-check.sh`, `scripts/migrate-firestore-paths.sh`, `scripts/vps-setup.sh`, `scripts/deploy-discord-relay-vps.sh` | Public. |
| `scripts/setup-branch-protection.sh`, `scripts/verify-branch-protection.sh`, `scripts/setup-github-labels.sh`, `scripts/setup-discord-channels.sh`, `scripts/gh-audit-log.sh`, `scripts/gh-auth-guard.sh` | Public. Must be idempotent across both repos. |
| `scripts/google-oauth-bootstrap.sh`, `scripts/setup-agent-git-auth.sh` | Private only. |

### 2.3 Stays in private `strawberry`

| Path | Reason |
|------|--------|
| `agents/**` | Memory, learnings, profiles, transcripts, inboxes. Never public. |
| `plans/**` | Architectural decisions, often mention infra tokens/IDs. Stay private. |
| `assessments/**` | Internal analyses. Stay private. |
| `secrets/**` | Gitignored plaintext excluded; `secrets/encrypted/**` is gitignored inside the public repo anyway, but moving `secrets/encrypted/` to public would leak the encrypted-blob filenames (useful signal to an attacker). Keep private. |
| `CLAUDE.md` (root) | Agent invariants. Private. |
| `agents/evelynn/CLAUDE.md` | Coordinator protocol. Private. |
| `tasklist/**` | Internal queue. Private. |
| `incidents/**` | Ops postmortems. Private. |
| `design/**` | Figma mirrors, design artifacts. Private for now; case-by-case publish later. |
| `mcps/**` | MCP server configs — may reference API keys in shape. Private until audited. |
| `strawberry-b14/**`, `strawberry.pub/**` | Legacy worktrees or mirrors — delete before migration; not part of either repo. |
| `tests/` (root-level, if any) | Case-by-case; most test fixtures go with their apps. |

### 2.4 Dual-tracked files

| Path | Treatment |
|------|-----------|
| `.gitignore` | Two tuned copies. Public repo adds `secrets/`, `.env*`, node_modules, etc. Private repo keeps current full ignore set. |
| `CLAUDE.md` (any workspace subdirs with agent rules) | Private only. If `apps/myapps/.cursor/skills/` contains agent rules, strip or move them. |
| Contributor docs | Fresh `CONTRIBUTING.md` + `CODE_OF_CONDUCT.md` + `LICENSE` (MIT or AGPL — Duong decides in §8) in public repo. None in private. |

### 2.5 Audit gate — architecture/ triage

`architecture/` is a mixed bag. Before the migration starts, Azir (pre-session) or Evelynn triages each file into public / private / redact-and-publish. The default is private.

| File | Default | Notes |
|------|---------|-------|
| `agent-network.md`, `agent-system.md` | Private | Agent roster and internal naming. |
| `claude-billing-comparison.md`, `claude-runlock.md` | Private | Cost/infra internals. |
| `deployment.md` | Public (sanitize) | Deployment runbook; strip references to specific agent names. |
| `discord-relay.md`, `telegram-relay.md` | Private initially | Contains channel/IDs; revisit later. |
| `firebase-storage-cors.md` | Public | Pure configuration doc. |
| `git-workflow.md`, `pr-rules.md`, `testing.md` | Public (sanitize) | Strip agent-specific references. |
| `infrastructure.md` | Private | Host-level infra. |
| `key-scripts.md` | Public (sanitize) | Drop entries for private-only scripts. |
| `mcp-servers.md`, `plugins.md`, `plan-gdoc-mirror.md` | Private | Agent internals. |
| `platform-parity.md`, `platform-split.md`, `system-overview.md` | Public (sanitize) | High-level system shape. |
| `security-debt.md` | Private | Open issues list — do not publish. |
| `README.md` | Split: private retains full index; public gets a pruned index under `docs/architecture/README.md`. |

---

## 3. Risk register

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| R1 | Past commits contain secrets (near-misses in `apps/`/`dashboards/`/`scripts/`) that become publicly searchable | Critical | Phase 1 gitleaks audit on the filtered history before push. Rotate any found secret regardless of recency. If found, treat migration as paused until rotated. |
| R2 | `git filter-repo --path` leaves orphan trees where scripts referenced agent paths | High | Phase 2 static link-check: after filter, grep the filtered checkout for `agents/`, `plans/`, `assessments/` path refs; either delete the file or rewrite the ref to a doc URL in strawberry. |
| R3 | 11 dual-green PRs can't be cleanly replayed against a rewritten `main` | High | Before rewriting history, **merge all dual-green PRs in strawberry first** (§4.1). Only unmerged/draft PRs need replay. For those, push the branch to strawberry-app and re-open; preserve the original author of record. |
| R4 | GitHub secrets not re-provisioned → first deploy workflow red in strawberry-app | Critical | Phase 3 runbook explicitly enumerates all 17 secrets and maps current→new; Duong executes via GitHub Console before first workflow run. Don't cut over Firebase deploy bindings until every secret is verified present. |
| R5 | Firebase CI/CD GitHub App installed against strawberry, not strawberry-app → prod deploys break | Critical | Phase 3 explicit step: reinstall Firebase GitHub App on strawberry-app. Gate prod deploy cutover on successful staging deploy from new repo. |
| R6 | Branch-protection rules not re-applied → someone (including agents) force-pushes or merges without review | High | Phase 3 runs `scripts/setup-branch-protection.sh` immediately after first successful workflow run. Verified via `scripts/verify-branch-protection.sh`. |
| R7 | Agent memory and plan docs hard-reference commit SHAs that drift after history rewrite | Medium | **Adopt fresh-start: single squashed commit** (see §5) — accept that old SHAs are dangling but preserve the old strawberry repo as read-only "archival" for reference. Update `agents/*/memory/MEMORY.md` and high-traffic plans via find/replace to point at the archival repo URL for historical SHAs. |
| R8 | Discord relay, Firebase function triggers, Cloud Run deploys, `scripts/setup-discord-channels.sh` hardcode `Duongntd/strawberry` | High | Phase 2 grep sweep produces a list of all hardcoded references; Phase 3 sed-rewrite in one atomic commit. Static list in §6.2. |
| R9 | Dependabot re-opens ~14 PRs in strawberry-app after cutover, spiking CI even though minutes are now free | Low | Accepted — free minutes. If it turns out Dependabot floods, can set `open-pull-requests-limit: 0` for a week. |
| R10 | Marketing: making the code public surfaces Dark Strawberry before it's ready | Medium | Decision for Duong (§8). Default stance in this plan: **public repo, no marketing push.** Add a `README.md` that reads "early-access platform, not yet accepting signups" with a link to a waitlist if desired. |
| R11 | Cross-repo workflow confusion: plans in strawberry reference PRs in strawberry-app and vice versa | Medium | Convention (§7): plans always link to `github.com/harukainguyen1411/strawberry-app/pull/N`, PR bodies always link to `plans/<status>/<slug>.md` on strawberry main via permalink. No file-level coupling. |
| R12 | PAT/bot accounts lose access when repo is recreated | High | Phase 3 re-issues fine-grained PAT scoped to `harukainguyen1411/strawberry-app`. Since `harukainguyen1411` owns the new repo, collaborator step is not required. |
| R13 | Turbo cache layer in CI keyed on repo slug → full rebuild after cutover | Low | Accepted — one-time cost, rebuild completes in a few minutes. |
| R14 | `apps/coder-worker/system-prompt.md` hardcodes "Duongntd/strawberry" — autonomous agent will try to commit to the wrong repo | Critical | Caught in Phase 2 grep sweep (see §6.2); sed-rewrite to `harukainguyen1411/strawberry-app` in the atomic rewrite commit. |
| R15 | `.github/branch-protection.json` currently requires only `validate-scope` and `preview` — doesn't match reality (should also include tdd-gate, unit-tests, e2e, qa). Re-applying as-is under-protects | Medium | Sync `branch-protection.json` with `plans/approved/2026-04-17-branch-protection-enforcement.md` Table §1 **before** reapplying. Treat as a blocker for Phase 3 exit. |

---

## 4. Execution sequence

Total time budget: 2-4 hours. Two executors: **Ekko** (history rewrite, repo creation, code cutover) and **Caitlyn** (secret re-provisioning, branch protection, deploy binding). Each phase has a rollback point.

### 4.0 Preflight — Ekko CLI-driven with Duong handoff (~5 min of Duong attention)

Ekko drives preflight via `gh` CLI at session start. Duong's only manual step is the Firebase GitHub App install (Console UI — no CLI equivalent).

- **Prereq:** fix the pre-existing `ulid@3.0.2` lockfile desync in Duongntd/strawberry before migration session. Otherwise `npm ci` fails on the filtered tree (confirmed by Ekko dry-run, `assessments/2026-04-18-migration-dryrun.md`). This is a 1-commit fix — run `npm install ulid@latest` at the repo root, commit the updated package-lock.json.

1. **Owner: Ekko** — Create new empty public repo: `gh repo create harukainguyen1411/strawberry-app --public --confirm`. Do not initialize with README/LICENSE/.gitignore.
2. **Owner: Ekko** — Enable all actions and set default workflow permissions to read/write: `gh api repos/harukainguyen1411/strawberry-app/actions/permissions --method PUT --field enabled=true --field allowed_actions=all` and `gh api repos/harukainguyen1411/strawberry-app/actions/permissions/workflow --method PUT --field default_workflow_permissions=write --field can_approve_pull_request_reviews=true`.
3. **Owner: Ekko** — Enable Dependabot alerts and security updates: `gh api repos/harukainguyen1411/strawberry-app/vulnerability-alerts --method PUT` and `gh api repos/harukainguyen1411/strawberry-app/automated-security-fixes --method PUT`.
4. **Owner: Duong** — Install the Firebase CI/CD GitHub App on strawberry-app (Console UI only — no CLI equivalent): Firebase Console → Project Settings → Integrations → GitHub → select `harukainguyen1411/strawberry-app`. Also install on `harukainguyen1411/strawberry-agents` in the same session (back-to-back migrations share this step).
5. **Owner: Duong** — Install the Firebase CI/CD GitHub App on strawberry-agents (same Console session as step 4).
6. **Owner: Ekko** — Confirm LICENSE choice (§8) and update plan if changed.
7. **Owner: Ekko** — Confirm repo name (`strawberry-app` vs alternative) and update this plan if changed. No collaborator invite needed — harukainguyen1411 is owner of both active repos.

### 4.1 Phase 0 — Merge the dual-green queue (Ekko, in strawberry) — 30-60 min

Goal: reduce the PR replay surface to zero. Every dual-green PR should merge **before** the history rewrite so it exists in the base commit.

1. For each of the 13 open PRs, in order of `updatedAt` ascending (oldest first so rebases don't cascade):
   a. Check `gh pr checks <N>` — skip if red.
   b. Check `gh pr view <N> --json reviewDecision` — skip if not APPROVED.
   c. Merge via squash: `gh pr merge <N> --squash --delete-branch`.
   d. Pull main locally to avoid divergence for next merge.
2. For PRs that are draft or red — leave open. They get replayed in Phase 4.
3. Commit cut-line: whatever is on `main` after Phase 0 is the base commit for the public repo.

Rollback point: none needed — this is pure merging in the existing repo.

**Gate:** before proceeding to Phase 1, CI minutes must either have reset or be reserved for minimum gate checks. If minutes are still 0, we're stuck. Alternatively: disable required status checks temporarily in strawberry (Duong action), merge admin-bypass with documented incident, proceed. This is the only sanctioned `--admin` merge in this plan and only after Duong signs off in session.

### 4.2 Phase 1 — History filter + secret audit (Ekko, fresh clone) — 30-45 min

**Do not operate on the live strawberry checkout.** Work in a scratch clone.

1. `git clone --bare https://github.com/Duongntd/strawberry.git /tmp/strawberry-filter.git`
2. Install `git-filter-repo` (`brew install git-filter-repo`) if not present.
3. Decision point (see §5): single squashed commit **vs.** path-filtered history. Default is **single squashed commit**. If Duong overrides to "preserve history," use path-filter steps (§5.2).
4. For squash path:
   a. `git clone /tmp/strawberry-filter.git /tmp/strawberry-app && cd /tmp/strawberry-app`
   b. Remove private paths: delete `agents/`, `plans/`, `assessments/`, `architecture/` (selected files re-added in next step), `secrets/`, `tasklist/`, `incidents/`, `design/`, `mcps/`, `strawberry-b14/`, `strawberry.pub`, `apps/private-apps/`, `CLAUDE.md`, `agents/evelynn/CLAUDE.md`.
   c. Re-add sanitized `architecture/` files per §2.5 table under `docs/architecture/`.
   d. Prune `scripts/` per §2.2.
   e. `git add -A && git commit -m "chore: initial public commit — strawberry-app split from strawberry <SHORT-SHA>"`
   f. Replace history: `git checkout --orphan clean && git add -A && git commit --reuse-message=HEAD && git branch -M clean main --force`
5. Run **gitleaks** against the filtered checkout and against the last 100 commits of its reflog:
   - `gitleaks detect --source=. --redact --report-path=/tmp/gitleaks.json`
   - `gitleaks detect --source=. --log-opts="--all" --redact --report-path=/tmp/gitleaks-history.json`
6. Review `/tmp/gitleaks.json`. Any real finding (not false positive) → **STOP**. Rotate the secret, amend the filtered commit, re-run.
7. False-positive rule: repo slug `Duongntd/strawberry` matches generic-api-key (known from `agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md`). Add to allowlist before running.

Rollback point: discard `/tmp/strawberry-app`, no remote changes yet.

### 4.3 Phase 2 — Rewrite hardcoded repo references (Ekko, still in scratch) — 20 min

1. Grep sweep in `/tmp/strawberry-app`:
   ```
   grep -rln 'Duongntd/strawberry' . --include='*.sh' --include='*.ts' --include='*.js' --include='*.yml' --include='*.yaml' --include='*.md' --include='*.json'
   ```
2. Expected hits (audit list — actual findings may differ; verify in session):
   - `apps/coder-worker/system-prompt.md` — rewrite to `harukainguyen1411/strawberry-app` (R14).
   - `apps/discord-relay/src/discord-bot.ts:172` — rewrite issue-filing URL.
   - `.github/workflows/landing-prod-deploy.yml` — if repo slug baked in, rewrite.
   - `scripts/setup-branch-protection.sh`, `scripts/verify-branch-protection.sh` — parametrize on `$GITHUB_REPOSITORY` or hardcode new slug.
   - Any `README.md` links.
3. For each hit, sed-rewrite inline. Commit as `chore: retarget repo references from strawberry to strawberry-app`.
4. Cross-grep: also search for `strawberry.git` and bare `strawberry` in URL contexts.
5. Run `npm ci` on the filtered tree and `turbo run build --dry-run` to catch any path that broke.

Rollback point: discard the commit, redo.

### 4.4 Phase 3 — Push, re-provision, re-protect (Caitlyn) — 45-60 min

Executed by Caitlyn in parallel with Phase 4 where possible.

1. **Push to new remote.**
   - In `/tmp/strawberry-app`: `git remote add origin https://github.com/harukainguyen1411/strawberry-app.git && git push -u origin main`.
2. **Re-provision GitHub secrets.** For each secret currently in strawberry, set in strawberry-app:
   - `AGE_KEY`, `AGENT_GITHUB_TOKEN`, `BOT_WEBHOOK_SECRET`, `CF_ACCOUNT_ID`, `CF_API_TOKEN`, `FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`, `GCP_SA_KEY_PROD`, `GCP_SA_KEY_STAGING`, `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_APP_ID`, `VITE_FIREBASE_AUTH_DOMAIN`, `VITE_FIREBASE_MEASUREMENT_ID`, `VITE_FIREBASE_MESSAGING_SENDER_ID`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_STORAGE_BUCKET`.
   - Method: `gh secret set <NAME> --repo harukainguyen1411/strawberry-app --body "$(gh secret get <NAME> --repo Duongntd/strawberry)"` — but `gh secret get` does not exist. Actual method: Caitlyn coordinates with Duong, who pastes each value once via `gh secret set --body-file` or Console. See §6.1.
   - `BEE_SISTER_UIDS` — per scope note, this secret is called out but not in the current `gh secret list`. Either it's a Firebase config value baked into `apps/myapps/functions` or it's referenced in a plan but not yet provisioned. Caitlyn verifies with Duong before cutover.
3. **Re-issue fine-grained PAT** minted from the `harukainguyen1411` account, scoped to `harukainguyen1411/strawberry-app`. Store encrypted token at `secrets/encrypted/github-triage-pat.txt.age` in the private repo as before. Any agent session using the old PAT needs refresh.
4. **Apply branch protection.** Fix `.github/branch-protection.json` in strawberry-app to match `plans/approved/2026-04-17-branch-protection-enforcement.md` §1 (5 required contexts, not 2). Commit. Run `scripts/setup-branch-protection.sh` against `harukainguyen1411/strawberry-app`. Verify with `scripts/verify-branch-protection.sh`.
5. **GitHub labels.** Run `scripts/setup-github-labels.sh` against the new repo.
6. **Dependabot.** Already wired via the pushed `.github/dependabot.yml`. First run will open PRs — accepted.
7. **Firebase GitHub App cutover.** Duong action: disconnect from strawberry, confirm connected to strawberry-app. Firebase will then deploy preview/prod from strawberry-app PRs.
8. **First workflow run.** Push a trivial no-op commit (bump version in root `package.json`). Verify all required workflows run green. If red → **STOP, rollback to strawberry** by reverting Firebase binding and leaving the old repo as canonical.

Rollback point: Firebase binding. Until step 8, strawberry remains the prod-deploying repo. After step 8 + one green deploy, strawberry-app is canonical.

### 4.5 Phase 4 — Replay open non-green PRs (Ekko + Caitlyn) — 30 min

1. For each PR still open in strawberry at migration time (drafts, red, or unmerged-but-expected):
   a. Check out the branch in a worktree.
   b. Re-create the branch against strawberry-app: push to new remote with same branch name.
   c. Open a new PR in strawberry-app using `gh pr create`.
   d. Close the strawberry PR with comment: "Migrated to strawberry-app#<NEW_N>. Context: plans/proposed/2026-04-19-public-app-repo-migration.md."
2. Dependabot PRs are not replayed — they'll re-open automatically on the new repo.

### 4.6 Phase 5 — Agent and plan update (Caitlyn) — 20-30 min

1. Update `agents/*/memory/MEMORY.md` across all active agents: find/replace `github.com/Duongntd/strawberry/pull` → `github.com/harukainguyen1411/strawberry-app/pull`, and `Duongntd/strawberry` (in code context) → `harukainguyen1411/strawberry-app`. Leave historical transcripts untouched (they're records of the past).
2. Update `architecture/git-workflow.md`, `architecture/pr-rules.md`, `CLAUDE.md` (root), and `agents/evelynn/CLAUDE.md` to name both repos explicitly: strawberry (agent-infra) and strawberry-app (code).
3. Add one-pager `architecture/cross-repo-workflow.md` documenting §7 cross-repo conventions.
4. Update plan-promote script commentary if any path-specific logic referred to `apps/`.
5. Commit batch to private repo: `chore: azir migration — update agent memory and architecture docs for two-repo split`.

### 4.7 Phase 6 — Archive old repo (Duong action) — 5 min

After 7 days of stable operation on strawberry-app:

1. Duong: github.com → Duongntd/strawberry → Settings → rename to `strawberry-archive-private` (optional — keeps the name `strawberry` free for the private agent-infra repo, **or** keep `strawberry` as the agent-infra repo and skip rename).
2. **Decision:** keep `strawberry` as the private agent-infra repo name. Do not rename. The monorepo split is spatial, not nominal — strawberry is still the brain, strawberry-app is the arms.
3. Delete `apps/`, `dashboards/`, `scripts/`, `.github/workflows/`, top-level build config from strawberry in a single `chore: azir — purge code paths migrated to strawberry-app` commit. Keeps strawberry's history readable back to the migration commit; SHAs before that remain valid for historical references.

Rollback point: if strawberry-app proves unstable in 7 days, revert Phase 6 (restore code paths from last pre-purge commit). Phase 6 is the final irreversible step only after 7 days of green operation.

---

## 5. History strategy — squash vs. preserve

### 5.1 Default: single squashed commit

**Rationale:**
- Old commit SHAs in agent memory break under any history filter. Squash is no worse than path-filter in this regard.
- Public repo history inherits zero baggage: no half-deleted files, no hard-to-explain path moves, no merge commits referencing "Vi's PR fix."
- Phase 1 is simpler: one commit, one gitleaks pass, clear baseline.
- `blame` loss is accepted — blame on pre-migration history lives in strawberry (archival).

**Tradeoff accepted:** `git log` on public repo starts at the migration commit. Anyone wanting pre-migration provenance looks at strawberry (which remains private but Duong can grant read access to collaborators as needed).

### 5.2 Alternative: path-filter preserve

Use `git filter-repo --path apps/ --path dashboards/ --path .github/workflows/ --path scripts/ --path-glob 'package*.json' --path-glob 'tsconfig*.json' --path turbo.json --path firestore.rules --path firestore.indexes.json --path release-please-config.json --path ecosystem.config.js`.

**Problems:**
- Merge commits from strawberry main will land with one-parent-empty, cluttering history.
- Some commits touched both private and public paths (e.g. a commit that modified both `agents/evelynn/memory/MEMORY.md` and `apps/myapps/...`). After filter, the commit message still references the agent change even though the agent file is gone. Confusing.
- gitleaks must scan full rewritten history, not just current state — slower, more false positives to triage.
- Any past secret near-miss in `apps/`/`scripts/` becomes permanently part of public git history. If rotated but not scrubbed, a historical leak is recoverable.

**When to use:** only if Duong insists on preserving `git log`/`git blame` for public PR-level forensics. Otherwise, squash.

---

## 6. Reference tables

### 6.1 GitHub secrets to re-provision

All 17 secrets. Each must be re-entered by Duong (or pulled from local env where available) and set via `gh secret set <NAME> --repo harukainguyen1411/strawberry-app --body-file -`. `gh` cannot read an existing secret's value, so each must be sourced from:
- Local file: `AGE_KEY` (from `secrets/age-key.txt`), Firebase service account JSONs (from local Firebase console download).
- Paste-through: `VITE_FIREBASE_*` values (from `apps/myapps/src/firebase-config.ts` or Firebase Console).
- Re-mint: `AGENT_GITHUB_TOKEN` (new PAT scoped to strawberry-app), `BOT_WEBHOOK_SECRET` (random — update Discord webhook config too).

| Secret | Source | Notes |
|--------|--------|-------|
| `AGE_KEY` | `secrets/age-key.txt` in private strawberry | Used by `.github/workflows/*` to decrypt ci-time secrets |
| `AGENT_GITHUB_TOKEN` | Re-mint fine-grained PAT scoped to strawberry-app | `harukainguyen1411` PAT for agent commits |
| `BOT_WEBHOOK_SECRET` | Re-mint random 32-byte | Must update Discord/GitHub webhook config to match |
| `CF_ACCOUNT_ID`, `CF_API_TOKEN` | Cloudflare dashboard | For landing deploys |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase console → Service Accounts → Generate new key | Dark Strawberry project |
| `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` | Firebase console (myapps project — ID in `apps/myapps/firebase.json`) | myapps functions deploy |
| `GCP_SA_KEY_PROD`, `GCP_SA_KEY_STAGING` | GCP IAM → Service Accounts → new key | Cloud Run / Functions deploy |
| `VITE_FIREBASE_*` (7 values) | Firebase console → Project settings → Web app | Client-side config, public anyway but CI needs them for build |

### 6.2 Hardcoded-slug audit expectations (from grep sweep)

Files that reference `Duongntd/strawberry` and must be rewritten in Phase 2 (confirmed via grep):

- `apps/coder-worker/system-prompt.md`
- `apps/discord-relay/src/discord-bot.ts` (issue-filing URL)
- `.github/workflows/landing-prod-deploy.yml`
- `plans/proposed/2026-04-17-dependabot-phase3.md` (stays in strawberry, reference updated post-migration)
- `plans/proposed/2026-04-05-plan-viewer.md` (plan viewer reads from strawberry-app — rewrite)
- `plans/proposed/2026-04-09-autonomous-pr-lifecycle.md` (rewrite)
- `scripts/setup-branch-protection.sh` (if slug hardcoded — parametrize on `$1` arg)

Per-file decision is made in-session when the grep is run.

### 6.3 Rollback summary

| After phase | Rollback action |
|-------------|-----------------|
| 0 | None — strawberry is untouched if Phase 1 not started |
| 1 | Discard `/tmp/strawberry-app` — no remote changes |
| 2 | Same as 1 |
| 3 step 1-3 | Delete `harukainguyen1411/strawberry-app` repo (Duong action, Console) |
| 3 step 4-6 | Branch-protection / labels / Dependabot in new repo — harmless if new repo deleted |
| 3 step 7 | Revert Firebase GitHub App binding back to strawberry (Duong action) |
| 3 step 8 red | Same as step 7 — repo deletion or binding revert |
| 4 | Close the newly-opened PRs in strawberry-app. Leave strawberry PRs open. |
| 5 | Revert the `chore: azir migration` commit in strawberry. Agent memory retains both old and new refs temporarily. |
| 6 | Restore purged paths from the commit prior to purge. Only phase that's pseudo-irreversible after 7 days. |

---

## 7. Cross-repo conventions (post-migration)

Adopted to avoid coupling drift between strawberry and strawberry-app.

1. **Plans always live in strawberry.** Code PRs in strawberry-app link to plans via permalink, e.g. `https://github.com/Duongntd/strawberry/blob/main/plans/approved/2026-04-13-deployment-pipeline-architecture.md`.
2. **PRs always live in strawberry-app.** Plans that reference code changes link to `https://github.com/harukainguyen1411/strawberry-app/pull/N`. No embedded diffs in plans.
3. **Shared commit prefix rules.** `chore:` / `ops:` for non-code; `feat:` / `fix:` / etc. for code. Same pre-push hook in both repos, tuned for the paths each repo owns.
4. **Same gitleaks ruleset.** `pre-commit-secrets-guard.sh` is dual-tracked (§2.2) and must stay synchronized. Single source of truth lives in strawberry; strawberry-app copies on each hook-refresh.
5. **Agent sessions run from strawberry checkout.** strawberry-app is checked out as a sibling worktree at `~/Documents/Personal/strawberry-app/` when agents need to touch code. Agents never `cd` between the two — each session is scoped to one or the other.
6. **Plan promotion stays in strawberry.** `scripts/plan-promote.sh` does not touch strawberry-app; a promoted plan is a signal to open a PR in strawberry-app, not a coupling.
7. **Discord relay files issues in strawberry-app** (per R14 rewrite). Triage agents read issues from strawberry-app and file plans in strawberry.
8. **Cross-repo search.** Add `architecture/cross-repo-workflow.md` (Phase 5 step 3) documenting how to grep across both repos for an agent (e.g. "search plans for a feature, then search code for the implementation").

---

## 8. Decisions (captured 2026-04-18)

1. **Repo name:** `strawberry-app`.
2. **LICENSE:** none — source-available, all rights reserved.
3. **History strategy:** single squashed commit (§5.1).
4. **Marketing stance:** quiet launch — public repo exists, no announcement.
5. **Phase 0 CI override:** one-time admin-merge of dual-green PRs is acceptable if minutes are still 0 at session start. Document as incident.
6. **`apps/private-apps/bee-worker` placement:** **moves to strawberry-app (public)**. Override of Azir's default. All apps ship from the public repo.
7. **`architecture/` triage:** Azir's §2.5 table accepted as-is.

8. **Owner account:** new public repo is owned by **harukainguyen1411** — Duong's HUMAN/personal identity (has admin bypass, reviewer on PRs). `Duongntd` is the AGENT account (collaborator, no bypass, canonical pusher for agent-driven commits). The rationale in the original decision text ("harukainguyen1411 is the canonical agent/contributor identity") was incorrect — correction captured 2026-04-18: harukainguyen1411 is human, Duongntd is agent.

**Correction note (2026-04-18):** §4.4 step 3 says "Re-issue fine-grained PAT minted from the `harukainguyen1411` account." This is backwards — PATs for agent ops must be minted from `Duongntd` (agent account), not harukainguyen1411 (human account). Executor should mint from Duongntd when running Phase 3.

Additional decision: **skip formal TDD** for migration ops. Replace with Caitlyn-authored acceptance-criteria gate checklist (see §9), baked into Kayn's task gates.

---

## 9. Acceptance criteria

Migration is complete when all of these are true:

- [ ] `harukainguyen1411/strawberry-app` exists, is public, has a green first workflow run.
- [ ] All 17 GitHub secrets present in strawberry-app and verified via a successful staging deploy.
- [ ] Branch protection on strawberry-app matches `plans/approved/2026-04-17-branch-protection-enforcement.md` §1 (5 required contexts, `strict: true`, 1 required review, `enforce_admins` per that plan).
- [ ] `harukainguyen1411` is the repo owner of strawberry-app (no collaborator invite required).
- [ ] Firebase GitHub App is installed on strawberry-app and **not** on strawberry.
- [ ] One green staging deploy and one green prod deploy have run from strawberry-app main.
- [ ] All 13 originally-open PRs are either merged (via Phase 0) or re-opened in strawberry-app (Phase 4).
- [ ] gitleaks report on strawberry-app shows no real findings (only allowlisted false positives).
- [ ] `agents/*/memory/MEMORY.md` and `architecture/*.md` reference strawberry-app for code and strawberry for plans — no broken `Duongntd/strawberry/pull/N` links for post-migration PRs.
- [ ] `architecture/cross-repo-workflow.md` exists in strawberry.
- [ ] Duong can merge a trivial PR in strawberry-app end-to-end without running out of CI minutes. (The core reason this plan exists.)

After 7 days stable: Phase 6 executes, code paths deleted from strawberry.

---

## 10. Handoff notes

- **Ekko:** owns Phases 0-2 and 4. History rewrite, repo creation, PR replay. Start only after Duong completes §4.0 preflight.
- **Caitlyn:** owns Phases 3, 5. Secrets, branch protection, Firebase binding, agent-memory update. Runs in parallel with Ekko where possible (Phase 3 step 1 needs Ekko's push first).
- **Duong actions** (not delegable to agents): §4.0 preflight; §6.1 secret entry; Phase 3 step 8 Firebase binding cutover; Phase 6 purge commit confirmation.
- **Azir (not this session):** if §7 cross-repo conventions need expansion, a follow-up ADR may be needed.
- **Scope note:** all apps — including `apps/private-apps/bee-worker` — migrate to strawberry-app (public). No apps remain in strawberry after Phase 6. See §8 decision 6.
- **Decisions captured 2026-04-18** — plan promoted to approved; ready to execute.
