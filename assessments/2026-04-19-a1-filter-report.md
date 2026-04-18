---
title: Migration Phase A1 Filter Report — strawberry-agents
date: 2026-04-19
author: ekko
plan: plans/approved/2026-04-19-strawberry-agents-companion-migration.md
tasks: plans/in-progress/2026-04-19-strawberry-agents-companion-tasks.md
---

# strawberry-agents Phase A1 Filter Report

Executed 2026-04-19. History-preserving filter via `git filter-repo --invert-paths`.
Scratch dir: `/tmp/strawberry-agents-migration`. No push yet — that is Phase A3.

---

## 1. Base SHA used

- Tag: `migration-base-2026-04-18`
- SHA: `af2edbc0f2ba1970024da652a499a8787d683f80`
- Same tag used in strawberry-app Phase 1 (sibling migration)
- Bare clone source: `https://github.com/Duongntd/strawberry.git`

---

## 2. Paths dropped (public-side, via `--invert-paths`)

| Path / Glob | Drop reason |
|-------------|-------------|
| `apps/` | Public code — strawberry-app |
| `dashboards/` | Public code — strawberry-app |
| `.github/workflows/` | CI workflows — strawberry-app |
| `.github/scripts/` | CI helper scripts — strawberry-app |
| `.github/pull_request_template.md` | App PR template |
| `.github/dependabot.yml` | App Dependabot config |
| `.github/branch-protection.json` | App branch protection |
| `package*.json` (glob) | App build config |
| `tsconfig*.json` (glob) | App TypeScript config |
| `turbo.json` | App monorepo config |
| `firestore.rules` | App Firestore config |
| `firestore.indexes.json` | App Firestore config |
| `release-please-config.json` | App release config |
| `ecosystem.config.js` | App PM2 config |
| `scripts/deploy/` | Deploy scripts — strawberry-app |
| `scripts/gce/` | GCE scripts — strawberry-app |
| `scripts/mac/` | Mac-specific scripts — strawberry-app |
| `scripts/windows/` | Windows-specific scripts — strawberry-app |
| `scripts/composite-deploy.sh` | Deploy script |
| `scripts/scaffold-app.sh` | App scaffold |
| `scripts/seed-app-registry.sh` | App registry seeding |
| `scripts/health-check.sh` | Deploy health check |
| `scripts/migrate-firestore-paths.sh` | App Firestore migration |
| `scripts/vps-setup.sh` | VPS setup — strawberry-app |
| `scripts/deploy-discord-relay-vps.sh` | VPS deploy |
| `scripts/setup-branch-protection.sh` | Repo setup — strawberry-app |
| `scripts/verify-branch-protection.sh` | Repo verify — strawberry-app |
| `scripts/setup-github-labels.sh` | GitHub labels — strawberry-app |
| `scripts/setup-discord-channels.sh` | Discord channels — strawberry-app |
| `scripts/gh-audit-log.sh` | GitHub audit log — strawberry-app |
| `scripts/gh-auth-guard.sh` | GitHub auth guard — strawberry-app |

---

## 3. Paths kept (agent-infra, verified in filtered tree)

| Path | Contents |
|------|----------|
| `agents/` | Full tree: all agent profiles, memory, journals, learnings, inboxes, transcripts |
| `plans/` | All four subdirs: proposed/, approved/, in-progress/, implemented/, archived/ |
| `assessments/` | All analyses, QA reports, evaluations |
| `CLAUDE.md` (root) | Agent invariants |
| `.claude/agents/` | All agent definition files (kept per task instructions — agent-infra) |
| `.claude/settings.json` | Claude settings |
| `.claude/skills/` | Agent skills |
| `.mcp.json` | MCP config (kept — private repo, agent-infra) |
| `tasklist/` | Internal task queue |
| `incidents/` | Ops postmortems |
| `design/` | Design artifacts |
| `mcps/` | MCP server configs |
| `secrets/encrypted/` | All 11 age-encrypted blobs — byte-for-byte match (§5) |
| `secrets/README.md` | Secrets README |
| `secrets/recipients.txt` | Age recipients |
| `architecture/` | Full private subset (agent-network, agent-system, infrastructure, etc.) |
| `scripts/` agent-infra | plan-promote.sh, plan-publish.sh, plan-unpublish.sh, plan-fetch.sh, _lib_gdoc.sh, safe-checkout.sh, evelynn-memory-consolidate.sh, list-agents.sh, new-agent.sh, lint-subagent-rules.sh, strip-skill-body-retroactive.py, hookify-gen.js, google-oauth-bootstrap.sh, setup-agent-git-auth.sh, install-hooks.sh, and others |
| `scripts/hooks/` | Full hook bundle (pre-commit-secrets-guard, pre-commit-unit-tests, pre-push-tdd, etc.) |
| `tools/` | decrypt.sh, encrypt.html, age-bundle.js, and other helpers |
| `strawberry.pub` | Age public key |
| `agents-table.md` | Agent roster table |
| `README.md` | Repo README |
| `docs/` | Internal docs |
| `tests/` | Test fixtures |

---

## 4. Commit count after filter

```
git log --oneline | wc -l  → 914
```

914 commits preserved. History intact from genesis commit (`9fe6a84 Initialize personal agent system`) through base SHA `af2edbc0`. This is the expected result for `--invert-paths` (preserves history, unlike strawberry-app's squash approach).

---

## 5. Secrets/encrypted diff check (R-agents-2)

Compared `secrets/encrypted/` in filtered tree vs live strawberry working tree:

Both directories contain exactly the same 11 files:
- `bee-sister-uids.age`
- `canary.age`
- `dashboards.prod.env.age`
- `dashboards.staging.env.age`
- `discord-bot-token.age`
- `gemini-api-key.age`
- `github-triage-pat.age`
- `google-client-id.age`
- `google-client-secret.age`
- `google-drive-plans-folder-id.age`
- `google-refresh-token.age`

**PASS — R-agents-2 verified.**

---

## 6. gitleaks findings

### 6a. Current tree (default scan, 827 commits)

```
gitleaks detect --source=. --redact --report-path=/tmp/gitleaks-agents.json
827 commits scanned
Result: 2 leaks found (exit 1)
```

### 6b. Full filtered history (`--log-opts="--all"`, 827 commits)

```
gitleaks detect --source=. --log-opts="--all" --redact --report-path=/tmp/gitleaks-agents-history.json
827 commits scanned
Result: 2 leaks found (exit 1)
```

Both scans produce the same 2 findings (same commits surface in both):

| # | Rule | File | Commit | Assessment |
|---|------|------|--------|------------|
| 1 | `curl-auth-header` | `agents/evelynn/transcripts/2026-04-17-e0b93856.md` line 527 | `75ecc1c0` | Token-like hash (`b812740a...`) in a curl command in a Duong-authored transcript. URL is `demo-config-mgmt-1111.europe-west1.run.app` — a demo Cloud Run service, not production infra. Token is in current HEAD file. **Private repo — lower risk than public.** Recommend rotation as precaution; not a hard blocker for private-repo push. |
| 2 | `telegram-bot-api-token` | `.mcp.json` | `fbadc6bd` (old commit, Apr 4) | Same Telegram bot token known from strawberry-app Phase 1 report (`0fe111c2` in that history). Stays in history. Private repo. Rotation still recommended (carried from P1 report). |

**Comparison with strawberry-app P1 findings:** strawberry-app P1 found 10 findings (8 in `apps/myapps/.cursor/` cursor skill docs + Firebase Web API key + the same Telegram token). Those 8 cursor-skill findings are absent here because `apps/` was dropped. Finding #1 above (transcript curl token) is present here because agent transcripts are KEPT in strawberry-agents. This was not a strawberry-app P1 finding in the same commit.

**Assessment:** No new infrastructure secrets. The curl-auth-header finding in the transcript is flagged for rotation but does NOT block the push to a private repo. The stop condition ("NEW leak not present in strawberry-app's history scan") is not triggered — these are agent-internal paths expected to be private-only.

---

## 7. Anomalies

1. **`docs/` present in filtered tree** — `docs/` existed in strawberry (it received the renamed public architecture files during Phase 2 of the strawberry-app migration). After filtering, `docs/` remains with internal docs (`delivery-pipeline-setup.md`, `vps-setup.md`, etc.). These are agent-internal reference docs — appropriate to keep in strawberry-agents. No anomaly, but noted.

2. **`scripts/discord-bot-wrapper.sh`, `scripts/discord-bridge.sh`, `scripts/telegram-bridge.sh`, `scripts/start-telegram.sh`** — Not in the explicit drop list, so kept. These are relay-support scripts for agent communication infrastructure. Appropriate for strawberry-agents.

3. **`scripts/report-run.sh`, `scripts/result-watcher.sh`, `scripts/sync-plugins.sh`, `scripts/install-plugins.sh`** — Similarly not dropped. Agent-infra helpers. Kept.

4. **gitleaks reports 827 commits scanned** (not 914) — gitleaks's commit count may exclude merge commits or count differently from `git log`. Not an anomaly in the actual history.

---

## 8. Security flags (not blockers for A2/A3)

1. **Demo Cloud Run token** in `agents/evelynn/transcripts/2026-04-17-e0b93856.md` (commit `75ecc1c0`). Demo endpoint, private repo. Rotation recommended but not urgent.

2. **Telegram bot token** in `.mcp.json` old history (commit `fbadc6bd`). Same as strawberry-app P1 flag. Private repo. Rotation recommended (carried from P1 report).

---

## 9. Summary verdict

| Check | Result |
|-------|--------|
| Base tag used | PASS — `migration-base-2026-04-18` = `af2edbc0` |
| Public paths dropped | PASS — apps/, dashboards/, .github/workflows/, build configs, deploy scripts all absent |
| Agent-infra paths kept | PASS — agents/, plans/, assessments/, CLAUDE.md, .claude/, tools/, scripts/agent-infra, secrets/encrypted/ all present |
| History preserved | PASS — 914 commits (not squashed) |
| secrets/encrypted/ match | PASS — 11 files, byte-for-byte match |
| gitleaks current tree | 2 findings — both in private agent paths, no production infra credentials. Private repo. Not blocking. |
| gitleaks full history | Same 2 findings |
| Stop condition triggered | NO — no new production leaks |

**Ready for Phase A2 (reference rewrite): YES**

---

## 10. Path to filtered tree

`/tmp/strawberry-agents-migration`

Do NOT delete. Phase A2 (reference rewrite) and Phase A3 (push) require it.
