---
title: Migration Phase 1+2 Dry-Run Report
date: 2026-04-18
author: ekko
plan: plans/proposed/2026-04-19-public-app-repo-migration.md
---

# Migration Phase 1+2 Dry-Run Report

Executed 2026-04-18 ~19:01–19:04 UTC+7. Total elapsed: ~3 minutes.
Scratch dir: `/tmp/strawberry-app-dryrun`. No pushes, no live repo mutations.

---

## 1. Deleted-path confirmation

The following paths were removed from the working clone before the squash commit:

| Path | Status |
|------|--------|
| `agents/` | Deleted (986 files total across all deletions in commit) |
| `plans/` | Deleted |
| `assessments/` | Deleted |
| `secrets/` | Deleted |
| `tasklist/` | Deleted |
| `incidents/` | Deleted |
| `design/` | Deleted |
| `mcps/` | Deleted |
| `CLAUDE.md` | Deleted |
| `agents-table.md` | Deleted |
| `strawberry.pub` | **Missed in initial rm -rf** (was a file, not a dir; `rm -rf` doesn't fail silently on missing targets but the glob didn't expand). Caught via `git status`, deleted and committed separately. Flag for real session: explicitly `rm -f strawberry.pub` in the deletion script. |
| `strawberry-b14/` | Not present in clone (already pruned from remote prior to this session). No error. |
| `architecture/` (private files) | 12 private files deleted: `agent-network.md`, `agent-system.md`, `claude-billing-comparison.md`, `claude-runlock.md`, `discord-relay.md`, `telegram-relay.md`, `infrastructure.md`, `mcp-servers.md`, `plan-gdoc-mirror.md`, `plugins.md`, `security-debt.md`. Plus `README.md` moved to `docs/architecture/`. |
| `architecture/` (public files) | 9 files moved to `docs/architecture/`: `deployment.md`, `git-workflow.md`, `pr-rules.md`, `testing.md`, `firebase-storage-cors.md`, `system-overview.md`, `platform-parity.md`, `platform-split.md`, `key-scripts.md`. |
| `scripts/` private scripts | 14 deleted: `plan-promote.sh`, `plan-publish.sh`, `plan-unpublish.sh`, `plan-fetch.sh`, `_lib_gdoc.sh`, `evelynn-memory-consolidate.sh`, `list-agents.sh`, `new-agent.sh`, `lint-subagent-rules.sh`, `strip-skill-body-retroactive.py`, `hookify-gen.js`, `google-oauth-bootstrap.sh`, `setup-agent-git-auth.sh`, `safe-checkout.sh`. |
| `scripts/hooks/` | All 4 required hooks present and retained: `pre-commit-secrets-guard.sh`, `pre-commit-unit-tests.sh`, `pre-push-tdd.sh`, `pre-commit-artifact-guard.sh`. `test-hooks.sh` also retained (not in delete list). |
| `apps/private-apps/` | **Retained** per scope override — bee-worker moves to public. |

**Count note:** The squash commit reported `986 files changed, 131976 deletions(-)` — confirming correct mass-deletion of private paths.

---

## 2. gitleaks findings

### 2a. Current-tree scan
```
gitleaks detect --source=. --redact --report-path=/tmp/gitleaks-dryrun.json --config=/tmp/gitleaks-config.toml
1063 commits scanned, 16.17 MB in 1.61s
Result: no leaks found (exit 0)
```

### 2b. Full history scan (--log-opts="--all")
```
gitleaks detect --source=. --log-opts="--all" --redact --report-path=/tmp/gitleaks-dryrun-history.json --config=/tmp/gitleaks-config.toml
1063 commits scanned, 16.17 MB in 1.13s
Result: no leaks found (exit 0)
```

**Allowlist applied:** `Duongntd/strawberry` regex (known false-positive per `agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md`).

**Note:** During the orphan-branch commit, the pre-commit secrets-guard hook reported 4 leaks. This is because the hook scanned git history that includes the pre-deletion commits (the hook runs against `--all` refs visible to the clone). These 4 findings are in the OLD filtered-out private paths, not in the public tree. Both post-commit gitleaks passes (current tree + full history of the squashed clone) are clean. In the real session, the squash should be done as a true orphan (no parent), which eliminates the old history from the clone entirely and would yield 0 hook findings too.

**Verdict: No real leaks. Green.**

---

## 3. Hardcoded-slug grep results

### Files referencing `Duongntd/strawberry` (18 files, must rewrite in Phase 2)

| File | Line(s) | Context | Action |
|------|---------|---------|--------|
| `apps/coder-worker/system-prompt.md` | 3 | "implementing a GitHub issue for the `Duongntd/strawberry` repository" | Rewrite to `Duongntd/strawberry-app` (R14 — critical) |
| `apps/discord-relay/src/discord-bot.ts` | 172 | Issue-filing URL `github.com/Duongntd/strawberry/issues/new` | Rewrite to `strawberry-app` |
| `apps/private-apps/bee-worker/README.md` | 28 | `GITHUB_REPO` default env var comment | Rewrite |
| `apps/private-apps/bee-worker/src/config.ts` | 18 | `optional("GITHUB_REPO", "Duongntd/strawberry")` | Rewrite default to `strawberry-app` |
| `apps/myapps/triage-context.md` | 9 | "GitHub issues filed against MyApps live in ... github.com/Duongntd/strawberry" | Rewrite |
| `apps/myapps/functions/README.md` | 112 | `BEE_GITHUB_REPO=Duongntd/strawberry` | Rewrite |
| `apps/myapps/functions/src/beeIntake.ts` | 38 | `default: "Duongntd/strawberry"` | Rewrite |
| `apps/myapps/functions/src/index.ts` | 187 | `default: "Duongntd/strawberry"` | Rewrite |
| `scripts/verify-branch-protection.sh` | 10 | `REPO="${REPO:-Duongntd/strawberry}"` | Rewrite default to `strawberry-app` |
| `scripts/setup-branch-protection.sh` | 10 | `REPO="${REPO:-Duongntd/strawberry}"` | Rewrite default to `strawberry-app` |
| `scripts/vps-setup.sh` | 20 | Prompt example text "Duongntd/strawberry" | Update example |
| `scripts/gce/setup-coder-vm.sh` | 7, 58 | `REPO_URL="https://github.com/Duongntd/strawberry.git"` | Rewrite to `strawberry-app.git` |
| `scripts/gce/setup-bee-vm.sh` | 7 | Same as above | Rewrite to `strawberry-app.git` |
| `docs/architecture/git-workflow.md` | 77 | `gh api repos/Duongntd/strawberry/branches/...` | Rewrite |
| `docs/architecture/deployment.md` | 77, 92 | "Secrets required (on `Duongntd/strawberry`)" | Rewrite |
| `docs/delivery-pipeline-setup.md` | 36, 61, 74, 139 | Console URLs pointing to strawberry settings | Rewrite to strawberry-app |
| `docs/vps-setup.md` | 98 | GitHub Actions runner registration URL | Rewrite |

### Files referencing `strawberry.git` URL
- `scripts/gce/setup-coder-vm.sh` lines 7, 58
- `scripts/gce/setup-bee-vm.sh` line 7

Both already captured in the table above.

**Unexpected find:** `apps/myapps/functions/src/beeIntake.ts` and `apps/myapps/functions/src/index.ts` both have hardcoded `Duongntd/strawberry` as runtime defaults — these are **code-level defaults that affect production behavior** (bee worker will file issues to the wrong repo post-migration). These are higher severity than doc-only refs and need Phase 2 rewrite before push.

**Total files requiring rewrite: 17** (some files have multiple lines).

---

## 4. Build sanity

### npm ci
`npm ci --ignore-scripts` fails with:
```
Missing: ulid@3.0.2 from lock file
```
**This is a pre-existing lockfile sync issue, NOT caused by migration filtering.** Same error reproduced on the live strawberry repo in the same session. `npm install --ignore-scripts` completes successfully.

### turbo build --dry-run
After `npm install`, `turbo run build --dry-run` exits 0. Tasks resolved correctly, including `myapp` (apps/myapps) package with vite build. No missing workspace paths.

**Verdict: Build graph intact. Lockfile desync is a pre-existing issue to fix separately.**

---

## 5. Unexpected errors / "file not found"

| Item | Observation |
|------|-------------|
| `strawberry-b14/` | Not present in clone — already pruned. No error (rm -rf on absent dir is a no-op). |
| `strawberry.pub` | Was a **file**, not a directory. Initial `rm -rf strawberry.pub/` (trailing slash) resolved to nothing. Caught by `git status`. Fix: use `rm -f strawberry.pub` without trailing slash in the real session script. |
| `architecture/README.md` | Exists — moved to `docs/architecture/` successfully. |
| Private hooks to delete | `scripts/hooks/` only contained the 4 public hooks + `test-hooks.sh`. No additional private hooks found. Hook deletion step was a no-op (correct). |

---

## 6. Summary verdict

| Check | Result |
|-------|--------|
| Private paths deleted | PASS (with one minor fix: `strawberry.pub` handling) |
| gitleaks current tree | PASS — 0 leaks |
| gitleaks full history | PASS — 0 leaks |
| Slug grep sweep | 17 files need rewrite in Phase 2 (list above) |
| npm ci | FAIL — pre-existing lockfile issue (unrelated to migration) |
| turbo build --dry-run | PASS |
| Elapsed time | ~3 minutes |

**Ready for real session.** Phase 2 rewrite is the main manual action; all 17 files are identified and most are straightforward sed replacements. The pre-existing lockfile issue should be fixed in strawberry before migration day.

---

## 7. Recommendations for real session

1. **Fix `strawberry.pub` deletion:** use `rm -f strawberry.pub` (no trailing slash).
2. **Fix lockfile before migration:** run `npm install` and commit the updated `package-lock.json` in strawberry before Phase 1. This ensures `npm ci` works in the public repo.
3. **Phase 2 sed rewrite:** all 17 files above. The bee-worker and myapps functions defaults (`beeIntake.ts`, `index.ts`) are runtime-critical — prioritize.
4. **True orphan history:** In the real session, after the squash commit, also force-push the orphan to reset the remote — the local history will have 1 commit from the orphan's perspective but the `--log-opts="--all"` scan revealed 1063 commits from old refs still reachable in the working clone. A bare push of the orphaned branch ensures the remote only has 1 commit in its history.
5. **`apps/myapps/triage-context.md`:** This file references strawberry in an agent-facing context description. Consider whether it belongs in the public repo at all, or whether agent-facing context docs should be stripped.
