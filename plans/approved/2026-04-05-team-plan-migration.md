---
title: Migrate Agent System from API Keys to Team Plan
status: approved
owner: syndra
date: 2026-04-05
---

# Migrate Agent System from API Keys to Team Plan

## Context

Duong is switching agent operations from personal API keys to his work team plan (Claude Max/Team subscription). API keys will be fully disabled for agent operations and retained only for app development (contributor-bot, myapps, etc.).

## What Changes

**Before:** Each agent has an `ANTHROPIC_API_KEY` in `agents/<name>/.claude/settings.local.json`. `launch_agent` reads these and injects the key as an env var. Agents authenticate via API credits.

**After:** Agents authenticate via the team subscription login. No per-agent API keys needed. Claude Code uses the logged-in session automatically.

## Migration Steps

### Phase 1: Verify Team Plan Access

1. Confirm Claude Code is logged into the team plan: `claude auth status` or `/config`
2. Verify auto mode works under the team plan (required for autonomous agents)
3. Verify concurrent sessions are supported (launch 2+ agents simultaneously)

### Phase 2: Remove API Key Injection from launch_agent

**File:** `mcps/agent-manager/server.py` (~lines 393-411)

Remove the entire block that reads `ANTHROPIC_API_KEY` from per-agent `settings.local.json` and injects it via `agent_api_key_export`. Specifically:
- Delete lines 393-411 (the `agent_api_key_export` block)
- Remove `{agent_api_key_export}` from `launch_cmd` on lines 416 and 418

After this change, `launch_cmd` simplifies to:
```python
if use_token:
    launch_cmd = f"export GH_TOKEN=$(cat '{quoted_path}') && export GITHUB_TOKEN=$(cat '{quoted_path}') && cd {WORKSPACE} && claude --model {model_flag}"
else:
    launch_cmd = f'cd {WORKSPACE} && claude --model {model_flag}'
```

### Phase 3: Clean Up Per-Agent Key Files

1. Remove `ANTHROPIC_API_KEY` from all `agents/<name>/.claude/settings.local.json` files
2. Delete any leftover key files in `secrets/.agent-key-*`
3. Keep `settings.local.json` files if they contain other settings (just strip the `env.ANTHROPIC_API_KEY` field)

### Phase 4: Update Documentation

1. **`architecture/claude-billing-comparison.md`** — Add note that agent system now runs on team plan, API reserved for app dev
2. **`plans/implemented/2026-04-05-agent-api-key-isolation.md`** — Mark as superseded by this plan (the isolation mechanism is no longer needed)

### Phase 5: Retain API Keys for App Development

API keys remain active for:
- `apps/contributor-bot/` — uses Anthropic SDK directly
- `apps/myapps/` — if any AI features use Claude API
- Any future app that calls the API programmatically

These keys live in their respective `.env` files or `secrets/`, unchanged.

## Rollback

If team plan auth fails or has issues:
- Re-add `ANTHROPIC_API_KEY` to per-agent `settings.local.json`
- Restore the injection block in `server.py` (recoverable from git history)

## Risk

- **Low.** If team plan auth is already working for Duong's Claude Code session, agents launched in the same environment will inherit it.
- **Watch for:** Rate limits or seat restrictions under the team plan that differ from API billing.

## Per-Agent Cost Tracking

With API keys, per-agent cost was trackable via separate keys in the Anthropic dashboard. Under the team plan, this granularity is lost. If cost-per-agent tracking is needed later, options:
- Re-enable API keys for cost-sensitive agents only (hybrid)
- Use Claude Code's `/cost` command per session and log it in session closing
- Wait for team plan admin tools to provide per-session breakdowns

## Scope

- **Files changed:** `mcps/agent-manager/server.py`, per-agent `settings.local.json` files, docs
- **Risk:** Low
- **Testing:** Launch one agent, verify it authenticates via team plan (no API key error), confirm auto mode works
