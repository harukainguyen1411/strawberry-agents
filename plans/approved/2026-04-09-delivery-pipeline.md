---
status: approved
owner: swain
date: 2026-04-09
slug: delivery-pipeline
---

# Delivery Pipeline — MyApps + discord-relay + coder-worker

End-to-end architecture to take an idea from Discord message → PR with
preview URL → Duong's manual merge → prod. All services run either on
Duong's always-on Windows computer or in GitHub Actions / Firebase
Hosting. **Zero Cloud Run. Zero GCP billing. Fully free tier.**

## Revision history

- **v1 (2026-04-09):** initial design, auto-merge, Cloud Run, API keys.
- **v2 (2026-04-09):** approval gate restored; Firebase Hosting preview
  channels + manual merge; coder agent uses `claude-code-action` in GH
  Actions with `ANTHROPIC_API_KEY`.
- **v3 (2026-04-09):** coder agent pivoted out of GH Actions to a local
  Windows NSSM worker under Duong's Max OAuth (ToS compliance).
- **v4 (2026-04-09):** discord-relay also moves to the Windows
  computer. Cloud Run is decommissioned entirely. `ANTHROPIC_API_KEY`
  never exists. GCP billing escalation cancelled. Only GitHub Actions
  runners (for MyApps build/deploy) remain as cloud workloads, and
  those don't touch Claude so no ToS concern.
- **v5 (2026-04-09, this revision):** Post-ship state sync. All four
  tonight-escalations resolved. Hetzner contributor-pipeline killed —
  `contributor-pipeline.yml` and `contributor-merge-notify.yml`
  deleted at `e4bab47` on main. Branch protection applied with
  required checks `validate-scope` + `preview`. Firebase SA locked
  down per Pyke M6: `firebase-hosting-deployer@myapps-b31ea.iam.
  gserviceaccount.com` scoped to `roles/firebasehosting.admin` only,
  secret name `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`. M5 PAT
  rotated with `workflow` scope removed. Two new Wave T items for
  Katarina: deregister the Hetzner self-hosted runner from GitHub
  Actions runners list and shut down the Hetzner VPS.

## 0. Final Success Criterion

A gated loop works unattended until the human gate:

> Duong posts a message in a Discord forum → `discord-relay` (on Duong's
> Windows computer, NSSM-supervised) routes it through Gemini 2.5-flash-
> lite and files a GitHub issue → `label-new-issues.yml` stamps `ready`
> → `coder-worker` (also on the Windows box) polls GitHub, sees the
> labeled issue, atomically swaps the label to `bot-in-progress`,
> acquires the shared Claude runlock, runs `claude -p` under Duong's
> Max login locally, commits to a branch, pushes, opens a PR labeled
> `bot-authored` → `preview-myapps.yml` in GitHub Actions builds MyApps
> and deploys it to a Firebase Hosting preview channel, posting the URL
> as a PR comment → **Duong reviews the preview URL and merges manually**
> → `deploy-myapps-prod.yml` deploys to Firebase Hosting live channel.

If any leg breaks, the rest still ship independently — every stage is a
self-contained process or workflow.

## 1. Architecture (Data Flow)

```
                 DUONG'S WINDOWS COMPUTER (always-on, NSSM)
+-------------------------------------------------------------+
|                                                             |
|  +--------------------+                                     |
|  | discord-relay      |                                     |
|  | (NSSM service)     |                                     |
|  |  - discord.js      |                                     |
|  |  - Gemini 2.5      |                                     |
|  |    flash-lite      |                                     |
|  |  - Octokit         |                                     |
|  +---------+----------+                                     |
|            |                                                |
|            | files issue                                    |
|            v                                                |
|  [GitHub: Duongntd/strawberry] ---+                         |
|            ^                       \                        |
|            |                        \                       |
|            | polls every 60s         \ workflow:            |
|            |                          \  issues.opened      |
|            |                           v                    |
|            |         +-----------------------------------+  |
|            |         |  .github/workflows/               |  |
|            |         |  label-new-issues.yml  [cloud]    |  |
|            |         |   - adds label `ready`            |  |
|            |         +-----------------------------------+  |
|            |                                                |
|  +---------+----------+                                     |
|  | coder-worker       |                                     |
|  | (NSSM service)     |                                     |
|  |  - poll GH for     |                                     |
|  |    ready+myapps    |                                     |
|  |  - label swap:     |                                     |
|  |    ready →         |                                     |
|  |    bot-in-progress |                                     |
|  |  - runlock acquire |                                     |
|  |    (shared w/ bee) |                                     |
|  |  - `claude -p`     |                                     |
|  |    under Max OAuth |                                     |
|  |  - git commit+push |                                     |
|  |  - gh pr create    |                                     |
|  |    label:          |                                     |
|  |    bot-authored    |                                     |
|  |  - label swap:     |                                     |
|  |    bot-in-progress |                                     |
|  |    → bot-pr-opened |                                     |
|  +---------+----------+                                     |
|            |                                                |
|  +---------+----------+                                     |
|  | (future) bee-worker|                                     |
|  | shares runlock     |                                     |
|  +--------------------+                                     |
+-------------------------------------------------------------+
             |
             | opens PR
             v
         GITHUB ACTIONS (cloud, no Claude calls)
+-------------------------------------------------------------+
|   +---------------------------------+                       |
|   | preview-myapps.yml              |                       |
|   |  - on: pull_request             |                       |
|   |  - paths: apps/myapps/**        |                       |
|   |  - fork guard                   |                       |
|   |  - npm ci && vite build         |                       |
|   |  - FirebaseExtended/            |                       |
|   |    action-hosting-deploy        |                       |
|   |    (preview channel)            |                       |
|   |  - posts URL as PR comment      |                       |
|   +----------------+----------------+                       |
|                    |                                        |
|                    v                                        |
|          +---------+---------+                              |
|          |   HUMAN GATE      |                              |
|          |   Duong reviews   |                              |
|          |   preview URL,    |                              |
|          |   approves PR,    |                              |
|          |   merges          |                              |
|          +---------+---------+                              |
|                    |                                        |
|                    v (push: main)                           |
|   +---------------------------------+                       |
|   | deploy-myapps-prod.yml          |                       |
|   |  - on: push main                |                       |
|   |  - paths: apps/myapps/**        |                       |
|   |  - npm ci && vite build         |                       |
|   |  - FirebaseExtended/            |                       |
|   |    action-hosting-deploy        |                       |
|   |    channelId: live              |                       |
|   +----------------+----------------+                       |
+--------------------|----------------------------------------+
                     v
               FIREBASE HOSTING
               https://<proj>.web.app
```

## 2. Key Decisions

### 2.1 Where each process runs

| Service | Runs on | Supervision | Why |
|---|---|---|---|
| `discord-relay` | Windows PC | NSSM | Free tier. Discord gateway is long-lived, but the desktop is always-on, so no cold-start concern. No GCP billing. |
| `coder-worker` | Windows PC | NSSM | Must run under Duong's Max OAuth; Max is personal-use only; Duong's own hardware is the only compliant home. |
| `bee-worker` (future) | Windows PC | NSSM | Same shape, same machine, already planned separately. |
| MyApps build + preview deploy | GitHub Actions | — | Node + Firebase CLI. No Claude invocation. Cloud is fine. |
| MyApps prod deploy | GitHub Actions | — | Same. |
| Issue auto-label | GitHub Actions | — | Pure `gh api` call, no Claude. |
| MyApps hosting | Firebase Hosting | — | Static SPA; free tier easily covers personal traffic. |

### 2.2 Auth surfaces

Only **one** cloud-credential remains in the system:

- **`FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`** — JSON key stored as a
  GitHub Actions repo secret, consumed by
  `FirebaseExtended/action-hosting-deploy` in `preview-myapps.yml` and
  `deploy-myapps-prod.yml`. SA is
  `firebase-hosting-deployer@myapps-b31ea.iam.gserviceaccount.com`,
  scoped to **`roles/firebasehosting.admin` only** on the Firebase
  project (locked down per Pyke M6). We accept the long-lived JSON
  key here because the action does not support WIF cleanly for
  Firebase Hosting and the key is tightly scoped.

On the Windows box, tokens live in flat files under
`%USERPROFILE%\bee\secrets\` (or equivalent path to be decided by
Katarina while scaffolding), with NTFS ACLs restricting read to Duong's
user account. No environment variables exported globally — each NSSM
service reads its own secrets at startup.

No WIF. No GCP service accounts for discord-relay. No `ANTHROPIC_API_KEY`.

### 2.3 discord-relay: local NSSM service

`apps/discord-relay/` is repurposed from a Cloud Run container to a
local Windows service. Core TS code is unchanged (it was already
POSIX-portable). The change is how it runs:

- NSSM service name `discord-relay`, runs as Duong's user, start type
  automatic, restart on failure.
- Reads secrets from flat files under the secrets directory:
  - `gemini-api-key.txt`
  - `discord-bot-token.txt`
  - `github-triage-pat.txt` (for filing issues; reused by coder-worker)
- Env vars set via NSSM (or loaded from `.env` that the start script
  generates from the secret files):
  - `GEMINI_API_KEY`
  - `DISCORD_BOT_TOKEN`
  - `GITHUB_TOKEN`
  - `TRIAGE_DISCORD_CHANNEL_ID=1489570533103112375`
  - `TRIAGE_TARGET_REPO=Duongntd/strawberry`
- Install helper: `apps/discord-relay/scripts/windows/install-discord-
  relay.ps1`, mirroring the Bee worker install pattern.
- Start script (POSIX, runs under Git Bash):
  `apps/discord-relay/scripts/start-windows.sh` — reads the secret
  files, exports env vars, runs `npm start`. This is what NSSM
  ultimately invokes.
- `apps/discord-relay/.env.example` lists the env vars (no values) for
  documentation.
- README updated with Windows install instructions.

The Dockerfile stays in the tree for now (reference + option value) but
is no longer on any deploy path. It can be deleted in a follow-up.

### 2.4 coder-worker: local NSSM service under Max OAuth

`apps/coder-worker/` — new TS Node project modeled on
`apps/discord-relay/`. Same config/github/log shape, swapping the
discord.js listener for a GitHub polling loop.

Why local: GitHub Actions runners are cloud infrastructure. Running
`claude -p` there under Duong's Max OAuth violates Anthropic ToS for
Max plan (personal-use only). The desktop under Duong's own Max login
is the compliant home.

**Job loop** (serialized, `MAX_CONCURRENT_JOBS=1`):

1. Poll GitHub every `POLL_INTERVAL_SECONDS` (default 60) for open
   issues in `Duongntd/strawberry` with labels `myapps` AND `ready`
   AND NOT `bot-in-progress`.
2. **Atomic label swap** via GitHub REST API: remove `ready`, add
   `bot-in-progress`. If the swap 409s (another worker got there
   first), skip.
3. `git fetch origin && git worktree add ... bot/issue-{number}` from
   latest `origin/main`. Worktree, not raw checkout — matches the
   repo's branch discipline.
4. Acquire shared runlock at `%USERPROFILE%\.claude-runlock\claude.lock`
   via `proper-lockfile`. Same lock path Bee worker will use, so the
   two serialize against each other and against Duong's own Claude
   Code sessions.
5. Assemble prompt: `apps/coder-worker/prompts/system.md` (scope rules)
   + issue title + issue body.
6. `execa('claude', ['-p', prompt, '--output-format', 'stream-json',
   '--max-turns', '25'])`. Stream output to `var/jobs/{issue}.log`.
7. `git add -A && git commit -m "chore: {title} (#${number})" &&
   git push origin bot/issue-{number}`.
8. `gh pr create --label bot-authored --body "closes #${number}"`
   targeting `main`.
9. Label swap on issue: remove `bot-in-progress`, add `bot-pr-opened`,
   comment with PR URL.
10. Release runlock + worktree, loop.

**Env:**
- `GITHUB_TOKEN` from `secrets/github-triage-pat.txt` (same PAT
  discord-relay uses).
- `TRIAGE_TARGET_REPO=Duongntd/strawberry`
- `POLL_INTERVAL_SECONDS=60`
- `MAX_CONCURRENT_JOBS=1`

Core code POSIX-portable per CLAUDE.md Rule 17. NSSM registration
helper at `apps/coder-worker/scripts/windows/install-coder-worker.ps1`.

**Hard scope guardrail** in `apps/coder-worker/prompts/system.md` —
MUST include a literal clause:

> You may only modify files under `apps/myapps/`. You must NEVER
> modify `.github/`, `.mcp.json`, `secrets/`, `scripts/`,
> `architecture/`, `plans/`, or `agents/`.

Prompt-layer only; the worker runs as Duong's user and has full FS
access. System prompt + PR review are the only defenses short of a
separate OS user. Pyke's assessment covers this.

### 2.5 Merge posture: human gate

No auto-merge. Duong is the approval gate.

- Branch protection on `main`:
  - Require PR before merging, **require 1 approval**, dismiss stale
    approvals on new commits.
  - Require status checks to pass: **`validate-scope` + `preview`**
    (applied to main, verified live as of `e4bab47`). `validate-scope`
    enforces the "bot may only touch `apps/myapps/`" rule from Pyke's
    M6 payload; `preview` is the Firebase Hosting preview deploy —
    no URL to review means no green merge.
  - Allow auto-merge: OFF.
  - Direct push to `main`: disallowed (PR-only, except admin override
    for plan-file commits like this one).
  - Enforce admins: OFF (so Duong can emergency-merge).
- Every bot-authored PR carries label `bot-authored` for filtering. No
  workflow or worker ever calls `gh pr merge`. The coder worker opens
  the PR and stops.
- Duong's review loop: open PR on GitHub → click preview URL posted
  by `action-hosting-deploy` → verify → approve + merge. Merge
  triggers `deploy-myapps-prod.yml`.

### 2.6 Secrets topology

| Secret | Home | Consumer |
|---|---|---|
| `DISCORD_BOT_TOKEN` | `secrets/discord-bot-token.txt` on Windows box (NTFS ACL) | discord-relay |
| `GEMINI_API_KEY` | `secrets/gemini-api-key.txt` on Windows box (NTFS ACL) | discord-relay |
| `GITHUB_TOKEN` (PAT with `repo`) | `secrets/github-triage-pat.txt` on Windows box (NTFS ACL) | discord-relay + coder-worker |
| `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` | GitHub Actions repo secret (JSON) | preview-myapps.yml + deploy-myapps-prod.yml |
| `FIREBASE_PROJECT_ID` (=`myapps-b31ea`) | GitHub Actions repo variable | same |

No GCP Secret Manager. No Cloud Run runtime SA. No WIF. No Anthropic API key.

## 3. Task Sequencing (v4)

The task list has mostly completed through earlier pivots. What
remains after this v4 correction is primarily teardown + repurposing
plus the still-in-progress smoke test.

**Wave T — Teardown (Katarina, priority 1):**
- Delete the Cloud Run service that was deployed for task #4:
  `gcloud run services delete discord-relay --region asia-southeast1 --quiet`.
- Delete any GCP Secret Manager secrets created for discord-relay:
  `gcloud secrets delete gemini-api-key --quiet` (and any sibling
  entries). Verify `strawberry-agents-discord` has no residual
  billing-accruing resources.
- Optional: leave the GCP project itself in place; nothing bills
  without the services.
- **Hetzner cleanup (new in v5):**
  - Deregister the self-hosted runner from GitHub Settings →
    Actions → Runners on `Duongntd/strawberry`.
  - Shut down the Hetzner VPS (via `hcloud server delete` or the
    Hetzner console). Its sole purpose was the contributor-pipeline,
    whose workflows were deleted at `e4bab47`.

**Wave W — Windows-ification of discord-relay (Katarina):**
- Add `apps/discord-relay/scripts/windows/install-discord-relay.ps1`
  (NSSM registration, mirrors Bee worker pattern).
- Add `apps/discord-relay/scripts/start-windows.sh` (POSIX/Git Bash,
  reads secret files, exports env, runs `npm start`).
- Add `apps/discord-relay/.env.example`.
- Update `apps/discord-relay/README.md` with Windows install steps.
- Duong runs the install script on his Windows box, confirms the
  service starts, forum post → issue flow works end-to-end.

**Wave C — coder-worker scaffold (Katarina, optionally w/ Fiora):**
- Scaffold `apps/coder-worker/` TS Node project per §2.4. File layout:
  - `src/index.ts` — poll loop
  - `src/config.ts` — env loading
  - `src/github.ts` — Octokit wrapper, label swap, issue fetch, PR
    create
  - `src/claude.ts` — `execa` wrapper around `claude -p`
  - `src/runlock.ts` — `proper-lockfile` wrapper
  - `src/log.ts`
  - `prompts/system.md` — hard-scoped system prompt
  - `scripts/windows/install-coder-worker.ps1`
  - `scripts/start-windows.sh`
  - `package.json`, `tsconfig.json`, `.env.example`, `README.md`
- Duong registers the NSSM service, confirms a test issue walks the
  full loop and lands a PR.

**Wave G — GitHub Actions cleanup (Fiora): COMPLETE**
- `issue-to-pr.yml` deleted in an earlier commit.
- `contributor-pipeline.yml` + `contributor-merge-notify.yml`
  deleted at `e4bab47` (Hetzner kill).
- `preview-myapps.yml`, `deploy-myapps-prod.yml`,
  `label-new-issues.yml` live on main.
- Branch protection applied with required checks `validate-scope` +
  `preview`, verified live as of `e4bab47`.
- `myapps-pr-preview.yml` path-filter trap fix from Fiora M4 is live.

**Wave S — Verification (Task #10, whoever owns it):**
- End-to-end smoke test: Duong posts in the Discord forum → issue
  filed by local discord-relay → labeled `ready` by GH Action →
  coder-worker picks it up → PR opened → preview URL posted →
  Duong merges → live URL reflects the change. One full walk, any
  stage failure triaged at the break point.

Wave T and Wave W can run serially on Katarina. Wave G is parallel,
owned by Fiora and trivial. Wave C depends on the coder-worker spec
being locked in (it is, as of this revision). Wave S is last.

## 4. File Manifest (v4)

| Path | Purpose | Wave |
|---|---|---|
| `.github/workflows/preview-myapps.yml` | Firebase Hosting preview on PR | (exists, keep) |
| `.github/workflows/deploy-myapps-prod.yml` | Firebase Hosting live on merge-to-main | (exists, keep) |
| `.github/workflows/label-new-issues.yml` | Stamp `ready` on new issues | (exists, keep) |
| `.github/branch-protection.json` | Source-of-truth protection config | (exists, ensure 1 approval + preview-myapps check) |
| `apps/myapps/.firebaserc` | Pin Firebase project ID | (exists) |
| `apps/discord-relay/scripts/windows/install-discord-relay.ps1` | NSSM registration | W |
| `apps/discord-relay/scripts/start-windows.sh` | POSIX startup shim | W |
| `apps/discord-relay/.env.example` | Env var documentation | W |
| `apps/discord-relay/README.md` | Windows install instructions (update) | W |
| `apps/coder-worker/src/*.ts` | Poll loop, GH, Claude, runlock, log | C |
| `apps/coder-worker/prompts/system.md` | Hard-scoped system prompt | C |
| `apps/coder-worker/scripts/windows/install-coder-worker.ps1` | NSSM registration | C |
| `apps/coder-worker/scripts/start-windows.sh` | POSIX startup shim | C |
| `apps/coder-worker/package.json` + `tsconfig.json` + `.env.example` + `README.md` | project files | C |
| *(deleted)* `.github/workflows/issue-to-pr.yml` | — | G |
| *(deleted)* `.github/coder-agent/` | moved into apps/coder-worker/prompts/ | G |
| *(deleted at e4bab47)* `.github/workflows/contributor-pipeline.yml` | Hetzner kill | T |
| *(deleted at e4bab47)* `.github/workflows/contributor-merge-notify.yml` | Hetzner kill | T |
| *(deleted)* `apps/discord-relay/Dockerfile` | follow-up; not urgent | — |
| *(NOT created)* `infra/gcp/*` | GCP bootstrap scripts — cancelled, no GCP surface remains | — |

## 5. Escalations — ALL RESOLVED (v5)

All four tonight-escalations are cleared:

1. ✅ **Firebase project ID + SA secret** — `myapps-b31ea` +
   `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`. SA is
   `firebase-hosting-deployer@myapps-b31ea.iam.gserviceaccount.com`
   scoped to `roles/firebasehosting.admin` only (Pyke M6 lockdown).
2. ✅ **Branch protection** — applied to `main` with required checks
   `validate-scope` + `preview`. Verified live at `e4bab47`.
3. ✅ **Windows computer ready state** — Claude Code + Node + Git
   Bash + NSSM confirmed installed. Secrets directory NTFS ACL is
   Katarina's responsibility during install-script execution; the
   install scripts themselves must verify and refuse to register
   NSSM if the ACL is wrong (see §6 risk row).
4. ✅ **GitHub PAT** — rotated with `workflow` scope removed,
   `repo` scope retained. Runtime consumers (discord-relay, coder-
   worker) are unaffected.

**Cancelled** (phantom escalations from earlier revisions — do not
act on these, they do not exist):

- ~~Anthropic API key~~ — never needed.
- ~~GCP billing confirmation~~ — no Cloud Run, no billing.
- ~~WIF pool / provider / deploy SA setup~~ — no Cloud Run, no WIF.
- ~~Cloud Run deploy SA secret roles~~ — no Cloud Run.

## 6. Risk Register (v4)

| Risk | Likelihood | Impact | Fallback |
|---|---|---|---|
| Windows computer is off / rebooting when a Discord post arrives | Medium | Medium | discord-relay is down during the outage — posts made while down are lost unless Discord retention holds them. NSSM auto-restart on crash. Follow-up: periodic health ping + Duong alert. |
| Windows computer is off / rebooting when an issue is labeled `ready` | Medium | Low | coder-worker picks it up on next boot — issues live in GitHub indefinitely. |
| discord-relay and coder-worker compete for CPU / rate-limit on shared `GITHUB_TOKEN` | Low | Low | Both are tiny; GitHub PAT rate limit is 5000/hr per token. Not a real concern. |
| coder-worker races Duong's own Claude Code session | Medium | Medium | Shared runlock at `~/.claude-runlock/claude.lock` serializes all `claude -p` invocations on the box. Same lock Bee worker will use. |
| coder-worker writes files outside `apps/myapps/` scope | Medium | High | System prompt has hard scope clause (§2.4). Worker runs as Duong's user — no OS sandbox. Branch protection + PR review are the last line of defense. Accepted risk for a personal repo. |
| Prompt injection via GitHub issue body | Medium | Medium | Issue filer is Gemini triage filtering Duong's own Discord posts. Attack surface exists only if someone else files issues on the repo. Low risk for a personal repo; Pyke's assessment covers. |
| Secret files readable by other Windows users | Low | High | NTFS ACL enforcement on the secrets directory at install time. Install script must verify the ACL and refuse to register NSSM if it's world-readable. |
| Bad coder-worker output lands in prod | Low | Medium | Primary defense = human gate. Duong sees the preview URL before merging. Firebase Hosting rollback is instant (`firebase hosting:rollback`). |
| Fork-PR leaks `FIREBASE_SERVICE_ACCOUNT` | Low | High | `preview-myapps.yml` uses `pull_request` (not `pull_request_target`) + `if: github.event.pull_request.head.repo.full_name == github.repository`. Forked PRs get no preview. Acceptable for personal repo. |
| `preview-myapps` check missing from branch protection → Duong merges blind | Low | Medium | `.github/branch-protection.json` lists it explicitly; Pyke audits. |
| NSSM registration done wrong → service doesn't survive reboot | Low | Medium | Install script sets `start type = auto` explicitly; verification step pings service after reboot. |
| NSSM runs as SYSTEM instead of Duong's user → Claude OAuth missing | Low | High | Install script explicitly passes `--run-as <DuongUser>`. Verify with `nssm get discord-relay ObjectName`. |
| Issue body references a secret path or URL | Low | High | Prompt-layer guardrail tells the worker not to read outside `apps/myapps/`; git diff review at Duong's merge is the safety net. |
| Gemini triage files garbage issues | High | Low | Cheap to close. Follow-up: `needs-human` routing for low-confidence triage. |

## 7. Rollback / Kill-Switch

One-command per failure mode:

- **MyApps bad prod deploy:** `firebase hosting:rollback` (or
  redeploy previous `dist/`).
- **coder-worker runaway:** `nssm stop coder-worker` on the Windows
  box. Or flip `ready` label off. Or disable `label-new-issues.yml`.
- **discord-relay runaway (spammy issue filing):** `nssm stop
  discord-relay`.
- **Preview channel storm:** `gh workflow disable preview-myapps.yml`.
  Existing previews auto-expire.
- **Full pipeline pause:** `nssm stop` both Windows services. GitHub
  Actions workflows still run on human PRs but no bot pipeline
  activity.

## 8. What Ships Tonight vs Follow-Up

**Tonight (already mostly done per task board):**
- Wave T teardown (Cloud Run + GCP secrets).
- Wave W discord-relay Windows repurposing.
- Wave C coder-worker scaffold + install.
- Wave G GitHub Actions cleanup.
- Wave S one successful end-to-end smoke run.

**Follow-up:**
- Delete `apps/discord-relay/Dockerfile` (cruft).
- Delete the `strawberry-agents-discord` GCP project entirely (if no
  other service uses it).
- Deregister the Hetzner self-hosted GitHub runner and shut down the
  VPS (tracked in Wave T, Katarina).
- Pyke post-ship IAM audit: `gcloud projects get-iam-policy
  strawberry-agents-discord` and `gcloud projects get-iam-policy
  myapps-b31ea` after Wave T completes.
- Observability: Windows service log rotation; Discord webhook
  alert on NSSM restarts; PR-comment alert on coder-worker failure.
- `needs-human` label for low-confidence Gemini triage.
- Per-service health endpoints + a tiny local dashboard.
- Rule-17 portability audit of both services' scripts.
- Consider running NSSM services as a dedicated Windows user
  account instead of Duong's personal account (stronger blast-radius
  containment for coder-worker).

## 9. Contract for Implementers

1. **Read this plan first.** Your task description is a pointer; the
   authoritative scope is the §3 wave you belong to + the §4 manifest
   rows your task owns.
2. **Do not widen scope.** If you think something else needs to change,
   post in the team channel; do not freelance.
3. **Every commit uses `chore:` prefix.** Pre-push hook enforces.
4. **No secrets in files, ever.** Use the patterns in §2.6.
5. **No new cloud infrastructure.** If a task seems to require Cloud
   Run / GCP SA / API key / WIF — stop and post in the team. The
   answer is almost certainly "run it on the Windows box" or "skip it."
6. **Core code POSIX-portable** per CLAUDE.md Rule 17; Windows-only
   helpers under `scripts/windows/` in the owning app directory.
7. **On success,** mark your task completed and post a one-line
   summary to the team.
8. **On failure,** keep the task `in_progress`, post the error and
   what you tried, wait for help.

Swain is available for architectural decisions if new blockers surface.
