---
date: 2026-04-19
topic: strawberry-agents Phase A1 history filter
---

# Learnings — strawberry-agents Phase A1 filter

## What happened

Ran `git filter-repo --invert-paths` on a fresh bare clone of `Duongntd/strawberry` at
`migration-base-2026-04-18` (SHA `af2edbc0`). Dropped all public paths (apps/, dashboards/,
.github/workflows/, build configs, deploy scripts). Kept full agent-infra tree.

Scratch dir: `/tmp/strawberry-agents-migration`. Bare clone: `/tmp/strawberry-agents-migration.git`.

## Key findings

1. **914 commits preserved** — `--invert-paths` preserves history unlike the squash approach
   used for strawberry-app. This is correct per the ADR (D2 decision).

2. **2 gitleaks findings** (private paths, not blocking for private-repo push):
   - `curl-auth-header` in `agents/evelynn/transcripts/2026-04-17-e0b93856.md` at commit
     `75ecc1c0` — real token for demo Cloud Run service. Flag for rotation.
   - `telegram-bot-api-token` in `.mcp.json` old history — same as P1 strawberry-app flag.

3. **secrets/encrypted/ matched exactly** — all 11 .age files present, R-agents-2 satisfied.

4. **Report file was pre-committed by Viktor in `085b781`** — when I wrote the report, the
   content was identical to what Viktor had committed. No additional commit needed.

5. **Pre-commit hook blocked on `architecture/deployment.md`** when many staged changes were
   present from prior Viktor session. Always use `git status` before committing to understand
   what's already staged from other agents.

## Scratch dirs for next phases

- Phase A2 (reference rewrite): work in `/tmp/strawberry-agents-migration` — add remote,
  grep-sweep for `Duongntd/strawberry` refs, rewrite, commit
- Phase A3 (push): `git remote add origin https://github.com/harukainguyen1411/strawberry-agents.git && git push -u origin main`

## filter-repo note

`git filter-repo --invert-paths` does NOT need the `--force` flag when the repo was freshly
cloned (it auto-detects single-remote). In practice, `--force` works fine either way.
The bare clone must be separate from the scratch working dir — clone the bare, then clone the
bare to get the working dir.
