# 2026-04-24 — Dual-Token Slack MCP Wiring

## Summary

Wired two Slack MCP instances (`slack-bot` / `slack-user`) side-by-side so
Evelynn/Sona can pick bot-vs-user identity per call.

## Key changes

- `strawberry/mcps/slack/scripts/start.sh` — rewrote to accept `--token-kind bot|user`.
  Reads the matching `bot_token=` or `user_token=` line from
  `strawberry-agents/secrets/slack-bot-token.txt` via `grep + cut`. Absolute path
  fix for REPO_ROOT bug from prior session. POSIX-portable (no `[[`).
- `.mcp.json` — replaced single `slack` entry with `slack-bot` and `slack-user`.
  Both pass `--token-kind` arg and `SLACK_TEAM_ID=T18MLBHC5`.
- `agents/memory/duong.md` — `## Slack` section added (Duong corrected the
  notification-target wording himself before Ekko could push).

## REPO_ROOT bug fix

Old `start.sh` resolved REPO_ROOT relative to the script location
(`$(dirname "$0")/../../..`), which pointed to the old `strawberry` repo's secrets/.
New approach: absolute hardcoded path to `strawberry-agents/secrets/slack-bot-token.txt`.
Simpler and correct since secrets always live in `strawberry-agents/`.

## start.sh shape

```sh
--token-kind bot    → reads bot_token=  line → exports as SLACK_BOT_TOKEN
--token-kind user   → reads user_token= line → exports as SLACK_BOT_TOKEN
```

Upstream package (`@modelcontextprotocol/server-slack`) only reads `SLACK_BOT_TOKEN`
regardless of which token kind is passed.

## Smoke test results

Both invocations emitted `Slack MCP Server running on stdio` with no auth errors.

## Multi-repo commit note

`start.sh` lives in the old `strawberry` repo (Duongntd/strawberry), which has no
live remote (repo no longer exists on GitHub). Commit `2efb12c` landed locally.
`.mcp.json` and `duong.md` committed in `strawberry-agents` at `cb260764`, pushed
and merged into `277dc40a`.

## Notification target clarification (from Evelynn mid-session)

- Canonical notification target: `mcp__slack-bot__slack_post_message` with
  `channel_id: "U03KDE6SS9J"` (Duong's user ID, not a channel ID).
- Bot DMing a user = real Slack notification. Self-DM = suppressed.
- `C0ANVLZQ17X` is a valid posting channel but NOT the notification path.
