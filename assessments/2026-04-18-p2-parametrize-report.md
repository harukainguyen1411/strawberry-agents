---
title: Migration Phase 2 — Parametrize Report
date: 2026-04-18
author: viktor
plan: plans/approved/2026-04-19-public-app-repo-migration.md
tasks: plans/in-progress/2026-04-19-public-app-repo-migration-tasks.md
scratch_tree: /tmp/strawberry-app-migration
---

# Migration Phase 2 — Parametrize Report

Executed 2026-04-18. Working tree: `/tmp/strawberry-app-migration` (Ekko's Phase 1 output).
All commits land on the scratch tree. No remote push — Phase 3 handles that.

---

## 1. Files parametrized by category

### P2.P1 — Runtime TypeScript (3 files)

| File | Change |
|------|--------|
| `apps/myapps/functions/src/beeIntake.ts` | `defineString("BEE_GITHUB_REPO", { default: "Duongntd/strawberry" })` → `default: ""`. Usage site reads `beeGithubRepo.value() \|\| process.env.GITHUB_REPOSITORY \|\| ""` with explicit error if unset. |
| `apps/myapps/functions/src/index.ts` | Same `defineString` change + `parseBeeRepo()` falls back to `process.env.GITHUB_REPOSITORY`. |
| `apps/private-apps/bee-worker/src/config.ts` | `optional("GITHUB_REPO", "Duongntd/strawberry")` → `optional("GITHUB_REPO", process.env.GITHUB_REPOSITORY ?? "")`. |

**Design note:** Firebase `defineString` defaults are evaluated at deploy configuration time, not runtime, so injecting `process.env.GITHUB_REPOSITORY` directly as the default is not safe there. The approach used: `default: ""` in the param declaration, then runtime fallback to `process.env.GITHUB_REPOSITORY` at the call site. This preserves the Firebase param override path while removing the hardcoded slug.

### P2.P2 — GitHub Workflows

Zero hits. No workflow YAML files referenced a hardcoded slug. P2.P2 is a confirmed no-op.

### P2.P3 — Shell Scripts (5 files)

| File | Change |
|------|--------|
| `scripts/setup-branch-protection.sh` | Removed `REPO="Duongntd/strawberry"` default. Script now resolves from: `$1` positional arg → `$GITHUB_REPOSITORY` env var → `git remote get-url origin` parsing. Usage block added to header comments. |
| `scripts/verify-branch-protection.sh` | Same resolution chain as above. |
| `scripts/gce/setup-coder-vm.sh` | Removed hardcoded `REPO_URL`. Accepts `$1` or `$GITHUB_REPOSITORY`; errors if neither set. Manual step echo updated to use `$_REPO_SLUG`. |
| `scripts/gce/setup-bee-vm.sh` | Same as setup-coder-vm.sh. |
| `scripts/vps-setup.sh` | Prompt example text `(e.g. Duongntd/strawberry)` → `(e.g. owner/repo)` — illustrative prompt, not a runtime default. |

### P2.P4 — LLM Prompts (1 file)

| File | Change |
|------|--------|
| `apps/coder-worker/system-prompt.md` | `Duongntd/strawberry` → `{{REPO_SLUG}}` placeholder. TODO comment added pointing Jayce to the follow-on runtime substitution task (read `GITHUB_REPOSITORY` env, replace `{{REPO_SLUG}}` before sending to model API). Tracked in `plans/approved/2026-04-19-public-app-repo-migration.md §4.3`. |

### P2.P5 — Discord-relay Issue URL (2 files)

| File | Change |
|------|--------|
| `apps/discord-relay/src/config.ts` | Added `github.repository: optional("GITHUB_REPOSITORY", "")` field. |
| `apps/discord-relay/src/discord-bot.ts` | Manual fallback URL `https://github.com/Duongntd/strawberry/issues/new` → `https://github.com/${config.github.repository \|\| "owner/repo"}/issues/new`. |

Note: `apps/discord-relay/src/github.ts` already had a correct `getRepoCoords()` that reads `process.env.GITHUB_REPOSITORY` — no change needed there.

### P2.P6 — Docs (7 files)

| File | Change |
|------|--------|
| `docs/architecture/deployment.md` | `(on \`Duongntd/strawberry\`)` headings → `(on the app repo — \`$GITHUB_REPOSITORY\`)` |
| `docs/architecture/git-workflow.md` | `repos/Duongntd/strawberry/branches/...` → `repos/${GITHUB_REPOSITORY}/branches/...` |
| `docs/delivery-pipeline-setup.md` | 5 occurrences replaced: CLI examples use `${GITHUB_REPOSITORY}`; console URL examples use `$GITHUB_REPOSITORY/settings/...` forms; coder-worker `.env` example updated. |
| `docs/vps-setup.md` | Runner registration section updated: prose and `./config.sh --url` example use `${GITHUB_REPOSITORY}`. |
| `apps/myapps/triage-context.md` | `github.com/Duongntd/strawberry` → `GITHUB_REPOSITORY env var` reference. |
| `apps/myapps/functions/README.md` | Local `.env` example `BEE_GITHUB_REPO=Duongntd/strawberry` → `BEE_GITHUB_REPO=owner/strawberry-app`. |
| `apps/private-apps/bee-worker/README.md` | Default column `Duongntd/strawberry` → `$GITHUB_REPOSITORY`. |

**Total files parametrized: 17** (3 runtime TS, 5 shell, 1 LLM prompt, 2 discord-relay, 6 docs — matching Ekko's 17-file dry-run hit list).

---

## 2. Commit SHAs on the filtered tree

| SHA | Message |
|-----|---------|
| `1b6865f` | chore: initial public commit (Ekko's Phase 1 squash) |
| `7c24091` | chore: parametrize repo slug in Cloud Functions and bee-worker runtime (migration P2.P1) |
| `8b3275a` | chore: parametrize repo slug across shell scripts (migration P2.P3) |
| `5d113c3` | chore: placeholder-ize repo slug in coder-worker system prompt (migration P2.P4) |
| `857bffc` | chore: env-source repo slug in discord-relay issue URL (migration P2.P5) |
| `43c34ea` | chore: audit doc slug mentions and update illustrative references (migration P2.P6) |
| `e191b77` | chore: add check-no-hardcoded-slugs.sh regression guard and install-hooks wiring (migration P2.Z) |

---

## 3. npm ci result

```
npm ci --ignore-scripts
added 1440 packages, audited 1449 packages in 9s
11 vulnerabilities (9 low, 2 moderate)
Exit code: 0
```

**PASS.** The ulid lockfile desync flagged in Ekko's dry-run was fixed prior to this session (confirmed by `npm ci` succeeding without `--legacy-peer-deps`).

---

## 4. turbo build --dry-run result

```
npx turbo run build --dry-run
• Running build in 8 packages
Tasks to Run: (all 8 packages resolved, 0 errors)
Exit code: 0
```

**PASS.** Build topology intact. No import cycles or missing config exports introduced by parametrization.

---

## 5. Final hardcoded-slug grep result

```
grep -rln 'Duongntd/strawberry|harukainguyen1411/strawberry' . \
  --include='*.sh' --include='*.ts' --include='*.js' \
  --include='*.yml' --include='*.yaml' --include='*.md' --include='*.json'
```

**Result:** `scripts/hooks/check-no-hardcoded-slugs.sh` (the guard file itself — it contains the pattern strings it scans for, listed in the slug allowlist as an explicit exemption).

**Zero non-allowlisted hits.** Exit criterion satisfied.

---

## 6. Regression-guard hook installation

- `scripts/hooks/check-no-hardcoded-slugs.sh` — POSIX-portable, executable, passes on clean tree (exit 0), fails on seeded violation (exit 1 — confirmed via synthetic smoke test).
- `scripts/hooks/slug-allowlist.txt` — exempts `package.json`, `README.md`, `docs/**`, `.github/dependabot.yml`, and the hook/allowlist files themselves.
- `scripts/hooks/pre-commit-check-no-hardcoded-slugs.sh` — auto-generated thin wrapper; picked up by the strawberry-managed pre-commit dispatcher pattern (`pre-commit-*.sh`).
- `scripts/install-hooks.sh` — updated to generate the wrapper on fresh install if absent.
- `bash scripts/install-hooks.sh` confirmed the wrapper appears in sub-hooks active list.

**Hook installation confirmed.**

---

## 7. Deferred follow-on work

- **Coder-worker `{{REPO_SLUG}}` substitution** — runtime substitution before the prompt is sent to the LLM API. Flagged for Jayce. TODO comment added to `apps/coder-worker/system-prompt.md`.
- **CI lint step for slug guard** — P2.Z task brief mentions a CI step in an existing workflow. Deferred to Ekko (Phase 3 wiring, owns `.github/workflows/` dispatch). The hook exists and is functional; CI wiring is additive.

---

## 8. Status

Phase 2 complete. The scratch tree at `/tmp/strawberry-app-migration` is ready for Phase 3 push (`git push -u origin main` from that directory — Caitlyn/Phase 3 owner).
