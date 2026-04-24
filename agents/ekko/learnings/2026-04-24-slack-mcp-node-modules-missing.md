# Slack MCP — node_modules Missing After PR #44

**Date:** 2026-04-24
**Task:** Diagnose `slack: ✗ Failed to connect` after PR #44 merge

## Root Cause

`mcps/slack/` was added to the repo via PR #44 with source files (`src/`, `package.json`,
`tsconfig.json`, etc.) but without `node_modules/` (correctly gitignored).
`start.sh` checks for `./node_modules/.bin/tsx` and exits 1 with
`"slack-mcp: node_modules missing — run 'npm install'"` if absent.

Claude's `/mcp` reconnect attempt invokes the start.sh cold — no deps, instant exit 1.

## Diagnosis Steps

1. `start.sh` read — shebang `#!/usr/bin/env bash`, hardcoded absolute token path, tsx check, no
   deps-install logic of its own.
2. `ls mcps/slack/` — `node_modules/` absent.
3. `secrets/slack-bot-token.txt` present with both `bot_token=` and `user_token=` lines.
4. `.mcp.json` slack entry correct (command, args, env).

## Fix

```
cd /Users/duongntd99/Documents/Personal/strawberry-agents/mcps/slack && npm install
```

170 packages, 0 vulnerabilities, ~4 seconds.

## Verification

MCP initialize handshake smoke test:

```
echo '{"jsonrpc":"2.0","id":1,"method":"initialize",...}' | bash scripts/start.sh
```

Response: `{"result":{"protocolVersion":"2024-11-05","capabilities":...,"serverInfo":{"name":"slack","version":"1.0.0"}},...}`

Server responds correctly. No stderr output.

## Recommendation

Add `npm install --prefix mcps/slack` to `scripts/install-hooks.sh` or add a post-clone setup
note so that future worktree spins or fresh clones automatically get deps installed.
Alternatively add an auto-install guard to `start.sh`:

```bash
[ -x "./node_modules/.bin/tsx" ] || npm install --silent
```

This keeps the MCP self-healing on first launch without requiring a separate setup step.
