# Handoff

## State
Delivery pipeline is live on Windows. Four NSSM services running: StrawberryDiscordRelay, StrawberryCoderWorker, deploy-webhook (port 9000), cloudflared-tunnel. All committed to main. Setup runbook updated at `docs/delivery-pipeline-setup.md`.

## Next
1. Configure GitHub webhook on Mac: `https://github.com/Duongntd/strawberry/settings/hooks/new` — Payload URL `https://webhook.darkstrawberry.com/webhook`, secret from `secrets/deploy-webhook-secret.txt`.
2. Run smoke test (runbook §10): post in Discord forum, verify full pipeline fires.

## Context
- Named Cloudflare tunnel live: `strawberry-webhook` (UUID 0853c7c1-7da2-4a28-8fc4-12d5130bfb63), routes `webhook.darkstrawberry.com` to localhost:9000. Config at `C:\Users\AD\.cloudflared\config.yml`.
- All NSSM .env files need `icacls /grant "SYSTEM:(R)"` — services run as LocalSystem; already done for all three apps.
- Em dashes in PS1 strings break Windows PowerShell 5.1 parsing — replace with hyphens in any new scripts.
- deploy-services.json uses full NSSM service names (StrawberryDiscordRelay, StrawberryCoderWorker).
