---
title: GitHub Push Webhook Auto-Deploy for Windows Services
status: proposed
owner: swain
created: 2026-04-11
---

# GitHub Push Webhook Auto-Deploy for Windows Services

## Problem

Three NSSM-supervised Node.js services on Duong's Windows box (discord-relay, coder-worker, bee-worker) require manual deployment: git pull, npm run build, nssm restart. This friction means pushes to main sit undeployed until Duong intervenes.

## Goal

A push to main on GitHub automatically triggers pull, build, and restart of all three services on the Windows box. Zero manual steps after initial setup.

## Architecture

A lightweight Node.js webhook receiver (`apps/deploy-webhook`) runs as a fourth NSSM service on Windows. GitHub sends a push event; the receiver validates the HMAC signature and unconditionally deploys all three services (discord-relay, coder-worker, bee-worker). Since this is a monorepo with shared code, any push to main rebuilds and restarts everything. The deploy script is a PowerShell script under `scripts/windows/` that handles git pull, npm run build, and nssm restart.

### Why Node.js for the receiver

Consistent with the existing stack (all three services are Node.js). No new runtime dependency. Minimal: express + crypto, no other deps.

### Component breakdown

| Component | Path | Purpose |
|-----------|------|---------|
| Webhook receiver | `apps/deploy-webhook/` | HTTP server, signature validation, invokes deploy script |
| Deploy script | `scripts/windows/deploy-service.ps1` | Per-service: npm run build, nssm restart. Called once per service. |
| Deploy-all wrapper | `scripts/windows/deploy-all.ps1` | git pull once, then calls deploy-service.ps1 for each of the three services sequentially. |
| Install script | `scripts/windows/install-deploy-webhook.ps1` | NSSM service registration, follows install-bee-worker.ps1 pattern |

### Request flow

```
GitHub push event (POST /webhook)
  -> deploy-webhook validates HMAC-SHA256 signature
  -> responds 200 immediately
  -> spawns: powershell deploy-all.ps1
  -> deploy-all.ps1: git pull --ff-only origin main
  -> for each service (discord-relay, coder-worker, bee-worker):
       deploy-service.ps1 -ServiceName <name>: npm run build (in app dir), nssm restart <name>
```

## Design Decisions

### D1: Unconditional full deploy

Every push to main rebuilds and restarts all three services. No change detection. This is a monorepo with shared TypeScript config, shared dependencies, and potential shared code between apps. Selective rebuild would add complexity for negligible benefit on a personal system with three small services. A full deploy takes under two minutes.

### D2: Sequential deploys, not parallel

Deploy one service at a time. Avoids git pull race conditions (single repo checkout) and keeps NSSM restart predictable. The extra 30 seconds of sequential build time is acceptable for a personal system.

### D3: Immediate 200 response

The webhook responds 200 as soon as signature validation passes. Deploy runs in background (child_process.spawn, detached). GitHub has a 10-second webhook timeout; builds will exceed that.

### D4: Git pull strategy

`git pull --ff-only origin main` in the repo root. If ff-only fails (should never happen since only main pushes trigger this and the box never has local commits), the deploy aborts and logs the error. No reset, no force pull -- fail safe, alert via log.

### D5: Webhook secret

Stored in env file at `%USERPROFILE%\deploy-webhook\secrets\webhook.env`, same NTFS ACL pattern as bee-worker. The GitHub webhook secret is set once in GitHub repo settings and in the env file. Never committed.

### D6: Locking

A file lock (`deploy.lock` in the repo root or a temp dir) prevents concurrent deploy runs. If a second push arrives while a deploy is in progress, queue it (or simply re-run after the current deploy finishes -- idempotent). Simplest approach: if lock exists, log "deploy already in progress, skipping" and return 200. The next push will pick up both sets of changes since git pull gets everything.

### D7: Logging

NSSM handles stdout/stderr log rotation (same pattern as bee-worker). The receiver logs each webhook receipt, validation result, and deploy outcomes. Deploy script logs each step (pull, build, restart) with timestamps.

### D8: Health check

GET `/health` returns 200 with uptime and last deploy timestamp. Useful for manual verification that the service is running.

## Failure modes

| Failure | Behavior |
|---------|----------|
| Invalid signature | 401, logged, no deploy |
| git pull fails | No services restarted, entire deploy aborted, error logged |
| npm run build fails | Service not restarted for that app, error logged |
| nssm restart fails | Error logged |
| Webhook receiver crashes | NSSM auto-restarts it (AppRestartDelay) |
| GitHub unreachable | No webhook sent; no action needed |
| Deploy already running | Skip, return 200, log message |

## Implementation scope

### New files

- `apps/deploy-webhook/package.json` -- minimal: express, dotenv
- `apps/deploy-webhook/src/index.ts` -- webhook server (~100 lines)
- `apps/deploy-webhook/tsconfig.json`
- `scripts/windows/deploy-all.ps1` -- git pull + iterate all three services
- `scripts/windows/deploy-service.ps1` -- per-service build + restart logic
- `scripts/windows/install-deploy-webhook.ps1` -- NSSM install script

### Network setup (manual, documented)

- Port: 9000 (configurable via env). Duong must open this port in Windows Firewall and router/ngrok/Cloudflare Tunnel.
- GitHub webhook: Settings > Webhooks > Add webhook, URL = `http://<windows-box-ip>:9000/webhook`, content type = JSON, secret = the shared secret, events = push only.

### Alternatives considered for exposing the endpoint

Since Duong's Windows box is behind a home network, the webhook URL must be reachable from GitHub. Three options:

1. **Port forwarding** -- simplest, router config. Works if ISP provides a stable public IP.
2. **Cloudflare Tunnel (cloudflared)** -- free, no port forwarding needed, runs as another NSSM service. Recommended if Duong already uses Cloudflare.
3. **ngrok** -- free tier works but URL changes on restart unless paid. Not recommended.

The plan does not prescribe which option. The install script documents all three and the implementer leaves it as a setup step for Duong.

## Out of scope

- Rollback on failed deploy (personal system, git revert + push is sufficient)
- Slack/Discord notifications of deploy status (can be added later)
- Deploying non-Node services or non-main branches
- CI/CD (GitHub Actions) -- the whole point is to avoid paid services and keep it on-box
