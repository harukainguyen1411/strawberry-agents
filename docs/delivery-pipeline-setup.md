# Delivery Pipeline — Credentials & Setup Runbook

One-time setup for the autonomous delivery pipeline shipped 2026-04-09.
Check off each section as you finish it. Everything here needs **your hands** — either your browser, your terminal, or a paste into a secret file.

All paid options have been removed. Free tier only.

---

## 0. Prerequisites on your Windows computer

The three local workers (`discord-relay`, `coder-worker`, `bee-worker`) run on your always-on Windows box. Install these once:

- [ ] **Git for Windows** — `winget install Git.Git` (includes Git Bash + MSYS `flock`)
- [ ] **Node 20+** (per-user install, NOT system-wide, so `%USERPROFILE%\.claude\` OAuth resolves under NSSM) — `winget install OpenJS.NodeJS.LTS` then confirm `node --version` shows 20+
- [ ] **GitHub CLI** — `winget install GitHub.cli`, then `gh auth login` with the account that has access to `Duongntd/strawberry`
- [ ] **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`, then `claude` once to complete the Max-subscription OAuth login. **This must be logged in as YOU (Max plan), not via API key.**
- [ ] **NSSM** (service supervisor) — `winget install NSSM.NSSM`
- [ ] Optional: **Cursor** as editor — you already use it

---

## 1. GitHub repo security hardening (run in YOUR terminal)

You must run these as the repo owner (`Duongntd`). The collaborator PAT lacks admin scope.

```bash
gh api -X PUT repos/Duongntd/strawberry/vulnerability-alerts
gh api -X PUT repos/Duongntd/strawberry/automated-security-fixes
gh api -X PATCH repos/Duongntd/strawberry \
  -f security_and_analysis.secret_scanning.status=enabled \
  -f security_and_analysis.secret_scanning_push_protection.status=enabled
```

- [ ] Ran the three commands above
- [ ] Confirmed at https://github.com/Duongntd/strawberry/settings/security_analysis that Dependabot alerts, security updates, secret scanning, and push protection all show **Enabled**

---

## 2. Rotate the triage PAT to remove `workflow` scope

**Why:** the current `secrets/github-triage-pat.txt` has `repo` + `workflow` scopes. The `workflow` scope lets any process holding the PAT rewrite `.github/workflows/*.yml` and silently remove the `validate-scope` guardrail. Drop `workflow`.

- [ ] Go to https://github.com/settings/tokens
- [ ] Find the token labeled `strawberry-agents` (or whatever you named it)
- [ ] Click **Edit**
- [ ] **Uncheck** the top-level `workflow` box
- [ ] Leave `repo` (full) checked
- [ ] Click **Update token** at the bottom
- [ ] No need to re-paste — the token string is unchanged, just the permissions narrowed

---

## 3. Branch protection on `main`

**Why:** makes the approval gate an *enforced* control. Without branch protection, any collaborator with push access can bypass review procedurally.

The exact JSON payload is pending Pyke's review (he's auditing Fiora's draft right now). Once that lands, this section will contain the full `gh api PUT` command you paste into your terminal. Leave unchecked for now.

- [ ] `gh api PUT` command from Pyke/Fiora applied (coming soon)
- [ ] Confirmed at https://github.com/Duongntd/strawberry/settings/branches that `main` shows the rule with **Require a pull request before merging (1 approval)** + required status checks

---

## 4. Firebase project + service account (for MyApps deploys)

Katarina is setting up the Firebase project in parallel. Once she finishes, she'll paste the project ID here. Meanwhile, generate the service account JSON:

- [ ] Confirm the Firebase project ID (Katarina will report it — for now it's likely `strawberry-agents-discord` since we're reusing the same GCP project)
- [ ] Go to https://console.firebase.google.com → select the project
- [ ] **Project Settings** (gear icon top left) → **Service accounts** tab
- [ ] Click **Generate new private key** → **Generate key** → download the JSON file
- [ ] Open the downloaded JSON in Cursor — copy the ENTIRE content (it's a JSON object)
- [ ] Go to https://github.com/Duongntd/strawberry/settings/secrets/actions
- [ ] Click **New repository secret**
- [ ] Name: `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` (exact name — Fiora's workflows reference this string)
- [ ] Value: paste the whole JSON content (including the curly braces)
- [ ] Click **Add secret**
- [ ] **Delete the downloaded JSON file from your Downloads folder** — gitleaks will not catch this, and we do not want it sitting on disk

⚠️ Pyke flagged: scope this service account to **Firebase Hosting Admin** only (not Project Editor). In the GCP console → IAM → find the new service account → remove `Editor` role → add `Firebase Hosting Admin` role only.

---

## 5. Discord bot token (already done, verify only)

- [x] `secrets/discord-bot-token.txt` is populated with the Evelynn bot token
- [x] `MESSAGE CONTENT INTENT` enabled on the Evelynn bot app

Nothing to do here unless something breaks.

---

## 6. Gemini API key (already done, verify only)

- [x] `secrets/gemini-api-key.txt` is populated
- [x] Verified working via smoke test — Gemini 2.5 Flash Lite returned a triage verdict

Nothing to do here unless Gemini free tier changes.

---

## 7. Secrets file checklist

Your `secrets/` folder should now contain exactly these files (all gitignored):

- [ ] `secrets/gemini-api-key.txt` — live, working
- [ ] `secrets/discord-bot-token.txt` — live, working
- [ ] `secrets/github-triage-pat.txt` — live, working (narrowed to `repo` only in §2)
- [ ] `secrets/firebase-service-account.json` — pre-existing, needs confirmation it matches the one in §4 OR is a separate file used by the `bee-worker` Admin SDK subscription
- [ ] `secrets/recipients.txt` — age encryption recipients (unrelated, pre-existing)
- [ ] `secrets/encrypted/` — age-encrypted secrets, pre-existing

**Nothing else should exist in `secrets/`.** If you see stale files (e.g., old `agent-github-token`), delete them.

---

## 8. GitHub Actions Secrets checklist

Go to https://github.com/Duongntd/strawberry/settings/secrets/actions and confirm these are set:

- [ ] `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` — from §4
- [ ] `AGENT_GITHUB_TOKEN` — already set per Fiora's earlier note, used by the auto-label and (future) contributor-pipeline workflows

You should NOT need these (they were considered and rejected):
- ~~`ANTHROPIC_API_KEY`~~ — not used, coder-worker runs locally on Max
- ~~`GCP_WORKLOAD_IDENTITY_PROVIDER`~~ — not used, no Cloud Run deploys anymore

---

## 9. Windows worker installation (after §0 prerequisites)

Once the Windows computer has the prereqs from §0, run the three NSSM installers:

**discord-relay** (Gemini triage bot, no Claude):
- [ ] Open Git Bash as Administrator
- [ ] `cd` into the strawberry repo clone
- [ ] Run `scripts/windows/install-discord-relay.ps1` (Katarina will scaffold this)
- [ ] Verify: `nssm status discord-relay` shows **SERVICE_RUNNING**
- [ ] Post a test message in the Discord `#suggestions` forum → verify a GitHub issue appears on `Duongntd/strawberry`

**coder-worker** (Claude Max local worker, writes code from issues):
- [ ] Run `scripts/windows/install-coder-worker.ps1` (Katarina will scaffold this)
- [ ] Verify: `nssm status coder-worker` shows **SERVICE_RUNNING**
- [ ] Label an issue `ready` → verify a PR appears within ~1 minute

**bee-worker** (sister-agent Firebase queue worker, optional for tonight):
- [ ] Deferred — ship after the MyApps pipeline is proven

---

## 10. End-to-end smoke test

After steps 1–9 are green:

- [ ] Post a new post in Discord `#suggestions`: "The read tracker streak counter resets when I cross midnight Vietnam time"
- [ ] Verify: Gemini triages → GitHub issue filed with labels `myapps` + `bug` + `area/read-tracker` + `ready`
- [ ] Verify: coder-worker picks up the `ready` label within ~60 seconds
- [ ] Verify: coder-worker opens a PR with label `bot-authored`, branch `bot/issue-{number}`
- [ ] Verify: `firebase-hosting-pr-preview` workflow runs and comments a preview URL on the PR
- [ ] Click the preview URL → verify MyApps loads with the fix applied
- [ ] Review the diff tab of the PR (not just the preview URL — install-time and build-time attack surface lives in the diff)
- [ ] Click **Merge pull request** → **Squash and merge**
- [ ] Verify: `deploy-myapps-prod` workflow runs and deploys to Firebase Hosting live channel
- [ ] Open the live MyApps URL → verify the fix is live

---

## 11. Operational asks (ongoing)

Once the pipeline is live, when you review PRs authored by the coder-worker:

- **Always review the diff tab**, not just the Firebase preview URL. Preview shows runtime behavior; diff shows install-time (package.json, lockfile) and build-time (scripts, configs) changes — different attack surfaces.
- **Be extra cautious with PRs that touch `package.json`, `package-lock.json`, or anything outside `apps/myapps/`.** The `validate-scope` workflow blocks out-of-scope paths, but lockfile poisoning via a dependency update is a known supply-chain vector worth eyeballing.
- **If Claude's PR looks dense or weird, reject and re-run.** You're the gate.
- **Watch for prompt-injection exfil patterns.** Pyke REV 2 §11.6: a malicious issue body could try to steer Claude into `Read`ing files outside `apps/myapps/` (like `secrets/*.txt`) and exfiltrating their content via a commit body or a file written into `apps/myapps/`. Katarina's coder-worker scaffold locks this down at the tool level (drop `Bash` from allowed tools, restrict read paths where possible, log every tool call), but be alert if a PR has suspicious string literals in a commit message or contains base64-looking blobs in the diff.

---

## 12. Physical security on the Windows box (Pyke operational ask)

The Windows computer now holds long-lived production secrets (GitHub PAT, Discord bot token, Gemini API key) in plaintext and runs partly-untrusted AI-generated code. If the machine is stolen or compromised, those tokens go with it.

- [ ] **Enable BitLocker** on the system drive. `manage-bde -status C:` to check; Control Panel → BitLocker Drive Encryption if not already on. Recovery key: back up somewhere safe (NOT in the strawberry repo).
- [ ] **Real Windows login password** — no blank password, no PIN-only
- [ ] **Disable auto-login** — Settings → Accounts → Sign-in options → require sign-in "Every time"
- [ ] **Lock the screen when you walk away** — Win+L habit, or auto-lock after 5 minutes idle
- [ ] **Windows Defender real-time scanning** enabled (default, verify)
- [ ] **Automatic Windows Updates** enabled so kernel patches land without you thinking about it

---

## Notes

- This runbook is the source-of-truth setup checklist. Update it whenever the team lands a new piece of the pipeline.
- Plan of record: `plans/approved/2026-04-09-delivery-pipeline.md`
- Security assessment: `assessments/2026-04-09-delivery-pipeline-security.md`
