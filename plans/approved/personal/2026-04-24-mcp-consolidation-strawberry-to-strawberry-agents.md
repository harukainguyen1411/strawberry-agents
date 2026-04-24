---
title: Consolidate MCP servers — migrate from stale strawberry/ repo into strawberry-agents/mcps/
status: approved
owner: karma
concern: personal
complexity: quick
tests_required: false
orianna_gate_version: 2
created: 2026-04-24
estimate_minutes: 90
---

## Context

`/Users/duongntd99/Documents/Personal/strawberry/` is a stale `Duongntd/strawberry` repo. The project-scoped `.mcp.json` at the root of `strawberry-agents/` still points its five MCP `start.sh` paths at that stale tree:

- `evelynn` — connected. Also injects `AGENTS_PATH` + `WORKSPACE_PATH` envs pointing at `strawberry/agents` and `strawberry/` respectively.
- `discord` — connected.
- `gcp` — connected.
- `cloudflare` — failed (pre-existing, out of scope).
- `slack` — failed (fix tracked in a separate plan; this plan only relocates the source tree).

A reconnaissance diff (`diff -rq --exclude=node_modules --exclude=.env --exclude=__pycache__ --exclude=venv --exclude=.venv`) shows the four overlapping MCPs (`evelynn`, `discord`, `cloudflare`, `gcp`) are byte-identical between `strawberry/mcps/<name>/` and `strawberry-agents/mcps/<name>/`. Only `slack/` exists uniquely under `strawberry/mcps/`, plus a trivial `shared/__pycache__` delta that is regenerated at runtime. No `.env` files are present in either tree — MCP env is inlined in `.mcp.json`. The Slack `scripts/start.sh` already references `strawberry-agents/secrets/slack-bot-token.txt`, so relocating its source is a clean move.

Goal: move `slack/` into `strawberry-agents/mcps/`, rewrite the five `.mcp.json` entries (command args + evelynn's AGENTS_PATH/WORKSPACE_PATH), verify zero regressions via `claude mcp list`, then delete `/Users/duongntd99/Documents/Personal/strawberry/` once Duong confirms nothing else in that repo is still live. Final deletion MUST be gated on explicit Duong confirmation per auto-mode safety rule 5.

## Tasks

### T1 — Reconcile inventory and record the canonical decisions (10 min)

- Kind: investigation
- Estimate (minutes): 10
- Files: `plans/proposed/personal/2026-04-24-mcp-consolidation-strawberry-to-strawberry-agents.md` (append an "Inventory reconciliation" section with the per-MCP decision table).
- Detail: Re-run `diff -rq --exclude=node_modules --exclude=.env --exclude=__pycache__ --exclude=venv --exclude=.venv strawberry/mcps/<name> strawberry-agents/mcps/<name>` for each of `evelynn`, `discord`, `cloudflare`, `gcp`, `shared`. Record results. For each MCP, declare canonical source. Expected outcome from scouting: all four overlapping MCPs identical, so `strawberry-agents/mcps/` is canonical for them; `slack/` only exists under `strawberry/mcps/`, so it is the migration source. Also inspect `strawberry/mcps/<name>/src` (and, for python MCPs, `requirements.txt`) for any cross-MCP `import` of a helper that lives ONLY under `strawberry/mcps/shared/` and not under `strawberry-agents/mcps/shared/` — if found, flag and STOP, escalate to Azir for plan revision.
- DoD: decision table committed to this plan; either "no blocking shared-lib deltas, proceed" is recorded, or the plan is paused pending escalation.

### T2 — Copy slack MCP into strawberry-agents/mcps/slack (15 min)

- Kind: migration
- Estimate (minutes): 15
- Files: `mcps/slack/` (new subtree under `strawberry-agents/`). <!-- orianna: ok -->
- Detail: `cp -R /Users/duongntd99/Documents/Personal/strawberry/mcps/slack /Users/duongntd99/Documents/Personal/strawberry-agents/mcps/slack`, then `rm -rf strawberry-agents/mcps/slack/node_modules` and run a fresh `npm install` inside that directory so the install is hermetic to the new repo. Do NOT copy any `.env` file (there isn't one; env comes via `.mcp.json`). Verify `strawberry-agents/mcps/slack/scripts/start.sh` already references `strawberry-agents/secrets/slack-bot-token.txt` (it does per scouting). Stage `mcps/slack/**` but NOT `node_modules/` — confirm `strawberry-agents/mcps/.gitignore` (or root `.gitignore`) already excludes `node_modules/`; add an entry if not.
- DoD: `strawberry-agents/mcps/slack/` present with a fresh `node_modules` tree and `./node_modules/.bin/tsx` executable; `node_modules/` is git-ignored; plan file tree is only source, package.json, package-lock.json, scripts, src, test, tsconfig.json, vitest.config.ts.

### T3 — Rewrite .mcp.json to point at strawberry-agents paths (10 min)

- Kind: config
- Estimate (minutes): 10
- Files: `.mcp.json`
- Detail: Edit the five `mcpServers.<name>.args[0]` entries to replace `/Users/duongntd99/Documents/Personal/strawberry/mcps/` with `/Users/duongntd99/Documents/Personal/strawberry-agents/mcps/`. Additionally under `mcpServers.evelynn.env`, repoint `AGENTS_PATH` to `/Users/duongntd99/Documents/Personal/strawberry-agents/agents` and `WORKSPACE_PATH` to `/Users/duongntd99/Documents/Personal/strawberry-agents`. Preserve all other env keys exactly. Do not reorder keys.
- DoD: `git diff .mcp.json` shows exactly six path rewrites (5 `args[0]` + 2 evelynn env — actually 7 lines, confirm by inspection) and nothing else; JSON remains valid (`python3 -m json.tool .mcp.json >/dev/null`).

### T4 — Smoke test: claude mcp list shows no regressions (15 min)

- Kind: verification
- Estimate (minutes): 15
- Files: none (verification only; record output inline in plan as a "Smoke results" section).
- Detail: From `strawberry-agents/` working directory run `claude mcp list`. Expect: `evelynn`, `discord`, `gcp` connected; `cloudflare` failed (pre-existing, unchanged); `slack` status equal-or-better than before (still failed if the separate Slack-fix plan has not landed; connected if it has). Any MCP that was previously connected and is now failing is a regression and blocks T5. If a regression appears, revert `.mcp.json` via `git checkout -- .mcp.json` and report. Also verify `strawberry-agents/mcps/slack/scripts/start.sh` is directly runnable: `bash strawberry-agents/mcps/slack/scripts/start.sh </dev/null` should fail fast only on missing stdin (MCP handshake), not on missing `tsx` or missing token file.
- DoD: smoke output captured in plan; either "zero regressions, proceed to T5" or "regression observed on <name>, T5 blocked, reverted .mcp.json."

### T5 — Delete the stale strawberry/ repo (gated on Duong confirmation) (10 min)

- Kind: cleanup
- Estimate (minutes): 10
- Files: `/Users/duongntd99/Documents/Personal/strawberry/` (full removal, external to this repo).
- Detail: STOP and ask Duong for explicit confirmation before deleting. `strawberry/` contains not only `mcps/` but also `agents/`, `apps/`, `architecture/`, `deploy/`, `firestore.rules`, `firestore.indexes.json`, `ecosystem.config.js`, etc. Duong must confirm (a) no active process / launchd / pm2 entry references that path, (b) no IDE workspace / bookmark still opens there, (c) no git remote still pushes to it, (d) no other `.mcp.json` or `claude.json` project entry references it. Only after a clear "yes, delete" does Talon run `rm -rf /Users/duongntd99/Documents/Personal/strawberry`. If Duong asks for a reversible alternative, rename to `/Users/duongntd99/Documents/Personal/_strawberry-archive-2026-04-24` instead and schedule deletion for a later date.
- DoD: either the directory is gone and Duong has confirmed in chat, or the plan is left with T5 marked "awaiting confirmation — archival rename performed" and a follow-up date set.

## Decision

Quick-lane is appropriate: single top-level concern (local MCP config), no schema changes, no universal-invariant touches, no external integrations added. The only non-trivial risk is T5's irreversible deletion — mitigated by an explicit human-confirmation gate and an archival-rename fallback.

## Open questions

- Is there anything under `strawberry/apps/`, `strawberry/deploy/`, `strawberry/firestore.rules`, or `strawberry/ecosystem.config.js` that is still load-bearing outside the MCP scope? T5 must not proceed until Duong answers this. If any of those are live, this plan ships through T4 only and T5 spawns a new plan.
- If T1 discovers a shared-lib drift between `strawberry/mcps/shared/` and `strawberry-agents/mcps/shared/` beyond the `__pycache__` delta, escalate — do not self-resolve in the quick lane.

## References

- `.mcp.json` (lines 3-50) — current MCP config pointing at the stale tree.
- `plans/implemented/personal/2026-04-24-custom-slack-mcp.md` — the separate Slack source-fix plan this one assumes is handled independently.
- `CLAUDE.md` auto-mode rule 5 — irreversible deletion requires explicit confirmation.

## Inventory reconciliation (T1 — 2026-04-24, Talon)

| MCP | Diff result | Canonical source | Decision |
|-----|-------------|-----------------|---------|
| evelynn | byte-identical | strawberry-agents/mcps/evelynn/ | use as-is |
| discord | byte-identical | strawberry-agents/mcps/discord/ | use as-is |
| cloudflare | byte-identical | strawberry-agents/mcps/cloudflare/ | use as-is |
| gcp | byte-identical | strawberry-agents/mcps/gcp/ | use as-is |
| shared | byte-identical | strawberry-agents/mcps/shared/ | use as-is |
| slack | only in strawberry/mcps/slack/ | strawberry/mcps/slack/ @ talon/slack-mcp-node25-cjs-fix | migrate (patched) |

No blocking shared-lib deltas found. Proceed with migration.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Owner (karma) declared; five tasks each have concrete files, detail, and DoD. Reconnaissance diff results are recorded in Context, so T1 is a verify-then-record rather than open-ended investigation. T5 (irreversible deletion of `/Users/duongntd99/Documents/Personal/strawberry/`) is explicitly gated on Duong confirmation and offers an archival-rename fallback, satisfying auto-mode rule 5. No unresolved TBD/TODO in gating sections; quick-lane scope is appropriate for local MCP config changes.
