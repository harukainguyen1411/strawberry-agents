# Dark Strawberry Manual Test Plan — 2026-04-13

**Tester:** Duong  
**Scope:** 6 manual verification items across darkstrawberry.com and apps.darkstrawberry.com  
**Legend:** [ ] = not started, [x] = pass, [F] = fail

---

## 1. Landing Page Icon Audit

**What:** Verify darkstrawberry.com has all icons Neeko designed. Some are missing.

### Prerequisites
- Access to Neeko's design source (Figma — ask Neeko for the Dark Strawberry landing page Figma link if you don't have it)
- Browser with DevTools

### Steps

1. Open Neeko's Figma file for the Dark Strawberry landing page.
2. Make a list of every icon present in the design, noting which page section each appears in (hero, features, footer, nav, etc.).
3. Open `https://darkstrawberry.com` in a fresh browser window.
4. Hard-refresh: **Cmd+Shift+R** (macOS) to bypass cache.
5. For each section, compare live icons against the Figma reference:
   - Nav/header icons (logo, any navigation icons)
   - Hero section icons
   - Feature cards (look for icon slots that are empty or show placeholder text)
   - Footer (look for social icons, brand mark, Neeko credit icon)
6. Open DevTools → **Network** tab → filter by type **Img** or **Fetch/XHR**. Reload. Look for any 404s on SVG or icon asset URLs.
7. Open DevTools → **Console** tab. Check for any "failed to load resource" errors referencing icon files.
8. In the Elements panel, search for `<svg` and `<img` tags in sections that appear to be missing icons. Look for empty `src` attributes or missing component references.

### Expected Result
Every icon in Neeko's Figma design is visible on the live page. No 404s for icon assets. No empty icon slots.

### Pass/Fail
- [ ] All icons present
- [ ] No 404s for icon assets
- [ ] No console errors for icon resources

### Notes
- The DsIcon component system lives in `apps/shared/ui/icons/` (icons.ts + DsIcon.vue). If an icon is missing, it may not be registered in `icons.ts` or the icon name used in the component doesn't match.
- Neeko's footer credit (neeko icon) was added in commit 4920dd7 — confirm it renders.

---

## 2. Portal Design Population

**What:** `apps.darkstrawberry.com` should show Neeko's portal redesign. It currently may not.

### Prerequisites
- Access to `apps.darkstrawberry.com`
- Browser DevTools

### Steps

1. Open `https://apps.darkstrawberry.com` in a private/incognito window (eliminates extension interference).
2. Hard-refresh: **Cmd+Shift+R**.
3. Compare the page visually against Neeko's portal redesign. Key things to check:
   - PlatformHeader component — does it use DsIcon (svg icons) or old emoji?
   - Home.vue — does it show app cards with DsIcon icons (book, chart-line, checklist, bee) or old emoji/placeholder?
   - PlatformLayout footer — is the Neeko credit present?
   - AccessDenied.vue (navigate to a protected route while signed out) — DsIcon or old content?
4. Open DevTools → **Network** tab → hard-reload again. Look at JS/CSS asset filenames:
   - If filenames are like `index-abc123.js` with a hash, the build is content-addressed (good).
   - If you see `index.js` with no hash, caching may be stale.
5. In the **Network** tab, click any JS bundle file → check the **Response Headers** panel:
   - Look for `Cache-Control`. It should NOT be `max-age=3600` or similar long TTL on JS/CSS files.
   - For `index.html`, Cache-Control should be `no-cache` or `max-age=0`.
6. If the old design still shows after hard-refresh:
   - Open DevTools → **Application** tab → **Cache Storage** → delete all entries.
   - Open **Service Workers** → click "Unregister" if any are listed.
   - Reload and recheck.
7. If the design is still wrong after cache clear, the issue is likely a build/import problem. Check:
   - Go to `https://apps.darkstrawberry.com/assets/` (may 404, that's fine) — the goal is to see if the browser loads new asset hashes or old ones.
   - Note which components are visually wrong and report to Katarina/Evelynn with screenshot.

### Expected Result
Portal shows Neeko's redesign: DsIcon svg icons throughout, no emoji placeholders, Neeko footer credit visible.

### Pass/Fail
- [ ] DsIcon icons visible in header, home cards, footer
- [ ] No stale emoji placeholders
- [ ] Cache-Control headers on HTML: `no-cache` or `max-age=0`
- [ ] Cache-Control headers on JS/CSS: long-lived with content hash in filename

### Notes
- If caching headers are wrong, Ornn's caching fix (see Test 4) may not have deployed yet. Run Test 4 after that fix lands.
- The portal redesign was committed on the feat/platform-monorepo branch (commit 4920dd7) — confirm that branch's PR was merged to main and Firebase deployed it.

---

## 3. Discord Triage Full Flow

**What:** Post in `#request-your-app`, verify the full triage/routing pipeline responds end-to-end.

### Prerequisites
- Discord account with access to the Dark Strawberry server
- Access to the discord-relay logs (SSH to coder-worker VM or check Discord bot DM channel)
- Optionally: access to the bot's hosting environment to check logs

### Steps

1. Open Discord → navigate to the Dark Strawberry server → `#request-your-app` channel.
2. Post a test message: `Test request: I'd like a [test app name] app please`
3. Wait up to 60 seconds. Expected hops:
   - **Hop 1 — Webhook received:** The Discord webhook or bot should receive the message. Check: does the bot reply in-channel or react with an emoji?
   - **Hop 2 — Bot logged:** SSH to the coder-worker VM (see Test 6 for SSH command) and check discord-relay logs:
     ```bash
     ssh duong@136.113.135.178 "journalctl -u discord-relay -n 50 --no-pager"
     ```
     or if using PM2/nohup, check the process log file. Look for a log entry showing the message was received.
   - **Hop 3 — Triage/routing:** Confirm the bot routes the request. Look for a reply message in `#request-your-app` or a post in a triage/routing channel (check which channel is designated for triage output).
   - **Hop 4 — Response sent:** A response or acknowledgment should appear within the expected SLA (check architecture docs for the expected response time).
4. If any hop is silent, check:
   - Discord bot is online (green dot on bot user in server member list).
   - coder-worker VM is up (Test 6).
   - discord-relay process is running: `ssh duong@136.113.135.178 "ps aux | grep discord"`
5. Check the Discord bot token is valid — if the bot appears offline, the token may be expired. Token is in `secrets/` (gitignored) on the coder-worker VM.

### Expected Result
- Bot acknowledges the message in `#request-your-app` within ~30 seconds.
- Logs confirm message was received and routed.
- Triage response appears in the appropriate channel.

### Pass/Fail
- [ ] Bot is online in Discord
- [ ] Bot acknowledges message in #request-your-app
- [ ] discord-relay logs show message received
- [ ] Triage/routing output appears in designated channel

### Notes
- **Requires Discord bot token** (stored in secrets on coder-worker VM — do not commit).
- If the bot is offline, check if the discord-relay service crashed. Use `journalctl` or PM2 logs. Restart with the appropriate service manager command.

---

## 4. Deploy Caching Verification

**What:** After Ornn's caching fix lands (plan: `plans/approved/2026-04-13-deploy-caching-fix.md`), verify that deploys bust cache correctly and headers are set properly.

**Run this AFTER Ornn's fix is merged and deployed.**

### Prerequisites
- `curl` available in terminal
- Access to Firebase project (or Cloudflare if that's the CDN in use)
- A trivial change ready to deploy (e.g., add a `<!-- cache test -->` comment to index.html)

### Steps

1. **Baseline — check current headers before the fix:**
   ```bash
   curl -sI https://apps.darkstrawberry.com/ | grep -i cache-control
   curl -sI https://darkstrawberry.com/ | grep -i cache-control
   ```
   Note what Cache-Control headers are returned.

2. **Make a trivial change and deploy:**
   - In the myapps repo, make a visible but harmless change (e.g., add a space to a comment in `index.html` or bump a version string in the UI).
   - Commit and push to trigger CI/CD deploy.
   - Wait for deploy to complete (check GitHub Actions or Firebase Hosting deploy log).

3. **Verify hard-refresh clears within seconds:**
   - Open `https://apps.darkstrawberry.com` in browser.
   - Hard-refresh (**Cmd+Shift+R**) immediately after deploy completes.
   - Confirm the change is visible without waiting.

4. **Verify cache headers post-fix:**
   ```bash
   # HTML — should be no-cache or max-age=0
   curl -sI https://apps.darkstrawberry.com/ | grep -i cache-control

   # A hashed JS asset (get the filename from DevTools → Network tab)
   curl -sI "https://apps.darkstrawberry.com/assets/index-XXXXXXXX.js" | grep -i cache-control
   ```
   **Expected output for HTML:**
   ```
   cache-control: no-cache
   ```
   or
   ```
   cache-control: max-age=0, must-revalidate
   ```
   **Expected output for hashed JS/CSS assets:**
   ```
   cache-control: public, max-age=31536000, immutable
   ```

5. **Verify no 1-hour stale window:**
   - If before the fix, `cache-control: max-age=3600` was returned on HTML — confirm that value is gone post-fix.

6. **Repeat for darkstrawberry.com:**
   ```bash
   curl -sI https://darkstrawberry.com/ | grep -i cache-control
   curl -sI https://darkstrawberry.com/assets/index-XXXXXXXX.js | grep -i cache-control
   ```

### Expected Result
- HTML served with `no-cache` or `max-age=0`.
- Hashed JS/CSS assets served with `immutable` or `max-age=31536000`.
- Hard-refresh shows changes immediately after deploy — no 1h wait.

### Pass/Fail
- [ ] HTML Cache-Control is `no-cache` or `max-age=0`
- [ ] JS/CSS assets are `immutable` with long max-age
- [ ] Trivial change visible immediately after deploy + hard-refresh
- [ ] No `max-age=3600` on any HTML resource

### Notes
- If Firebase Hosting is the CDN, caching rules live in `firebase.json` under the `"headers"` key.
- **Requires Firebase or Cloudflare console access** to verify configuration if headers are still wrong.

---

## 5. Apps Smoke Test (Bee End-to-End + Spot Checks)

**What:** Walk the Bee app end-to-end and spot-check other apps.

### Prerequisites
- Logged into `apps.darkstrawberry.com` with a valid account
- Access to GitHub (github.com/Duongntd/myapps or the relevant repo)
- SSH access to coder-worker VM (136.113.135.178) for bee-worker logs

### Steps

#### 5a — Bee End-to-End

1. Navigate to `https://apps.darkstrawberry.com` → open the **Bee** app.
2. Submit a test app request through the Bee UI. Use a clearly named test request so you can identify it in logs.
3. Check the bee-worker is running on the coder-worker VM:
   ```bash
   ssh duong@136.113.135.178 "ps aux | grep bee-worker"
   ```
4. Watch bee-worker logs for the request to be picked up:
   ```bash
   ssh duong@136.113.135.178 "journalctl -u bee-worker -f --no-pager"
   ```
   (Ctrl+C to stop following)
5. Confirm the worker processes the request:
   - Log entry shows request received
   - Branch creation attempt logged
   - PR submission logged
6. Check GitHub for the created branch and PR:
   ```bash
   gh pr list --repo Duongntd/myapps --state open
   ```
   or open `https://github.com/Duongntd/myapps/pulls` in browser.
7. Verify PR was submitted with expected title/content.

#### 5b — Other Apps Spot Check

8. Navigate back to `https://apps.darkstrawberry.com`.
9. Open each app and verify it loads without errors:

   | App | URL Path | Quick Check |
   |-----|----------|-------------|
   | Read Tracker | `/read-tracker/` (or standalone URL) | Opens, shows book list |
   | Portfolio Tracker | `/portfolio-tracker/` | Opens, shows portfolio view |
   | Task List | `/task-list/` | Opens, shows task list |
   | Bee | (tested above) | — |

10. For each app, check DevTools Console for any JS errors during load.
11. Check `apps/myapps/` in the codebase for the current list of registered apps and confirm all appear on the portal home page.

### Expected Result
- Bee end-to-end: request submitted → worker picks up → branch created → PR submitted on GitHub.
- All other apps load without errors.
- Portal home shows all registered apps with correct icons.

### Pass/Fail
- [ ] Bee request submitted successfully via UI
- [ ] bee-worker logs show request received
- [ ] GitHub branch created
- [ ] GitHub PR submitted
- [ ] Read Tracker loads without errors
- [ ] Portfolio Tracker loads without errors
- [ ] Task List loads without errors
- [ ] No JS console errors on app load

### Notes
- **Requires GitHub access** (gh CLI or browser).
- If bee-worker is not running, check Test 6 for VM health first.
- The bee-worker source is in `apps/bee-worker/` (TypeScript, ESM). Restart with the appropriate service manager on the VM.

---

## 6. coder-worker VM Health Check

**What:** Confirm the coder-worker VM at 136.113.135.178 (e2-small, billed) is healthy and all systems running.

### Prerequisites
- SSH key configured for 136.113.135.178
- `gcloud` CLI authenticated (or access to GCP Console)

### Steps

#### 6a — VM Up Check

**Option A — gcloud CLI:**
```bash
gcloud compute instances list --filter="name:coder-worker" --format="table(name,status,zone,networkInterfaces[0].accessConfigs[0].natIP)"
```
Expected: `STATUS = RUNNING`, IP = `136.113.135.178`

**Option B — Direct ping:**
```bash
ping -c 3 136.113.135.178
```
Expected: 3 packets received, 0% loss

**Option C — SSH:**
```bash
ssh duong@136.113.135.178 "echo VM_OK && uptime"
```
Expected: `VM_OK` followed by uptime output (no connection refused).

#### 6b — Claude Auth Valid

```bash
ssh duong@136.113.135.178 "claude --version && claude auth status"
```
Expected: version printed, auth status shows authenticated (not expired/invalid).

If auth is invalid:
```bash
ssh duong@136.113.135.178 "claude auth login"
```
(This requires interactive login — complete it in the SSH session.)

#### 6c — Health-Check Cron Firing to Discord

1. Check cron is configured:
   ```bash
   ssh duong@136.113.135.178 "crontab -l"
   ```
   Look for a health-check entry (should reference a Discord webhook or message script).

2. Check recent cron execution logs:
   ```bash
   ssh duong@136.113.135.178 "grep CRON /var/log/syslog | tail -20"
   ```
   or
   ```bash
   ssh duong@136.113.135.178 "journalctl -u cron -n 20 --no-pager"
   ```

3. Check Discord — navigate to the health-check notification channel. Confirm a recent heartbeat message exists (should be within the last cron interval, e.g., last 5/15/60 minutes depending on schedule).

#### 6d — Manual Task Execution

1. SSH to the VM and run a minimal test task to confirm Claude execution works:
   ```bash
   ssh duong@136.113.135.178 "echo 'test task' | claude --print 'Respond with OK'"
   ```
   Expected: `OK` or similar acknowledgment (not an auth error or crash).

2. Confirm the worker process is running:
   ```bash
   ssh duong@136.113.135.178 "ps aux | grep -E 'bee-worker|discord-relay|coder' | grep -v grep"
   ```
   Expected: relevant worker processes listed.

#### 6e — Billing Sanity

1. Open GCP Console → Billing → check current month's cost for the e2-small instance is within expected range.
2. Confirm the VM is not running idle with nothing to do — if all services are stopped, consider whether the VM should be shut down to save costs.

### Expected Result
- VM is RUNNING and reachable via SSH.
- Claude auth is valid.
- Health-check cron is configured and recent Discord heartbeat is present.
- Manual task execution returns a valid response.

### Pass/Fail
- [ ] VM status = RUNNING (gcloud or ping)
- [ ] SSH connection succeeds
- [ ] Claude auth valid
- [ ] Health-check cron entry exists in crontab
- [ ] Recent Discord heartbeat message present
- [ ] Manual claude task execution succeeds
- [ ] Worker processes running

### Notes
- **Requires GCP Console access** for billing check and instance management.
- **Requires SSH key** for 136.113.135.178. If key is missing from your local machine, retrieve it from `secrets/` or re-provision via GCP Console (Compute Engine → SSH keys).
- VM is billed even when idle — confirm it is needed before leaving it running.
