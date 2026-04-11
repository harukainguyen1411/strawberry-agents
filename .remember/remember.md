# Handoff

## State
Delivery pipeline is live on Windows. Four NSSM services running: StrawberryDiscordRelay, StrawberryCoderWorker, deploy-webhook (port 9000), cloudflared-tunnel. All committed to main. Setup runbook updated at `docs/delivery-pipeline-setup.md`.

## Next
1. Configure GitHub webhook on Mac: payload URL `https://timely-outputs-withdrawal-hardware.trycloudflare.com/webhook`, secret from `secrets/deploy-webhook-secret.txt`. Note: URL changes on cloudflared restart.
2. Upgrade to named Cloudflare tunnel (permanent URL) via `cloudflared login` + `cloudflared tunnel create`.
3. Run smoke test (runbook §10): post in Discord forum, verify full pipeline fires.

## Context
- trycloudflare.com URL is ephemeral — changes on every cloudflared-tunnel service restart; update GitHub webhook after reboots until named tunnel is set up.
- All NSSM .env files need `icacls /grant "SYSTEM:(R)"` — services run as LocalSystem; already done for all three apps.
- Em dashes in PS1 strings break Windows PowerShell 5.1 parsing — replace with hyphens in any new scripts.
- deploy-services.json uses full NSSM service names (StrawberryDiscordRelay, StrawberryCoderWorker).
