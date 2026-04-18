# A2 — Cross-repo reference parametrization in strawberry-agents migration tree

**Date:** 2026-04-18
**Session:** A2 task in `/tmp/strawberry-agents-migration` (git filter-repo output, 914 commits)
**Plan:** `plans/approved/2026-04-19-strawberry-agents-companion-migration.md` §4.2

## What was done

Rewrote `Duongntd/strawberry` slug references in the strawberry-agents migration tree.
Commit `f456bae` in `/tmp/strawberry-agents-migration`.

## Files changed (7)

| File | Change |
|------|--------|
| `architecture/git-workflow.md` | Break-glass `gh api` URL → `harukainguyen1411/strawberry-agents` |
| `architecture/deployment.md` | Secrets/variables section headers → `harukainguyen1411/strawberry-app` (workflows live there) |
| `docs/vps-setup.md` | GitHub Actions runner registration URLs + systemd service name → strawberry-app |
| `docs/delivery-pipeline-setup.md` | Security hardening commands, secrets URLs, branch-protection URLs, coder-worker `TRIAGE_TARGET_REPO` → strawberry-app |
| `agents/evelynn/memory/evelynn.md` | Secrets location note → strawberry-app |
| `scripts/discord-bridge.sh` | Added `STRAWBERRY_APP_DIR` env var; `README_PATH` reads from app checkout; `STRAWBERRY_DIR` default updated to strawberry-agents |
| `scripts/discord-bot-wrapper.sh` | discord-relay node path → `/home/runner/strawberry-app/apps/discord-relay/src/index.js` |

## Key decision: what NOT to rewrite (R-agents-1)

Historical/archival files were left untouched:
- All `agents/*/transcripts/**`, `agents/_retired/**`, `agents/*/inbox/**` — past records
- `plans/**`, `assessments/**`, `agents/*/learnings/**` — historical citations
- `agents/azir/memory/MEMORY.md` line 13 — intentionally names `Duongntd/strawberry` as the archive (correct)
- `agents/heimerdinger/memory/MEMORY.md` line 13 — historical session note (CI fix on old repo)
- `agents/evelynn/memory/last-sessions/a7a754c2.md` — billing block note from prior session

## Routing logic for `Duongntd/strawberry` refs

Not all refs map to the same new target:
- **Agent-infra contexts** (branch protection for this repo, agent session launch) → `harukainguyen1411/strawberry-agents`
- **Code repo contexts** (workflows, secrets for deploys, runners, coder-worker triage target) → `harukainguyen1411/strawberry-app`
- **Archive references** (historical notes correctly naming the old repo as archive) → leave untouched

## Script pattern for two-checkout runtime

`discord-bridge.sh` now distinguishes:
- `STRAWBERRY_DIR` — agent-infra checkout (where Claude sessions run from)
- `STRAWBERRY_APP_DIR` — code checkout (where `apps/**` live)

Both default to `/home/runner/strawberry-agents` and `/home/runner/strawberry-app` respectively, overridable via env.

## Gitleaks

Pre-commit hook ran automatically, scanned ~2.29 KB, zero findings.

## What A3 still needs

- Set git remote: `git remote add origin https://github.com/harukainguyen1411/strawberry-agents.git`
- Push: `git push -u origin main`
- Branch protection per §7.3 minimal profile
- Hook installation via `scripts/install-hooks.sh`
