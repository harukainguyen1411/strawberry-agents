---
title: Fix Agent API Key Isolation
status: superseded
owner: syndra
date: 2026-04-05
---

# Fix Agent API Key Isolation

## Problem

All agents use Duong's global Claude Code API key instead of their per-agent keys.

## Root Cause

Each agent has a `settings.local.json` at `agents/<name>/.claude/settings.local.json` with a unique `ANTHROPIC_API_KEY`. But `launch_agent` runs:

```
cd {WORKSPACE} && claude --model {model_flag}
```

Claude Code resolves project-level `settings.local.json` from the working directory's `.claude/` folder. Since the working directory is always the strawberry root, it loads `.claude/settings.local.json` — which has no `ANTHROPIC_API_KEY`. The per-agent files at `agents/<name>/.claude/` are never consulted.

The global Claude Code key (from `~/.claude/settings.local.json` or environment) becomes the fallback for every agent.

## Recommended Fix

**Inject `ANTHROPIC_API_KEY` into the launch command's environment.** In `launch_agent()` (server.py ~line 393-398), read the agent's key from their `settings.local.json` and export it:

```python
# After resolving agent_dir, before building launch_cmd:
agent_settings_file = os.path.join(agent_dir, '.claude', 'settings.local.json')
agent_api_key_export = ''
if os.path.exists(agent_settings_file):
    import json
    with open(agent_settings_file) as f:
        agent_settings = json.load(f)
    agent_key = agent_settings.get('env', {}).get('ANTHROPIC_API_KEY', '')
    if agent_key:
        # Write key to a temp file per agent so it never appears in scrollback
        key_file = os.path.join(WORKSPACE, 'secrets', f'.agent-key-{recipient}')
        with open(key_file, 'w') as f:
            f.write(agent_key)
        os.chmod(key_file, 0o600)
        quoted_key_path = key_file.replace("'", "'\\''")
        agent_api_key_export = f"export ANTHROPIC_API_KEY=$(cat '{quoted_key_path}') && "
```

Then prepend `agent_api_key_export` to `launch_cmd`.

**Why this approach:**
- Follows the existing pattern (GH_TOKEN uses `$(cat ...)` to avoid scrollback exposure)
- No changes to Claude Code's settings resolution — we work with, not against, the tool
- Per-agent `settings.local.json` files remain the source of truth for keys
- Key files in `secrets/` are gitignored

## Alternative Considered: Change Working Directory

Launch each agent from `agents/<name>/` so Claude Code picks up their `settings.local.json`. Rejected because:
- The CLAUDE.md and project context depend on launching from the root
- Would break all relative paths in agent tools and scripts
- Claude Code might not find the root `.claude/` project config

## Cleanup

After implementing, the `env.ANTHROPIC_API_KEY` field in per-agent `settings.local.json` files becomes a **config source only** (read by launch_agent), not directly consumed by Claude Code. This is fine — no changes needed to the files themselves.

## Scope

- **File changed:** `mcps/agent-manager/server.py` (launch_agent function only)
- **Risk:** Low. Only affects how agents are launched. Existing sessions unaffected.
- **Testing:** Launch one agent, verify via `/cost` or API error that the per-agent key is active.
