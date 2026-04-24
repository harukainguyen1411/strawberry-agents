# Slack MCP Server Wiring

**Date:** 2026-04-24
**Task:** Fix `slack: ✗ Failed to connect` in `claude mcp list`

## Root Causes Found

### 1. Token file missing at expected path
`start.sh` computes `REPO_ROOT` as 3 levels up from `mcps/slack/scripts/`, which resolves to
`/Users/duongntd99/Documents/Personal/strawberry/` (the old strawberry repo).
It then reads the token from `$REPO_ROOT/secrets/slack-bot-token.txt`.
That file did NOT exist in the old strawberry `secrets/` — it only existed in `strawberry-agents/secrets/`.

Fix: copied the token file to `/Users/duongntd99/Documents/Personal/strawberry/secrets/slack-bot-token.txt`.
This is not committed (gitignored in that repo).

### 2. SLACK_TEAM_ID was a placeholder
`.mcp.json` had `"SLACK_TEAM_ID": "TXXXXXXXX"` (literal placeholder).
The `@modelcontextprotocol/server-slack` package requires both `SLACK_BOT_TOKEN` and `SLACK_TEAM_ID`.

Fix: retrieved real team ID via `curl https://slack.com/api/auth.test` with the existing token.
Real team ID: `T18MLBHC5`. Updated `.mcp.json`. Team IDs are not secrets (visible in Slack URLs).

## Token Note
The token in `secrets/slack-bot-token.txt` is a **user token** (`xoxp-` prefix), not a bot token.
The package env var is named `SLACK_BOT_TOKEN` but accepts user tokens too.
The server started cleanly in local smoke test.

## How Other MCPs Handle Secrets
Discord and slack both use the plaintext-in-gitignored-secrets pattern (no age encryption).
Cloudflare and GCP use the same `start.sh` pattern — read from `$REPO_ROOT/secrets/`.

## Phase 3 Verification
`claude mcp list` cannot be run within the same session — MCP config is loaded at session startup.
A **session restart** is required to verify the `slack` entry shows `✓ Connected`.

## Key Learning
When a start.sh references `$REPO_ROOT/secrets/`, the repo root it resolves to may differ from
where secrets actually live if the MCP server code lives in a different repo than the secrets.
Always verify the REPO_ROOT computation path when debugging MCP connection failures.
