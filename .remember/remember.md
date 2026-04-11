# Handoff

## State
Delivery pipeline fully live. Four NSSM services running: StrawberryDiscordRelay, StrawberryCoderWorker, deploy-webhook (port 9000), cloudflared-tunnel (named tunnel, `webhook.darkstrawberry.com` -> localhost:9000). GitHub webhook configured and verified 200. Runbook complete at `docs/delivery-pipeline-setup.md`.

## Next
1. Run smoke test (runbook §10): post in Discord forum, verify full pipeline fires end to end.
2. Monitor first real coder-worker PR — review diff carefully before merging.

## Context
- Named Cloudflare tunnel live: `strawberry-webhook` (UUID 0853c7c1-7da2-4a28-8fc4-12d5130bfb63), routes `webhook.darkstrawberry.com` to localhost:9000. Config at `C:\Users\AD\.cloudflared\config.yml`.
- All NSSM .env files need `icacls /grant "SYSTEM:(R)"` — services run as LocalSystem; already done for all three apps.
- Em dashes in PS1 strings break Windows PowerShell 5.1 parsing — replace with hyphens in any new scripts.
- deploy-services.json uses full NSSM service names (StrawberryDiscordRelay, StrawberryCoderWorker).
