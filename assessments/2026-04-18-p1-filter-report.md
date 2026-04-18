---
title: Migration Phase 1 Filter Report
date: 2026-04-18
author: ekko
plan: plans/approved/2026-04-19-public-app-repo-migration.md
---

# Migration Phase 1 Filter Report

Executed 2026-04-18. This is the real run (not dry-run). Scratch dir: `/tmp/strawberry-app-migration`. No pushes yet — Phase 3 will push.

---

## 1. Base SHA tag

- Tag: `migration-base-2026-04-18`
- SHA: `af2edbc0f2ba1970024da652a499a8787d683f80`
- Pushed to `origin` (Duongntd/strawberry): confirmed

---

## 2. Deleted-path confirmation

| Path | Status |
|------|--------|
| `agents/` | Deleted |
| `plans/` | Deleted |
| `assessments/` | Deleted |
| `secrets/` | Deleted |
| `tasklist/` | Deleted |
| `incidents/` | Deleted |
| `design/` | Deleted |
| `mcps/` | Deleted |
| `CLAUDE.md` | Deleted |
| `agents-table.md` | Deleted |
| `strawberry.pub` | Deleted (`rm -f`, no trailing slash per dry-run learning) |
| `strawberry-b14/` | Not present in clone (pruned prior). No error. |
| `.mcp.json` | Deleted (agent-infra; contained Telegram bot token in old history — see §4) |
| `.claude/` | Deleted (agent definitions and cursor skills — private infra) |
| `apps/myapps/.cursor/` | Deleted (cursor skills — agent tooling not for public repo) |
| `architecture/` private files | 11 deleted: `agent-network.md`, `agent-system.md`, `claude-billing-comparison.md`, `claude-runlock.md`, `discord-relay.md`, `telegram-relay.md`, `infrastructure.md`, `mcp-servers.md`, `plan-gdoc-mirror.md`, `plugins.md`, `security-debt.md` |
| `architecture/` public files | 9 moved to `docs/architecture/`: `deployment.md`, `git-workflow.md`, `pr-rules.md`, `testing.md`, `firebase-storage-cors.md`, `system-overview.md`, `platform-parity.md`, `platform-split.md`, `key-scripts.md` + `README.md` |
| `scripts/` private scripts | 14 deleted: `plan-promote.sh`, `plan-publish.sh`, `plan-unpublish.sh`, `plan-fetch.sh`, `_lib_gdoc.sh`, `evelynn-memory-consolidate.sh`, `list-agents.sh`, `new-agent.sh`, `lint-subagent-rules.sh`, `strip-skill-body-retroactive.py`, `hookify-gen.js`, `google-oauth-bootstrap.sh`, `setup-agent-git-auth.sh`, `safe-checkout.sh` |
| `scripts/hooks/` | All 4 required hooks retained: `pre-commit-secrets-guard.sh`, `pre-commit-unit-tests.sh`, `pre-push-tdd.sh`, `pre-commit-artifact-guard.sh`. `test-hooks.sh` also retained. No others to delete. |
| `apps/private-apps/` | **Retained** per §8 decision 6 — bee-worker moves to public |

**Squash commit:** Single orphan `1b6865f`, 602 files, 115,577 insertions.

**Additional deletions vs dry-run (anomalies caught in real run):**
- `.mcp.json` deleted (not in plan's explicit deletion list, but is private agent-infra — contained Telegram bot token in git history)
- `.claude/` deleted (agent definitions/skills — private infra)
- `apps/myapps/.cursor/` deleted (triggered `curl-auth-header` gitleaks false positives on placeholder `YOUR_TOKEN` strings in documentation)

---

## 3. gitleaks findings

### 3a. Current orphan commit only (`--log-opts="HEAD"`, 1 commit scanned)
```
gitleaks detect --source=. --redact --log-opts="HEAD" --report-path=/tmp/gitleaks-p1-head.json
1 commits scanned
Result: no leaks found (exit 0)
```

**PASS — 0 leaks in the commit that will be pushed to public repo.**

### 3b. Full history scan (`--log-opts="--all"`, 1084 commits from origin)
```
gitleaks detect --source=. --redact --log-opts="--all" --report-path=/tmp/gitleaks-p1-history.json
1084 commits scanned
Result: 10 leaks found (exit 1)
```

All 10 findings are in OLD origin/main commits that will NOT be pushed to `harukainguyen1411/strawberry-app` (the orphan eliminates prior history). Details:

| Rule | File | Commit | Assessment |
|------|------|--------|------------|
| `curl-auth-header` | `agents/evelynn/transcripts/2026-04-17-e0b93856.md` | `c6951fee` | Private path (deleted). Template `YOUR_TOKEN` placeholder in transcript. False positive. NOT in public tree. |
| `telegram-bot-api-token` | `.mcp.json` | `0fe111c2` | **Real Telegram bot token** in old private commit. Path deleted. NOT in public tree. Token should be rotated (see §4). |
| `curl-auth-header` (7x) | `apps/myapps/.cursor/skills/github-issue-implementation/` | `d77b2125` | Template `YOUR_TOKEN` placeholder in cursor skill docs. False positives. Path deleted. NOT in public tree. |
| `gcp-api-key` | `apps/myapps/src/firebase/config.ts` | `6311a59d` | Firebase Web API key in old commit. Current tree uses `import.meta.env.*` (clean). Firebase Web API keys are designed to be public (security enforced via Firebase Security Rules). NOT in public tree. |

**Allowlist applied:** `Duongntd/strawberry` regex (known false positive per camille learnings). No new allowlist entries needed beyond what's in `.gitleaks.toml`.

---

## 4. Security flags requiring follow-up (not blockers for Phase 2/3)

1. **Telegram bot token** in `Duongntd/strawberry` private history (`0fe111c2:.mcp.json`). This is in the private repo's history — not exposed publicly. However, per risk register R1 ("Rotate any found secret regardless of recency"), this token should be rotated. Action: Duong rotates via Telegram BotFather when convenient. Not a Phase 2/3 blocker.

2. **Firebase Web API key** in `Duongntd/strawberry` private history (`6311a59d:apps/myapps/src/firebase/config.ts`). Firebase Web API keys are intentionally public (browser SDK requires them). Current code correctly uses env vars. No rotation needed.

---

## 5. Commit count on filtered main

```
git log --oneline | wc -l  → 1
```

Exactly 1 commit on main. Working tree clean. Orphan history — no ancestry to origin/main.

---

## 6. Path to filtered tree

`/tmp/strawberry-app-migration`

Ready for Phase 2 (Viktor) at that path.

---

## 7. Summary verdict

| Check | Result |
|-------|--------|
| Base tag pushed | PASS — `migration-base-2026-04-18` = `af2edbc0f2ba1970024da652a499a8787d683f80` |
| Private paths deleted | PASS (+ 3 additional paths caught in real run: `.mcp.json`, `.claude/`, `apps/myapps/.cursor/`) |
| gitleaks orphan commit | PASS — 0 leaks |
| gitleaks full history (old origin) | 10 findings, all in OLD commits NOT in public tree. No blockers. |
| Commit count on filtered main | PASS — 1 |
| Working tree clean | PASS |
| Security flags | Telegram bot token in private history — rotation recommended but not blocking |

**Ready for Phase 2: YES**
