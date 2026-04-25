# Infrastructure

## Local Mac (primary)

Duong's Mac is the primary runtime environment for the agent system.

- **Agent sessions**: Each agent runs as a Claude CLI session in its own iTerm window.
- **iTerm2**: Dynamic profiles for each agent (custom backgrounds, names) at `~/Library/Application Support/iTerm2/DynamicProfiles/agents.json`.
- **Runtime state**: `~/.strawberry/ops/` — inbox, conversations, health, inbox-queue (all gitignored).

## VPS — Hetzner CX22

**IP:** `37.27.192.25`
**OS:** Ubuntu 24.04
**Specs:** 4 GB RAM + 2 GB swap (mandatory for concurrent Claude + agent processes)
**User:** `runner` (no root access for processes)

### Setup

Provisioned via `scripts/vps-setup.sh` which handles:
- System packages (Node 22, Claude CLI, PM2)
- `runner` user creation with scoped sudo
- SSH hardening (key-only, no root login)
- UFW firewall
- fail2ban
- GitHub Actions runner registration

### PM2 processes

| Process | Script | Purpose |
|---|---|---|
| `discord-bot` | `apps/discord-relay/src/index.js` | Discord relay bot |
| `discord-bridge` | `scripts/discord-bridge.sh` | Event queue → Claude CLI |
| `result-watcher` | `scripts/result-watcher.sh` | Claude responses → Discord |

Config: `ecosystem.config.js` at repo root. PM2 startup hook via systemd for reboot persistence.

### Cron jobs

```
0 3 * * *    find /home/runner/data/discord-processed/ -type f -mtime +7 -delete
0 3 * * *    pm2 flush
*/15 * * * * /home/runner/strawberry/scripts/health-check.sh
```

### Security

- UFW: no extra inbound ports (Discord uses outbound WebSocket)
- fail2ban + key-only SSH
- No privilege escalation — all processes as `runner`
- Secrets in `/home/runner/.env.discord` (chmod 600, not in git)

### Claude auth

Duong uses Claude subscription (not API billing). CLI on VPS authenticates via `claude login` (OAuth). Token persists in `~/.claude/`.

### Deploy

`scripts/deploy-discord-relay-vps.sh` — pull + install + PM2 restart.

### Data directories

```
/home/runner/data/
├── discord-events/       # Incoming Discord events
├── discord-responses/    # Outgoing responses
└── discord-processed/    # Archived (rotated by cron)
```

## Relay bridges (stalled)

- **Discord relay** — stalled as of 2026-04-25. Archive pending W3.
- **Telegram bridge** — stalled / abandoned as of 2026-04-25. Archive pending W3.

No new MCP server architecture exists for agent dispatch. `discord-relay.md`, `telegram-relay.md`, and `mcp-servers.md` are candidates for archival in W3; they remain at their current paths until that wave lands.
