---
status: approved
owner: evelynn
architects: [swain, pyke]
---

# Discord-CLI Integration — Replace Contributor Pipeline

## Summary

Replace the current four-step contributor pipeline (Discord → Gemini triage → GitHub Issue → GHA Claude runner) with a two-step flow (Discord → Claude CLI as Evelynn). Evelynn runs persistently on the VPS and processes Discord events directly with full codebase context.

## Architecture

### Components

| Component | Location | Owner | Purpose |
|---|---|---|---|
| Discord relay bot | `apps/discord-relay/` | Katarina/Ornn | Thin Discord I/O — listens to events, posts responses |
| Event bridge | `scripts/discord-bridge.sh` | Katarina/Ornn | Watches event queue, spawns `claude --message` per event |
| Result watcher | `scripts/result-watcher.sh` | Katarina/Ornn | Monitors agent completion, posts follow-ups to Discord |
| PM2 config | `ecosystem.config.js` | Pyke | Process management for all three components |
| Deploy script | `scripts/deploy.sh` | Pyke | Pull + install + PM2 restart |
| Health check | `scripts/health-check.sh` | Pyke | Cron: PM2 status + Claude auth + disk usage → Discord #ops |

### Data Flow

```
Discord Gateway
    ↓ (WebSocket, outbound only)
discord-relay bot (Node.js, discord.js)
    ↓ writes JSON
/home/runner/data/discord-events/
    ↓ watched by
discord-bridge.sh
    ↓ spawns
claude --message (as Evelynn, with codebase context)
    ↓ writes JSON
/home/runner/data/discord-responses/
    ↓ read by
discord-relay bot
    ↓ posts to
Discord thread
```

### Claude CLI Invocation Tiers

| Tier | Use case | --max-turns | Example |
|---|---|---|---|
| Triage | Evaluate a new suggestion | 1 | New forum post |
| Delegation | Read files, use agent-manager tools | 5 | Actionable feature request |

### Event Sanitization

All Discord user content must be sanitized before inclusion in Claude prompts:
- Strip XML-like tags, system prompt patterns, instruction overrides
- Cap user content at 2000 characters
- Use clear `<event>` delimiters in prompt template
- Validate JSON schema before processing

### Rate Limiting

- Minimum 30 seconds between `claude --message` invocations
- If queue > 5 events, post "processing backlog" acknowledgment to oldest waiting thread

## Infrastructure (Pyke)

### VPS: Hetzner CX22 (37.27.192.25)

- Ubuntu 24.04, 4GB RAM, Node 22, Claude CLI, PM2
- All processes run as `runner` user (no root)
- Add 2GB swap file (mandatory — concurrent Claude + agent processes)

### Directory Structure (VPS only)

```
/home/runner/data/
    discord-events/          # Incoming events
    discord-responses/       # Outgoing responses
    discord-processed/       # Archived (rotated by cron)
```

### Secrets

File: `/home/runner/.env.discord` (chmod 600, runner-owned, not in git)
- DISCORD_TOKEN
- DISCORD_GUILD_ID
- DISCORD_FORUM_CHANNEL_ID

Claude auth: persisted in `~/.claude/` via OAuth (subscription-based).

### PM2 Processes

| Process | Script | Restart policy |
|---|---|---|
| discord-bot | apps/discord-relay/src/index.js | on-crash, max 10/15min |
| discord-bridge | scripts/discord-bridge.sh | on-crash |
| result-watcher | scripts/result-watcher.sh | on-crash |

PM2 startup hook via systemd for reboot persistence.

### Cron Jobs

```
# Rotate processed events older than 7 days
0 3 * * * find /home/runner/data/discord-processed/ -type f -mtime +7 -delete

# Flush PM2 logs
0 3 * * * pm2 flush

# Health check every 15 minutes
*/15 * * * * /home/runner/strawberry/scripts/health-check.sh
```

### Security

- UFW: no new ports needed (Discord uses outbound WebSocket)
- fail2ban + key-only SSH already in place
- No privilege escalation — all processes as `runner`

## Codebase Changes

### Delete

- `apps/contributor-bot/src/triage.js` — Gemini triage (Evelynn replaces this)
- `apps/contributor-bot/src/github.js` — GitHub issue creation (no longer needed)
- `@google/generative-ai` dependency
- `@octokit/rest` dependency
- GHA workflow for Claude Code runner

### Create

- `apps/discord-relay/` — refactored from contributor-bot, ~100 LOC
- `scripts/discord-bridge.sh`
- `scripts/result-watcher.sh`
- `ecosystem.config.js`
- `scripts/deploy.sh`
- `scripts/health-check.sh`

### Keep

- `discord.js` dependency
- `express` (health endpoint)
- Discord bot token and channel config pattern

## Blocked On Duong

1. Discord bot token (create in Discord Developer Portal)
2. Discord guild ID + forum channel ID
3. Verify Claude CLI auth on VPS (`ssh runner@37.27.192.25` then `claude --version`)

## Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| Claude subscription rate limits | Events queue up | Sequential processing + immediate ack |
| VPS memory pressure (4GB) | Swap thrashing | 2GB swap + memory monitoring |
| OAuth token expiry | All CLI calls fail | Health check cron + Discord #ops alerts |
| Discord event flood | Backlog grows | Rate limiting + backlog notification |
| Prompt injection via Discord | Security breach | Input sanitization + content length cap |
