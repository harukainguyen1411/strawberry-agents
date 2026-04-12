---
status: proposed
owner: swain
created: 2026-04-11
title: Deploy Bee Worker on GCE VM (Replace Windows NSSM)
---

# Deploy Bee Worker on GCE VM

## Goal

Move bee-worker from a Windows NSSM service to an always-on GCE VM running systemd, so Duong does not need to keep his Windows machine running 24/7.

## Prerequisite

This plan assumes the GitHub-issue rearchitect (`plans/proposed/2026-04-11-bee-github-issue-rearchitect.md`) is completed first. The deployed worker will poll GitHub issues, not Firestore.

## Architecture

A single `e2-micro` GCE VM (free-tier eligible) running Debian, with Node.js and Claude Code CLI installed. bee-worker runs as a systemd service. Claude Code authenticates via `claude login` (OAuth, Claude Max subscription). A cron job handles session refresh before expiry.

This is structurally identical to how coder-worker runs on Windows, except Linux + systemd replaces Windows + NSSM.

## VM Sizing

| Resource | Spec | Notes |
|----------|------|-------|
| Machine type | `e2-micro` | 0.25 vCPU (burstable to 2), 1 GB RAM. Free-tier eligible in `us-central1`, `us-west1`, `us-east1`. |
| Disk | 10 GB standard persistent (free-tier) | Node.js + Claude CLI + bee-worker repo fits in ~2 GB. |
| OS | Debian 12 (Bookworm) | Default GCE image. Minimal footprint. |
| Network | Ephemeral external IP | No inbound traffic needed — worker only polls outbound. |

**Cost: $0/month.** No existing GCE VMs in the billing account — the free-tier e2-micro slot is available.

## Decided: GCP Project and Session Sharing

- **GCP project:** Use the existing Firebase project `myapps-b31ea`. The VM will live alongside the existing Firebase resources. No new project needed.
- **Claude Max session sharing:** Accepted. The bee-worker VM will consume one concurrent session slot. This is fine for Duong's usage pattern.

## Claude Code CLI Auth on Headless VM

This is the hardest part of the plan. Claude Code uses OAuth browser login (`claude login`), which requires a browser. On a headless VM:

### Initial Auth

1. SSH into the VM.
2. Run `claude login`. It prints an OAuth URL.
3. Copy the URL to a local browser, complete the login.
4. The CLI stores the session token locally (~/.claude/).

### Session Expiry Problem

Claude Max OAuth tokens expire (exact TTL is not publicly documented, but empirically 7-30 days). When the token expires, `claude -p` fails silently or returns an auth error. The worker must handle this.

### Mitigation Strategy

1. **Health check cron (every 6 hours):** A script runs `claude -p "ping"` with a 30-second timeout. If it exits non-zero or outputs an auth error, the script:
   - Writes a failure marker to `/var/log/bee-worker/auth-health.log`.
   - Sends a notification to Duong (via a GitHub issue labeled `ops`, or a curl to a Telegram/Discord webhook).
2. **Manual re-auth:** Duong SSHes in and runs `claude login` again. This is the only reliable path — OAuth requires a browser.
3. **Worker resilience:** bee-worker's poll loop must catch auth errors from `claude -p` and retry with backoff rather than crashing. If auth fails 3 times consecutively, the worker should stop polling and wait for the health check to alert Duong.

There is no way to fully automate re-auth with a browser-based OAuth flow on a headless machine. The health check ensures Duong is alerted promptly rather than discovering the outage hours later.

### Alternative: API Key (Not Recommended for Now)

If Anthropic releases long-lived API keys for Claude Max subscribers, that would eliminate the re-auth problem entirely. Not available today. Revisit if the re-auth cadence becomes burdensome.

## systemd Service

### Unit File: `/etc/systemd/system/bee-worker.service`

```ini
[Unit]
Description=Bee Worker (GitHub Issue Poller)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=bee
Group=bee
WorkingDirectory=/opt/bee-worker
ExecStart=/usr/bin/node dist/index.js
Restart=on-failure
RestartSec=30
EnvironmentFile=/opt/bee-worker/.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bee-worker

[Install]
WantedBy=multi-user.target
```

### Key Decisions

- **Dedicated `bee` user** — no root, minimal permissions.
- **Restart=on-failure** with 30s backoff — survives transient errors without hammering.
- **Logs to journald** — `journalctl -u bee-worker -f` for tailing. No separate log rotation needed.
- **EnvironmentFile** — `.env` contains `GITHUB_TOKEN`, `GITHUB_REPO`, `BEE_POLL_INTERVAL_MS`. Never committed.

## Deployment Flow

### One-Time VM Setup

1. Create GCE VM via `gcloud compute instances create bee-worker --project=myapps-b31ea --machine-type=e2-micro --zone=us-central1-a --image-family=debian-12 --image-project=debian-cloud --boot-disk-size=10GB`.
2. SSH in. Install Node.js 20 LTS (`curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt-get install -y nodejs`).
3. Install Claude Code CLI (`npm install -g @anthropic-ai/claude-code`).
4. Run `claude login`, complete OAuth in local browser.
5. Create `bee` user: `sudo useradd -r -m -d /opt/bee-worker -s /bin/bash bee`.
6. Clone strawberry repo (or just the `apps/bee-worker` subtree) into `/opt/bee-worker/`.
7. `npm ci && npm run build` in the worker directory.
8. Write `.env` with secrets.
9. Install the systemd unit file, `sudo systemctl daemon-reload && sudo systemctl enable --now bee-worker`.
10. Install the health check cron.

### Code Updates

For now, manual: SSH in, `git pull`, `npm ci && npm run build`, `sudo systemctl restart bee-worker`. A deploy webhook (like the Windows push-autodeploy plan) can be added later but is not in scope here — keep the initial deployment simple.

## Changes to architecture/platform-split.md

The current doc describes a Mac/Windows split. With bee-worker moving to GCE, the doc needs a third section:

- **GCE (Autonomous):** Runs bee-worker in headless mode. Same constraints as Windows: never writes to agent state, never pushes to main. Polls GitHub issues, runs `claude -p`, posts answers as comments.

The Windows section remains valid for coder-worker (unless coder-worker also migrates later).

## What Does NOT Change

- **coder-worker stays on Windows** — this plan only moves bee-worker.
- **bee-worker code** — no code changes needed beyond what the GitHub-issue rearchitect plan already covers.
- **Mac agent system** — unaffected.

## Open Questions (Non-Blocking)

1. **Claude CLI auth token location:** Does `claude login` store tokens in `~/.claude/` for the logged-in user? If so, the `bee` service user needs its own `claude login` session, or the token path needs to be symlinked/shared. To be tested during setup.
2. **Future: coder-worker migration?** If this works well, should coder-worker also move to GCE (or a second e2-micro)? Deferred — validate with bee-worker first.
