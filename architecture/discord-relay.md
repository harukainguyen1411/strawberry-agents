# Discord Relay

Replaces the old contributor pipeline (Discord → Gemini triage → GitHub Issue → GHA Claude runner) with a direct Discord → Evelynn flow.

**Status:** Planned — blocked on Duong providing bot token, guild/channel IDs, VPS auth.

## Architecture

```
Discord Gateway (WebSocket)
    ↓
discord-relay bot (Node.js, discord.js) — thin I/O layer
    ↓ writes JSON
/home/runner/data/discord-events/
    ↓ watched by
discord-bridge.sh
    ↓ spawns
claude --message (as Evelynn, with codebase context)
    ↓ writes JSON
/home/runner/data/discord-responses/
    ↓ read by
discord-relay bot → posts to Discord thread
```

Three PM2 processes on the Hetzner VPS.

## Components

| Component | Location | Purpose |
|---|---|---|
| Discord relay bot | `apps/discord-relay/src/index.js` | Discord I/O — listens to events, posts responses |
| Event bridge | `scripts/discord-bridge.sh` | Watches event queue, spawns `claude --message` |
| Result watcher | `scripts/result-watcher.sh` | Monitors agent completion, posts follow-ups |

## Claude CLI Invocation Tiers

| Tier | Use | Max turns | Example |
|---|---|---|---|
| Triage | Evaluate new suggestion | 1 | New forum post — classify and respond |
| Delegation | Read files, use agent-manager | 5 | Actionable feature request |

## Security

- All Discord user content sanitized before Claude prompts
- Strip XML-like tags, system prompt patterns, instruction overrides
- Cap user content at 2000 characters
- Use `<event>` delimiters in prompt template
- Validate JSON schema before processing

## Rate Limiting

- Minimum 30 seconds between `claude --message` invocations
- Queue > 5 events → post "processing backlog" acknowledgment

## Data Directories (VPS only)

```
/home/runner/data/
├── discord-events/       # Incoming events
├── discord-responses/    # Outgoing responses
└── discord-processed/    # Archived (rotated by cron)
```

See [infrastructure.md](infrastructure.md) for VPS details and PM2 config.
