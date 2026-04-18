---
title: Public-repo migration — acceptance-criteria gate checklist
date: 2026-04-18
author: caitlyn
plan: plans/approved/2026-04-19-public-app-repo-migration.md
related:
  - plans/approved/2026-04-17-branch-protection-enforcement.md
  - assessments/2026-04-18-migration-dryrun.md
---

# Public-repo migration — acceptance-criteria gate checklist

Phase-gate checklist for the `harukainguyen1411/strawberry-app` migration. Formal TDD is skipped for this migration (Duong's call per §8); this document is the explicit gate record that replaces the xfail-first discipline.

Each phase closes only when **every** check in its section is `[x]`. Checks are binary — a check is either verifiably true or it is not. Every gate is designed to be runnable by Vi (or a human) in under two minutes using the "how to verify" line beneath it. Kayn's task breakdown references these gate IDs (`P0-G1`, `P1-G2`, etc.) when marking tasks complete.

Repo shorthand used throughout:
- **strawberry** = `Duongntd/strawberry` (private agent-infra, current canonical repo)
- **strawberry-app** = `harukainguyen1411/strawberry-app` (new public code repo)

---

## Phase 0 gate — dual-green queue drained

Goal: every mergeable PR in strawberry is merged before history rewrite, so replay surface is minimized.

- [ ] **P0-G1** Every dual-green PR from the §1 list that was APPROVED + green at session start is either merged or explicitly skipped with reason.
  - Verify: `gh pr list --repo Duongntd/strawberry --state merged --search "merged:>=<SESSION_START_ISO>" --json number,title` — cross-reference against the 13 PR IDs in §1 (#146, #148, #152, #153, #154, #161, #165, #169, #170, #175, #177, #180, #182). Any ID not in merged-list must have a documented skip reason (draft / red / author-not-responded) in the Phase 0 journal entry.

- [ ] **P0-G2** No PR in the §1 list remains in OPEN state with reviewDecision=APPROVED AND all checks green.
  - Verify: `gh pr list --repo Duongntd/strawberry --state open --json number,reviewDecision,statusCheckRollup | jq '[.[] | select(.reviewDecision=="APPROVED") | select(all(.statusCheckRollup[]; .conclusion=="SUCCESS"))]'` returns `[]`.

- [ ] **P0-G3** Local `main` in the agent-infra checkout matches `origin/main` on strawberry (no divergence before Phase 1 clone).
  - Verify: `git -C /Users/duongntd99/Documents/Personal/strawberry fetch origin && git -C /Users/duongntd99/Documents/Personal/strawberry rev-parse HEAD` equals `git -C /Users/duongntd99/Documents/Personal/strawberry rev-parse origin/main`.

- [ ] **P0-G4** Phase 0 cut-line SHA is recorded in the session journal.
  - Verify: `grep -c "^cut-line SHA:" agents/ekko/journal/2026-04-*.md` ≥ 1, value matches `git rev-parse origin/main` at end of Phase 0.

- [ ] **P0-G5** If a `--admin` bypass merge was used for any PR (per §4.1 gate), an incident note exists.
  - Verify: either `ls assessments/break-glass/2026-04-*-migration-admin-merge*.md` returns a file, or no `--admin` merges were used (confirmed by checking merge commit authors/messages for "admin" markers).

---

## Phase 1 gate — history filtered and secret-audited

Goal: scratch clone is clean, squashed, and carries zero leaked secrets.

- [ ] **P1-G1** Scratch clone exists at a non-live path (not the agent-infra working tree).
  - Verify: `test -d /tmp/strawberry-app || test -d /tmp/strawberry-filter.git`; `pwd` in any ongoing Phase 1 shell must NOT equal `/Users/duongntd99/Documents/Personal/strawberry`.

- [ ] **P1-G2** All private paths listed in §2.3 are absent from the scratch tree.
  - Verify: run once — `for p in agents plans assessments secrets tasklist incidents design mcps CLAUDE.md strawberry-b14 strawberry.pub; do test -e "/tmp/strawberry-app/$p" && echo "LEAK: $p"; done` — output must be empty.

- [ ] **P1-G3** Scratch tree uses squashed single-commit history (per §5.1 decision).
  - Verify: `git -C /tmp/strawberry-app rev-list --count HEAD` equals `1`, AND `git -C /tmp/strawberry-app log --format=%s` shows exactly one "initial public commit" line.

- [ ] **P1-G4** gitleaks current-tree scan reports zero real findings (allowlisted false positives only).
  - Verify: `gitleaks detect --source=/tmp/strawberry-app --redact --config=/tmp/gitleaks-config.toml --report-path=/tmp/gitleaks.json && jq 'length' /tmp/gitleaks.json` returns `0`. If nonzero, each entry must be a known false-positive from `agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md` with allowlist evidence.

- [ ] **P1-G5** gitleaks full-history scan reports zero real findings.
  - Verify: `gitleaks detect --source=/tmp/strawberry-app --log-opts="--all" --redact --config=/tmp/gitleaks-config.toml --report-path=/tmp/gitleaks-history.json && jq 'length' /tmp/gitleaks-history.json` returns `0`.

- [ ] **P1-G6** Filtered tree builds — `npm install` succeeds, `turbo run build --dry-run` exits 0.
  - Verify: `cd /tmp/strawberry-app && npm install --ignore-scripts && npx turbo run build --dry-run; echo "exit=$?"` — final exit must be `0`. (Note: `npm ci` may fail on the pre-existing `ulid` lockfile desync flagged in the dry-run report; `npm install` is the intended path until lockfile is refreshed.)

- [ ] **P1-G7** No `.age`-encrypted secret blobs present in the scratch tree.
  - Verify: `find /tmp/strawberry-app -name '*.age' -type f` returns no results.

- [ ] **P1-G8** Architecture triage matches §2.5 — 9 public files moved to `docs/architecture/`, 12 private files absent.
  - Verify: `ls /tmp/strawberry-app/docs/architecture/ | sort` contains `deployment.md`, `git-workflow.md`, `pr-rules.md`, `testing.md`, `firebase-storage-cors.md`, `system-overview.md`, `platform-parity.md`, `platform-split.md`, `key-scripts.md`, `README.md`. AND `! ls /tmp/strawberry-app/docs/architecture/{agent-network,agent-system,claude-billing-comparison,claude-runlock,discord-relay,telegram-relay,infrastructure,mcp-servers,plan-gdoc-mirror,plugins,security-debt}.md 2>/dev/null`.

---

## Phase 2 gate — repo references retargeted

Goal: no code, script, doc, or runtime config inside the public tree points at `Duongntd/strawberry` where it should point at `harukainguyen1411/strawberry-app`.

- [ ] **P2-G1** Zero hits for `Duongntd/strawberry` across runtime-critical paths in the scratch tree.
  - Verify: `cd /tmp/strawberry-app && grep -rln 'Duongntd/strawberry' apps/ dashboards/ scripts/ .github/ --include='*.ts' --include='*.tsx' --include='*.js' --include='*.sh' --include='*.yml' --include='*.yaml' --include='*.json'` returns no matches.

- [ ] **P2-G2** The 17 files flagged in the dry-run report (§3 of `assessments/2026-04-18-migration-dryrun.md`) each no longer contain the old slug.
  - Verify: for each of the 17 files listed, `grep 'Duongntd/strawberry' <file>` returns no matches. Runtime-critical subset (must pass before push): `apps/coder-worker/system-prompt.md`, `apps/discord-relay/src/discord-bot.ts`, `apps/private-apps/bee-worker/src/config.ts`, `apps/myapps/functions/src/beeIntake.ts`, `apps/myapps/functions/src/index.ts`, `scripts/setup-branch-protection.sh`, `scripts/verify-branch-protection.sh`, `scripts/gce/setup-coder-vm.sh`, `scripts/gce/setup-bee-vm.sh`.

- [ ] **P2-G3** No bare `strawberry.git` URLs remain pointing at the old repo.
  - Verify: `grep -rln 'github.com/Duongntd/strawberry.git' /tmp/strawberry-app/` returns no matches.

- [ ] **P2-G4** Docs that intentionally reference strawberry (agent-infra) use the full plan-permalink form per §7 convention.
  - Verify: spot-check `docs/architecture/git-workflow.md`, `docs/architecture/deployment.md` — any surviving `strawberry` mention must be in the form `github.com/Duongntd/strawberry/blob/main/plans/...` (permalink to a plan), not a bare slug in a deploy/auth context.

- [ ] **P2-G5** Phase 2 commit exists with the retarget diff.
  - Verify: `git -C /tmp/strawberry-app log --oneline | grep -i 'retarget\|strawberry-app'` returns at least one entry, OR the single squash commit in Phase 1 already includes the retargets (acceptable alternative — verify via `git show --stat HEAD`).

- [ ] **P2-G6** Build still green after retarget.
  - Verify: re-run `cd /tmp/strawberry-app && npx turbo run build --dry-run; echo "exit=$?"` — exit `0`.

---

## Phase 3 gate — pushed, provisioned, protected

Goal: strawberry-app is live on GitHub, fully secret-loaded, branch-protected, and Firebase-bound.

- [ ] **P3-G1** strawberry-app is public and visible.
  - Verify: `gh repo view harukainguyen1411/strawberry-app --json visibility,isPrivate,name | jq` returns `"visibility":"PUBLIC"` and `"isPrivate":false`.

- [ ] **P3-G2** `main` on strawberry-app matches the scratch-tree squash commit SHA.
  - Verify: `gh api repos/harukainguyen1411/strawberry-app/commits/main --jq .sha` equals `git -C /tmp/strawberry-app rev-parse HEAD`.

- [ ] **P3-G3** All 17 GitHub secrets are present in strawberry-app.
  - Verify: `gh secret list --repo harukainguyen1411/strawberry-app --json name | jq -r '.[].name' | sort` — output must contain (as a superset) the 17 names: `AGE_KEY`, `AGENT_GITHUB_TOKEN`, `BOT_WEBHOOK_SECRET`, `CF_ACCOUNT_ID`, `CF_API_TOKEN`, `FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`, `GCP_SA_KEY_PROD`, `GCP_SA_KEY_STAGING`, `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_APP_ID`, `VITE_FIREBASE_AUTH_DOMAIN`, `VITE_FIREBASE_MEASUREMENT_ID`, `VITE_FIREBASE_MESSAGING_SENDER_ID`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_STORAGE_BUCKET`, and (per §6.1 note) `BEE_SISTER_UIDS` if Duong confirmed it's provisioned.

- [ ] **P3-G4** Every secret's `updatedAt` is on or after the Phase 3 start timestamp (rules out stale copies).
  - Verify: `gh secret list --repo harukainguyen1411/strawberry-app --json name,updatedAt | jq '.[] | select(.updatedAt < "<PHASE_3_START_ISO>")'` returns no entries.

- [ ] **P3-G5** `.github/branch-protection.json` in strawberry-app matches the 5-context spec from `plans/approved/2026-04-17-branch-protection-enforcement.md` §1.
  - Verify: `gh api repos/harukainguyen1411/strawberry-app/contents/.github/branch-protection.json --jq .content | base64 -d | jq '.required_status_checks.contexts | sort'` equals `["Playwright E2E","QA report present (UI PRs)","regression-test check","unit-tests","xfail-first check"]`.

- [ ] **P3-G6** Live branch-protection rule on strawberry-app `main` matches the JSON spec.
  - Verify: `gh api repos/harukainguyen1411/strawberry-app/branches/main/protection --jq '{contexts: .required_status_checks.contexts | sort, strict: .required_status_checks.strict, reviews: .required_pull_request_reviews.required_approving_review_count, enforce_admins: .enforce_admins.enabled, last_push_approval: .required_pull_request_reviews.require_last_push_approval}'` equals `{"contexts":["Playwright E2E","QA report present (UI PRs)","regression-test check","unit-tests","xfail-first check"],"strict":true,"reviews":1,"enforce_admins":true,"last_push_approval":true}`.

- [ ] **P3-G7** `scripts/verify-branch-protection.sh` exits 0 against strawberry-app.
  - Verify: `REPO=harukainguyen1411/strawberry-app bash scripts/verify-branch-protection.sh; echo "exit=$?"` returns `exit=0`.

- [ ] **P3-G8** GitHub labels are provisioned on strawberry-app.
  - Verify: `gh label list --repo harukainguyen1411/strawberry-app --json name | jq 'length'` returns ≥ the baseline count present on strawberry (`gh label list --repo Duongntd/strawberry --json name | jq 'length'`).

- [ ] **P3-G9** Firebase CI/CD GitHub App is installed on strawberry-app.
  - Verify: open `https://github.com/harukainguyen1411/strawberry-app/settings/installations` (or `gh api /repos/harukainguyen1411/strawberry-app/installations --jq '.installations[] | select(.app_slug=="firebase-app-hosting") // select(.app_slug | contains("firebase")) | .app_slug'`) returns a Firebase app entry.

- [ ] **P3-G10** Firebase CI/CD GitHub App is NOT installed on strawberry (prevents dual-deploy).
  - Verify: `gh api /repos/Duongntd/strawberry/installations --jq '.installations[] | select(.app_slug | contains("firebase"))'` returns empty output. If the API path is restricted, inspect `https://github.com/Duongntd/strawberry/settings/installations` by hand — no Firebase entry present.

- [ ] **P3-G11** A new fine-grained PAT scoped to strawberry-app is minted and its encrypted blob committed to the private repo.
  - Verify: `test -f /Users/duongntd99/Documents/Personal/strawberry/secrets/encrypted/github-triage-pat.txt.age` AND `git -C /Users/duongntd99/Documents/Personal/strawberry log --format=%H -n 1 secrets/encrypted/github-triage-pat.txt.age` returns a commit SHA dated on or after migration day.

- [ ] **P3-G12** First (trivial) workflow run on strawberry-app is green across all required contexts.
  - Verify: `gh run list --repo harukainguyen1411/strawberry-app --limit 5 --json conclusion,name,status | jq '[.[] | select(.status=="completed")] | all(.conclusion=="success")'` returns `true`. Required contexts listed in P3-G5 must each have a `conclusion=success` run against `main` or the seed PR.

- [ ] **P3-G13** A green **staging** deploy has completed from strawberry-app.
  - Verify: `gh run list --repo harukainguyen1411/strawberry-app --workflow=<staging-deploy.yml> --limit 3 --json conclusion | jq '[.[] | select(.conclusion=="success")] | length'` ≥ 1. (Workflow filename resolved from the repo's actual `.github/workflows/` directory.)

---

## Phase 4 gate — open PRs replayed

Goal: every non-green or unmerged PR from strawberry either lives on strawberry-app or is explicitly closed with a migration trail.

- [ ] **P4-G1** Every open PR that existed on strawberry at Phase 0 start AND was not merged in Phase 0 now has a corresponding open PR in strawberry-app.
  - Verify: build a mapping file `tasklist/migration-pr-map.md` (or inline in journal) with columns `strawberry PR# | strawberry-app PR# | notes`. Every row must have a strawberry-app PR number OR an explicit "closed, no replay, reason: <...>" note.

- [ ] **P4-G2** Every strawberry PR closed as part of replay carries a migration comment.
  - Verify: for each row in the P4-G1 mapping, `gh pr view <OLD_N> --repo Duongntd/strawberry --json comments --jq '.comments[].body' | grep -i "strawberry-app"` returns at least one match referencing the new PR or the migration plan.

- [ ] **P4-G3** Replayed PRs preserve original author attribution.
  - Verify: for each new PR in strawberry-app replayed from a prior strawberry PR, `gh pr view <NEW_N> --repo harukainguyen1411/strawberry-app --json commits --jq '.commits[].authors[].email'` contains the same email(s) as the original. If agents re-authored commits under `harukainguyen1411`, there must be a co-author trailer preserving the original author.

- [ ] **P4-G4** Dependabot PRs from strawberry are NOT manually replayed (accepted to auto-reopen per §4.5).
  - Verify: `gh pr list --repo harukainguyen1411/strawberry-app --author "app/dependabot" --json number | jq 'length'` may be 0 at Phase 4 end; only P4-G4 fails if an agent manually ported Dependabot PRs (wasted work).

- [ ] **P4-G5** No strawberry PR remains OPEN in a state that will confuse future contributors.
  - Verify: `gh pr list --repo Duongntd/strawberry --state open --json number | jq 'length'` — for each remaining open PR, either it's an agent-infra PR (plans/agents/assessments only — belongs in strawberry) or it's been closed with the P4-G2 comment. No code-path PRs (apps/dashboards/scripts) may remain open on strawberry.

---

## Phase 5 gate — agent memory + architecture updated

Goal: agent memory and cross-repo docs reflect the two-repo world. No post-migration PR references point at old paths.

- [ ] **P5-G1** `agents/*/memory/MEMORY.md` find/replace audit — zero `github.com/Duongntd/strawberry/pull/` references that post-date the migration.
  - Verify: `grep -rn 'github.com/Duongntd/strawberry/pull/' /Users/duongntd99/Documents/Personal/strawberry/agents/*/memory/MEMORY.md` — every result must reference a PR number merged/closed BEFORE Phase 0 cut-line (historical), OR must be corrected to `harukainguyen1411/strawberry-app`.

- [ ] **P5-G2** `agents/*/memory/MEMORY.md` find/replace — code-context `Duongntd/strawberry` slugs updated.
  - Verify: `grep -rn 'Duongntd/strawberry' /Users/duongntd99/Documents/Personal/strawberry/agents/*/memory/MEMORY.md` — every remaining match is either in a historical-commit-SHA context (acceptable) OR in a quoted transcript (acceptable — transcripts are records). No active "current repo is X" references point at the old slug.

- [ ] **P5-G3** `architecture/cross-repo-workflow.md` exists in strawberry and documents §7 conventions.
  - Verify: `test -f /Users/duongntd99/Documents/Personal/strawberry/architecture/cross-repo-workflow.md` AND `grep -c 'strawberry-app' /Users/duongntd99/Documents/Personal/strawberry/architecture/cross-repo-workflow.md` ≥ 5 (the doc references the new repo at least five times across the cross-repo conventions).

- [ ] **P5-G4** `architecture/git-workflow.md`, `architecture/pr-rules.md`, root `CLAUDE.md`, and `agents/evelynn/CLAUDE.md` name both repos explicitly.
  - Verify: for each file, `grep -c 'strawberry-app' <file>` ≥ 1 AND `grep -c 'agent-infra\|agent infra' <file>` ≥ 1 (both repos named, with the role distinction present).

- [ ] **P5-G5** The migration update commit to strawberry is in place.
  - Verify: `git -C /Users/duongntd99/Documents/Personal/strawberry log --oneline --grep="migration — update agent memory"` returns ≥ 1 commit, authored on or after migration day.

- [ ] **P5-G6** `scripts/plan-promote.sh` (private repo) still functions after any edits — smoke test with a throwaway plan move is optional but a `bash -n scripts/plan-promote.sh` syntax check is required.
  - Verify: `bash -n /Users/duongntd99/Documents/Personal/strawberry/scripts/plan-promote.sh; echo "exit=$?"` returns `exit=0`.

- [ ] **P5-G7** `architecture/README.md` in strawberry lists `cross-repo-workflow.md` in its index.
  - Verify: `grep -F 'cross-repo-workflow' /Users/duongntd99/Documents/Personal/strawberry/architecture/README.md` returns at least one match.

---

## Phase 6 gate — 7-day stability, code paths purged from strawberry

Goal: strawberry-app has run clean for a week; strawberry is stripped of code paths.

- [ ] **P6-G1** At least 7 calendar days have elapsed since Phase 3 Firebase-binding cutover.
  - Verify: `date -u +%s` minus the cutover timestamp recorded in `agents/caitlyn/journal/2026-04-*.md` is ≥ 604800 (7 × 86400).

- [ ] **P6-G2** During the 7-day window, strawberry-app produced ≥ 1 green staging deploy AND ≥ 1 green prod deploy with no rollbacks.
  - Verify: `gh run list --repo harukainguyen1411/strawberry-app --workflow=<prod-deploy.yml> --limit 20 --created ">=<PHASE3_CUTOVER_ISO>" --json conclusion | jq '[.[] | select(.conclusion=="success")] | length'` ≥ 1 AND `gh run list ... | jq '[.[] | select(.conclusion=="failure")] | length'` equals 0. Same check against the staging-deploy workflow.

- [ ] **P6-G3** No `scripts/deploy/rollback.sh` invocation recorded during the 7-day window.
  - Verify: `gh run list --repo harukainguyen1411/strawberry-app --limit 100 --created ">=<PHASE3_CUTOVER_ISO>" --json name | jq '.[] | select(.name | test("rollback"; "i"))'` returns empty.

- [ ] **P6-G4** No incident report filed against strawberry-app during the 7-day window.
  - Verify: `ls /Users/duongntd99/Documents/Personal/strawberry/incidents/2026-04-*-strawberry-app-*.md 2>/dev/null` returns no results, OR any result has been resolved and linked to a fix PR.

- [ ] **P6-G5** Phase 6 purge commit exists in strawberry.
  - Verify: `git -C /Users/duongntd99/Documents/Personal/strawberry log --oneline --grep="purge code paths migrated to strawberry-app"` returns ≥ 1 commit.

- [ ] **P6-G6** After purge, strawberry no longer contains code paths.
  - Verify: for each of `apps/`, `dashboards/`, `.github/workflows/`, `turbo.json`, `firestore.rules`, `ecosystem.config.js` — `test -e /Users/duongntd99/Documents/Personal/strawberry/<path>` fails. (Private-only scripts remain; `scripts/` directory stays pruned per §2.2.)

- [ ] **P6-G7** strawberry `main` is still green (a minimal CI may still run on agent-infra paths; it must not break).
  - Verify: `gh run list --repo Duongntd/strawberry --branch main --limit 3 --json conclusion | jq '[.[] | select(.conclusion=="success")] | length'` ≥ 1 for the post-purge commit.

---

## Migration-complete gate — §9 criteria + added rigor

Migration is declared complete **only when every check below is `[x]`**. This section is a superset of the source plan's §9 list, expanded with verifications.

### Source-plan §9 (verbatim, now verifiable)

- [ ] **M-G1** `harukainguyen1411/strawberry-app` exists, is public, has a green first workflow run.
  - Verify: combines P3-G1 + P3-G12 — both must be `[x]`.

- [ ] **M-G2** All 17 GitHub secrets are present in strawberry-app AND a successful staging deploy has used them.
  - Verify: combines P3-G3 + P3-G13 — both must be `[x]`.

- [ ] **M-G3** Branch protection on strawberry-app matches `2026-04-17-branch-protection-enforcement.md` §1.
  - Verify: P3-G6 `[x]`.

- [ ] **M-G4** `harukainguyen1411` is the repo owner of strawberry-app.
  - Verify: `gh repo view harukainguyen1411/strawberry-app --json owner --jq '.owner.login'` returns `harukainguyen1411`.

- [ ] **M-G5** Firebase GitHub App is installed on strawberry-app and NOT on strawberry.
  - Verify: P3-G9 `[x]` AND P3-G10 `[x]`.

- [ ] **M-G6** One green staging deploy AND one green prod deploy have run from strawberry-app main.
  - Verify: P3-G13 `[x]` AND P6-G2 `[x]` (prod green confirmed).

- [ ] **M-G7** All 13 originally-open PRs are either merged (Phase 0) or re-opened in strawberry-app (Phase 4).
  - Verify: cross-reference the §1 PR list against P0-G1 merged-set + P4-G1 replay-set — union must cover all 13 IDs with no gaps.

- [ ] **M-G8** gitleaks on strawberry-app shows no real findings (allowlisted false positives only).
  - Verify: P1-G4 + P1-G5 both `[x]`, AND a re-run of `gitleaks detect --source=<local-clone-of-strawberry-app> --log-opts="--all" --redact` against the pushed `main` returns zero non-allowlisted findings.

- [ ] **M-G9** `agents/*/memory/MEMORY.md` and `architecture/*.md` reference strawberry-app for code and strawberry for plans — no broken `Duongntd/strawberry/pull/N` links for post-migration PRs.
  - Verify: P5-G1 + P5-G2 + P5-G4 all `[x]`.

- [ ] **M-G10** `architecture/cross-repo-workflow.md` exists in strawberry.
  - Verify: P5-G3 `[x]`.

- [ ] **M-G11** Duong can merge a trivial PR in strawberry-app end-to-end without running out of CI minutes. (The core reason this plan exists.)
  - Verify: run the migration-acceptance smoke — Duong (or an agent on Duong's behalf) opens a trivial no-op PR on strawberry-app (e.g. whitespace change in a README), waits for all 5 required status checks to report `success`, gets one review from the second account, and merges. Capture the PR URL in the session journal. Confirm `gh api /repos/harukainguyen1411/strawberry-app/actions/billing/usage` (if available) or manually verify via repo billing page that Actions minutes are NOT the limiting factor.

### Added rigor (Caitlyn-proposed, beyond §9)

- [ ] **M-G12** No `--admin` merge on strawberry-app after branch protection was applied.
  - Verify: `gh api /repos/harukainguyen1411/strawberry-app/pulls?state=closed --jq '.[] | select(.merged_at != null) | {n: .number, by: .merged_by.login, admin_override: (.auto_merge == null and .merged_by.login == "Duongntd")}'` — manually inspect any entry where `merged_at > <P3-G6 timestamp>`; none should carry an admin-override signature. (Admin-override detection on GitHub is not a first-class API field; rely on audit-log via `gh api /orgs/... /audit-log` if available, or cross-check merge commit messages for bypass notes.)

- [ ] **M-G13** The public-repo `scripts/hooks/pre-commit-secrets-guard.sh` is byte-identical to the private-repo copy (dual-tracked invariant from §2.2).
  - Verify: `diff /Users/duongntd99/Documents/Personal/strawberry/scripts/hooks/pre-commit-secrets-guard.sh <(gh api repos/harukainguyen1411/strawberry-app/contents/scripts/hooks/pre-commit-secrets-guard.sh --jq .content | base64 -d)` — output empty.

- [ ] **M-G14** Post-migration, `apps/private-apps/bee-worker` lives in strawberry-app (public), per §8 decision 6 override.
  - Verify: `gh api repos/harukainguyen1411/strawberry-app/contents/apps/private-apps/bee-worker --jq '.[].name'` returns a file listing (not 404), AND `test -d /Users/duongntd99/Documents/Personal/strawberry/apps/private-apps/bee-worker` fails (post-Phase-6 purge).

- [ ] **M-G15** No `tasklist/migration-pr-map.md` row is left unresolved.
  - Verify: `grep -c '^|' /Users/duongntd99/Documents/Personal/strawberry/tasklist/migration-pr-map.md` (or the journal-inline variant) — every row has either a new PR number or a documented "no replay" reason. No blank "notes" cells on merged/closed PRs.

- [ ] **M-G16** Public repo has no `.age`-encrypted files committed.
  - Verify: `gh api repos/harukainguyen1411/strawberry-app/git/trees/main?recursive=1 --jq '.tree[].path' | grep '\.age$'` returns no matches.

- [ ] **M-G17** The private repo retains all agent-infra paths untouched.
  - Verify: for each of `agents/`, `plans/`, `assessments/`, `secrets/`, `tasklist/`, `incidents/`, `design/`, `mcps/` — `test -d /Users/duongntd99/Documents/Personal/strawberry/<path>` succeeds. (Purge in Phase 6 removes code paths only; agent-infra is preserved.)

---

## Kayn reference — gate IDs by phase

Copy-paste list for Kayn's task-breakdown cross-reference:

- **Phase 0:** P0-G1, P0-G2, P0-G3, P0-G4, P0-G5
- **Phase 1:** P1-G1, P1-G2, P1-G3, P1-G4, P1-G5, P1-G6, P1-G7, P1-G8
- **Phase 2:** P2-G1, P2-G2, P2-G3, P2-G4, P2-G5, P2-G6
- **Phase 3:** P3-G1, P3-G2, P3-G3, P3-G4, P3-G5, P3-G6, P3-G7, P3-G8, P3-G9, P3-G10, P3-G11, P3-G12, P3-G13
- **Phase 4:** P4-G1, P4-G2, P4-G3, P4-G4, P4-G5
- **Phase 5:** P5-G1, P5-G2, P5-G3, P5-G4, P5-G5, P5-G6, P5-G7
- **Phase 6:** P6-G1, P6-G2, P6-G3, P6-G4, P6-G5, P6-G6, P6-G7
- **Migration complete:** M-G1, M-G2, M-G3, M-G4, M-G5, M-G6, M-G7, M-G8, M-G9, M-G10, M-G11, M-G12, M-G13, M-G14, M-G15, M-G16, M-G17

Total: **57 gates.**

---

## Notes on gate design

1. **Every gate is a single `[ ]` line with a one-liner verification.** Long multi-line rituals are anti-Caitlyn. If a check doesn't fit in a single shell command or URL-load, it's probably two checks.
2. **No gate verifies by "agent judgment."** Every gate names the exact artifact (command output, file contents, API response) that proves truth.
3. **Gates are idempotent.** Re-running any verification on a green gate must still return green.
4. **Phase gates are strictly ordered** — P1 can only close if P0 is closed; Migration-complete can only close if P0–P6 all closed.
5. **Gate failure is recoverable by design.** Each gate references a §N rollback point in the source plan; if a gate red-flags, the rollback is documented, not improvised.
6. **Skipped formal TDD trade-off.** Since xfail-first is not enforced for migration ops, these gates ARE the test suite. A gate failing is the equivalent of a test failing — no implementation commit is considered "done" until its gate is green.
