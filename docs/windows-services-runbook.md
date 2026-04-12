# Windows Services Runbook

Operational reference for the Node.js services running on the Windows box under NSSM.

---

## 1. Current Services

| Service | NSSM name | App dir | What it does |
|---------|-----------|---------|--------------|
| Discord relay | `discord-relay` | `apps/discord-relay` | Discord bot — bridges Discord messages to the CLI agent over file-based IPC |
| Coder worker | `coder-worker` | `apps/coder-worker` | Local Windows worker that receives jobs from the agent system and runs Max/Claude Code |
| Bee worker | `bee-worker` | `apps/private-apps/bee-worker` | Worker that processes Bee MVP document jobs (DOCX annotation pipeline) |
| Deploy webhook | `deploy-webhook` | `apps/deploy-webhook` | Receives GitHub push webhooks and auto-deploys all services above |

---

## 2. Manual Restart (interim, before autodeploy)

Run in Git Bash or PowerShell at the repo root. Replace `<service>` with the NSSM name.

```powershell
# Pull latest code
git pull --ff-only origin main

# Rebuild the service
cd apps/<service>
npm ci
npm run build
cd ../..

# Restart via NSSM (run as Administrator)
nssm restart <service>

# Verify
nssm status <service>
```

To restart all three services sequentially:

```powershell
git pull --ff-only origin main

foreach ($svc in @("discord-relay","coder-worker","bee-worker")) {
    $dir = "apps\$svc"
    Push-Location $dir; npm ci; npm run build; Pop-Location
    nssm restart $svc
    nssm status  $svc
}
```

---

## 3. One-Time Autodeploy Setup

After this setup, every push to `main` auto-deploys all three services. `deploy-webhook` does: git pull → build → nssm restart for each entry in `deploy-services.json`.

### 3a. Run the install script (Administrator PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\install-deploy-webhook.ps1
```

This builds `apps/deploy-webhook`, installs and starts the `deploy-webhook` NSSM service, and writes a secrets template at:

```
%USERPROFILE%\deploy-webhook\secrets\webhook.env
```

### 3b. Set the webhook secret

Edit the env file and fill in `DEPLOY_WEBHOOK_SECRET` with any strong random string (e.g. `openssl rand -hex 32`). Also set `DEPLOY_REPO_ROOT` to the absolute path of the cloned repo (e.g. `C:\Users\Duong\strawberry`).

```
%USERPROFILE%\deploy-webhook\secrets\webhook.env
```

Restart after editing:

```powershell
nssm restart deploy-webhook
```

### 3c. Expose port 9000 to GitHub

Choose one:

**Option A — Port forwarding (simplest if your ISP gives a stable public IP)**
1. Open Windows Firewall: allow inbound TCP 9000.
   - `netsh advfirewall firewall add rule name="deploy-webhook" protocol=TCP dir=in localport=9000 action=allow`
2. On your router: forward external TCP 9000 → Windows box LAN IP:9000.
3. Note your public IP (`curl ifconfig.me`).

**Option B — Cloudflare Tunnel (no port forwarding, free)**
```powershell
winget install --id Cloudflare.cloudflared
cloudflared tunnel --url http://localhost:9000
```
Copy the generated `https://*.trycloudflare.com` URL. Register `cloudflared` as an NSSM service for persistence so it survives reboots.

**Option C — ngrok (quick test, URL changes on restart)**
```powershell
ngrok http 9000
```

### 3d. Register the GitHub webhook

In the repo: **Settings > Webhooks > Add webhook**

| Field | Value |
|-------|-------|
| Payload URL | `http://<your-public-host>:9000/webhook` |
| Content type | `application/json` |
| Secret | same value as `DEPLOY_WEBHOOK_SECRET` |
| Events | Just the push event |

### 3e. Verify

```powershell
curl http://localhost:9000/health
# Should return: {"status":"ok"}
```

Push a commit to `main` and watch `apps/deploy-webhook/logs/stdout.log` for deploy output.

---

## 4. Adding a New Service

1. Add one entry to `scripts/windows/deploy-services.json`:

```json
{ "name": "<nssm-service-name>", "appDir": "apps/<app-dir>" }
```

2. Install the new service via NSSM (first time only):

```powershell
nssm install <nssm-service-name> node dist\index.js
nssm set <nssm-service-name> AppDirectory C:\path\to\strawberry\apps\<app-dir>
nssm set <nssm-service-name> Start SERVICE_AUTO_START
nssm start <nssm-service-name>
```

3. Commit `deploy-services.json` to `main`. The deploy webhook will pick it up on next push.

That's it. Future pushes to `main` will include the new service in the auto-deploy sweep.
