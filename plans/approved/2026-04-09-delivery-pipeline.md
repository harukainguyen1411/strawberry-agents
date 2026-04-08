---
status: approved
owner: swain
date: 2026-04-09
slug: delivery-pipeline
---

# Delivery Pipeline — MyApps + discord-relay

End-to-end architecture to take an idea from Discord message → PR with
preview URL → Duong's manual merge → prod. This plan covers tasks 2–12
in the `delivery-pipeline` team task list.

**Revision 2026-04-09 (post-team-lead correction):** Approval gate is
back. No auto-merge. Duong reviews each PR against a Firebase Hosting
preview URL and merges manually. Merge-to-main deploys prod. This plan
has been updated end-to-end to reflect that; `auto-merge.yml` is removed,
`firebase-hosting-pull-request` and `firebase-hosting-merge` Google
actions replace the custom deploy workflows for MyApps.

**Revision 2026-04-09 v2 (Max-plan coder worker pivot):** Coder agent
moves **out of GitHub Actions** and into a long-running Windows worker
on Duong's always-on computer. GitHub Actions runners are cloud
infrastructure, and running `claude -p` there under Duong's Max OAuth
violates Anthropic's ToS for Max (personal-use only). The worker polls
GitHub for `ready`-labeled issues, invokes `claude -p` locally under
Duong's Max login, pushes a branch, and opens a PR. `ANTHROPIC_API_KEY`
is no longer needed and removed from the escalation list. Firebase
Hosting preview/prod workflows, label workflow, and discord-relay Cloud
Run deploy all unchanged.

## 0. Tonight's Success Criterion

A gated loop works unattended until the human gate:

> Duong posts a message in a Discord forum → Gemini triage bot (on Cloud Run)
> files a GitHub issue → auto-label stamps `ready` → a GitHub Action picks
> the issue up, runs a Claude-powered coder, pushes a branch, opens a PR
> labeled `bot-authored` → Firebase Hosting posts a preview channel URL as
> a comment on the PR → **Duong reviews the preview and merges manually** →
> merge-to-main triggers `firebase-hosting-merge` and (for relay changes)
> Cloud Run deploy. discord-relay ships independently on its own path.

If any one leg breaks, the rest still ship independently — every stage is a
self-contained workflow.

## 1. Architecture (Data Flow)

```
+--------------------+      +------------------------+
| Discord forum post | ---> | discord-relay          |
| (Duong → channel)  |      | (Cloud Run, asia-se1)  |
+--------------------+      |  - discord.js gateway  |
                            |  - Gemini 2.5-flash-   |
                            |    lite triage         |
                            |  - Octokit issue file  |
                            +-----------+------------+
                                        |
                                        v (POST /repos/.../issues)
                            +------------------------+
                            | GitHub: Duongntd/      |
                            | strawberry             |
                            |  - new Issue created   |
                            +-----------+------------+
                                        |
                                        v (workflow: issues.opened)
                            +------------------------+
                            | .github/workflows/     |
                            | auto-label-ready.yml   |   [task 12]
                            |  - stamps `ready` label|
                            +-----------+------------+
                                        |
                                        v (polled every 60s by local worker)
                            +------------------------+
                            | apps/coder-worker/     |   [task 11 v2]
                            | (Windows, NSSM)        |
                            |  - polls GH for issues |
                            |    labeled `ready`     |
                            |    && `myapps` &&      |
                            |    !`bot-in-progress`  |
                            |  - atomic label swap:  |
                            |    ready→bot-in-       |
                            |    progress            |
                            |  - acquires shared     |
                            |    runlock             |
                            |    (~/.claude-runlock/ |
                            |     claude.lock)       |
                            |  - `claude -p` under   |
                            |    Duong's Max OAuth   |
                            |    (local, NOT cloud)  |
                            |  - git commit + push   |
                            |  - gh pr create, label |
                            |    `bot-authored`      |
                            |  - label swap on issue:|
                            |    bot-in-progress →   |
                            |    bot-pr-opened       |
                            +-----------+------------+
                                        |
                                        v (workflow: pull_request)
                            +------------------------+
                            | .github/workflows/     |
                            | myapps-pr-preview.yml  |   [task 7]
                            |  - path: apps/myapps   |
                            |  - npm ci && vite build|
                            |  - FirebaseExtended/   |
                            |    action-hosting-     |
                            |    deploy (preview)    |
                            |  - posts URL as PR     |
                            |    comment             |
                            +-----------+------------+
                                        |
                                        v
                            +------------------------+
                            |  HUMAN GATE            |
                            |  Duong reviews preview |
                            |  URL, merges PR        |
                            +-----------+------------+
                                        |
                                        v (push: main)
                +-----------------------+-----------------------+
                |                                               |
                v                                               v
  +-----------------------------+           +----------------------------------+
  | myapps-prod-deploy.yml [t8] |           | deploy-relay.yml          [task8]|
  |  - path filter: apps/myapps |           |  - path filter:                  |
  |  - npm ci && vite build     |           |    apps/discord-relay            |
  |  - FirebaseExtended/action- |           |  - gcloud auth via WIF           |
  |    hosting-deploy           |           |  - gcloud builds submit          |
  |    channelId=live           |           |  - gcloud run deploy             |
  +--------------+--------------+           +----------------+-----------------+
                 |                                            |
                 v                                            v
        https://<proj>.web.app                 https://discord-relay-<hash>-
        (or custom domain)                        as.a.run.app
                                                       ^
                                                       | (Discord gateway
                                                       |  keeps alive via
                                                       |  min-instances=1)
```

## 2. Key Decisions

### 2.1 Hosting targets

- **MyApps → Firebase Hosting.** It is a Vue 3 + Vite SPA (confirmed
  `apps/myapps/package.json`, `apps/myapps/firebase.json` already exists with
  `public: dist` and SPA rewrites). Pure static build output. Cloud Run would
  be ceremony for no gain. Firebase Hosting is free tier for this traffic.
- **discord-relay → Cloud Run.** It is a long-lived discord.js gateway
  client that also exposes an Express health endpoint (`src/health.ts`,
  `src/discord-bot.ts`). Dockerfile exists at `apps/discord-relay/Dockerfile`.
  Cloud Run with `min-instances=1` keeps the Discord websocket alive.
  - Region `asia-southeast1` (Duong's constraint).
  - Project `strawberry-agents-discord`.
  - Cost note: `min-instances=1` is NOT free tier — flag in escalations.

### 2.2 GitHub → GCP auth

Two auth paths, split by what each workflow touches:

**A. Firebase Hosting (MyApps PR previews + prod deploys) — service
account JSON via GitHub secret.** Use
`FirebaseExtended/action-hosting-deploy` (the official
Google-maintained action formerly `firebase-hosting-pull-request` /
`firebase-hosting-merge`). It expects `firebaseServiceAccount` as a
repo-level GitHub secret (`FIREBASE_SERVICE_ACCOUNT`) holding a JSON
key for a service account with `roles/firebasehosting.admin` and
`roles/serviceusage.serviceUsageConsumer` on the Firebase project.
Katarina generates this SA as part of task #6. We accept a long-lived
JSON key here because (a) it's scoped to hosting only, (b) the Google
action does not yet support WIF cleanly for Firebase Hosting PR
preview URLs, and (c) the approval gate means there is no auto-deploy
beyond preview channels anyway.

**B. Cloud Run (discord-relay deploy) — Workload Identity Federation.**
No long-lived keys for the relay path.

- Create workload identity pool `github-pool` and provider
  `github-provider` bound to `token.actions.githubusercontent.com`,
  with attribute condition
  `assertion.repository == 'Duongntd/strawberry'`.
- Service account
  `github-deployer@strawberry-agents-discord.iam.gserviceaccount.com`
  with roles:
  - `roles/run.admin` (deploy Cloud Run)
  - `roles/iam.serviceAccountUser` (act as runtime SA)
  - `roles/artifactregistry.writer` (push images)
  - `roles/cloudbuild.builds.editor` (if using Cloud Build)
  - `roles/secretmanager.secretAccessor` (read deploy-time secrets)
- Bind the pool's principal set to that SA via
  `iam.workloadIdentityUser`.
- The `deploy-relay.yml` workflow uses
  `google-github-actions/auth@v2` with `workload_identity_provider` +
  `service_account`. Zero secrets in CI for the relay deploy.

### 2.3 Coder agent: local Windows worker under Max OAuth

**Decision: the coder agent is a long-running local process on Duong's
always-on Windows computer, NSSM-supervised, invoking `claude -p`
interactively under Duong's own Max login.** It is NOT a GitHub Action.

Why: GitHub Actions runners are cloud infrastructure. Running `claude
-p` there under Duong's Max OAuth violates Anthropic ToS for Max plan
(personal-use only, not server-shaped automation). Running the same
command on Duong's own hardware under Duong's own login is exactly the
personal-automation pattern the Max plan is designed for. `claude-code-
action` + `ANTHROPIC_API_KEY` is also a valid path but Duong has chosen
to avoid API billing; Max-plan-on-own-hardware is the path.

**Shape of the worker** (`apps/coder-worker/`):

- Long-running Node TS process, NSSM service on Windows — same
  supervision pattern as discord-relay / Bee worker.
- Polls GitHub every `POLL_INTERVAL_SECONDS` (default 60) for open
  issues in `Duongntd/strawberry` where labels include `myapps` AND
  `ready` AND NOT `bot-in-progress`.
- Per matching issue, serialized via a local semaphore (`MAX_
  CONCURRENT_JOBS=1`):
  1. Atomic label swap via GitHub REST API: remove `ready`, add
     `bot-in-progress`. If the swap 409s because another worker got
     there first, skip the issue.
  2. `git fetch origin && git worktree add ... bot/issue-{number}`
     from latest `origin/main` (worktree, not raw checkout — matches
     strawberry's branch discipline).
  3. Acquire shared runlock at
     `%USERPROFILE%\.claude-runlock\claude.lock` via
     `proper-lockfile`. Same lock path Bee worker uses, so the two
     serialize against each other rather than racing Duong's own
     Claude Code sessions.
  4. Assemble prompt: `.github/coder-agent/system.md` (scope rules) +
     issue title + issue body, injected as `claude -p` arg.
  5. `execa('claude', ['-p', prompt, '--output-format', 'stream-json',
     '--max-turns', '25'])`. Stream output to a per-job log file under
     `var/jobs/{issue}.log`.
  6. `git add -A && git commit -m "chore: {title} (#${number})" &&
     git push origin bot/issue-{number}`.
  7. `gh pr create --label bot-authored --body "closes #${number}"`
     targeting `main`.
  8. Label swap on issue: remove `bot-in-progress`, add
     `bot-pr-opened`, post a comment with the PR URL.
  9. Release runlock and worktree, loop.

- Env:
  - `GITHUB_TOKEN` loaded from `secrets/github-triage-pat.txt` (same
    token discord-relay uses for issue filing).
  - `TRIAGE_TARGET_REPO=Duongntd/strawberry`
  - `POLL_INTERVAL_SECONDS=60`
  - `MAX_CONCURRENT_JOBS=1`
- Code is POSIX-portable per CLAUDE.md Rule 17; Windows-specific install
  helpers (NSSM registration) live under `scripts/windows/`.
- Reuse the `apps/discord-relay/` scaffolding shape wholesale — same
  TS project layout, same `config.ts`/`github.ts`/`log.ts` pattern,
  just swap the discord.js listener for a `setInterval` poll.

**Hard scope guardrail in the system prompt**
(`.github/coder-agent/system.md`): the prompt MUST include a literal
clause: "You may only modify files under `apps/myapps/`. You must NEVER
modify `.github/`, `.mcp.json`, `secrets/`, `scripts/`, `architecture/`,
`plans/`, or `agents/`." Prompt-layer guardrail, not a sandbox — the
worker runs as Duong's user and can theoretically touch anything, so the
system prompt is the only line of defense short of a separate OS user
account. Pyke's security assessment should weigh this.

**What is NOT needed anymore:**
- `ANTHROPIC_API_KEY` GitHub secret — gone.
- `anthropics/claude-code-action` marketplace action — gone.
- `.github/workflows/coder-agent.yml` — delete.

### 2.4 Secrets topology

| Secret | Home | Consumer |
|---|---|---|
| `DISCORD_BOT_TOKEN` | GCP Secret Manager (`discord-bot-token`) | discord-relay runtime |
| `GEMINI_API_KEY` | GCP Secret Manager (`gemini-api-key`) | discord-relay runtime |
| `GITHUB_TOKEN` (issue filing) | GCP Secret Manager (`gh-issue-bot-token`) | discord-relay runtime |
| `GITHUB_TOKEN` (coder worker PAT) | `secrets/github-triage-pat.txt` on Windows box (NTFS ACL to Duong's user only) | coder-worker |
| `FIREBASE_SERVICE_ACCOUNT` | GitHub Actions Secret (JSON) | myapps-pr-preview.yml, myapps-prod-deploy.yml |
| Cloud Run deploy auth | OIDC (WIF), no secret | deploy-relay.yml |

Cloud Run wires Secret Manager secrets as env vars via
`--update-secrets=NAME=gcp-secret-name:latest`. No secrets ever appear in
source control or in plan files.

### 2.5 Merge posture: human gate

No auto-merge. Duong is the approval gate.

- Branch protection on `main`:
  - Require PR before merging, **require 1 approval**, dismiss stale
    approvals on new commits.
  - Require status checks to pass: `lint`, `typecheck`, `test` (existing
    MyApps CI subset) + `myapps-pr-preview` (the preview deploy itself
    is a check — if it fails there's no URL to review).
  - **Allow auto-merge: OFF.**
  - Restrict who can push to `main`: nobody directly (PR-only).
  - Enforce admins: OFF (so Duong can emergency-merge).
- Every bot-authored PR carries label `bot-authored` for filtering. No
  workflow ever calls `gh pr merge`. The coder agent opens the PR and
  stops.
- Duong's review loop: open the PR on GitHub, click the preview URL
  posted by `FirebaseExtended/action-hosting-deploy`, verify, click
  Merge. Merge triggers `myapps-prod-deploy.yml` and (for relay edits)
  `deploy-relay.yml`.

## 3. Task Sequencing

Tasks 2–12 form a dependency graph. Execution waves:

**Wave A — GCP groundwork (parallel, blocks C,D):**
- **Task 2** — Enable GCP APIs on `strawberry-agents-discord`:
  `run.googleapis.com`, `cloudbuild.googleapis.com`,
  `artifactregistry.googleapis.com`, `secretmanager.googleapis.com`,
  `iamcredentials.googleapis.com`, `firebasehosting.googleapis.com`,
  `sts.googleapis.com`.
- **Task 3** — Push discord-relay secrets (`DISCORD_BOT_TOKEN`,
  `GEMINI_API_KEY`, issue-filing `GITHUB_TOKEN`) to Secret Manager. Grant
  the Cloud Run runtime SA `roles/secretmanager.secretAccessor` on each.
- **Task 5** — Inspect MyApps; confirm Vite build + `firebase.json`
  correctness; produce an `apps/myapps/.firebaserc` if missing pinning the
  Firebase project ID. (No Docker needed — Firebase Hosting is static.)
  The task name says "dockerize" — **override**: Swain's inspection in
  §2.1 determined MyApps is a static SPA; dockerizing is unnecessary
  ceremony. Rename task in flight to "Inspect MyApps + verify Firebase
  Hosting config".

**Wave B — Auth plumbing (parallel with A):**
- Set up Workload Identity Federation pool/provider/SA for the relay
  deploy path (step §2.2-B).
- Katarina generates the Firebase Hosting service account JSON (§2.2-A)
  as part of task #6 and hands it to Fiora to paste into GitHub secrets.
- Add GitHub repo secrets/variables: `GCP_WIF_PROVIDER`,
  `GCP_DEPLOY_SA`, `GCP_PROJECT_ID`, `FIREBASE_PROJECT_ID`,
  `GAR_REGION=asia-southeast1`, `ANTHROPIC_API_KEY`,
  `FIREBASE_SERVICE_ACCOUNT`.

**Wave C — Deployment workflows (needs A + B):**
- **Task 4** — Deploy discord-relay to Cloud Run (one-shot, from main).
  `gcloud builds submit --tag` → `gcloud run deploy` with
  `--region=asia-southeast1 --min-instances=1 --max-instances=3
  --memory=512Mi --cpu=1 --port=8080
  --update-secrets=DISCORD_BOT_TOKEN=discord-bot-token:latest,...`.
- **Task 6** — Firebase Hosting project + site setup for MyApps. Run
  `firebase init hosting` in `apps/myapps`, target the
  `strawberry-agents-discord` GCP project, commit `.firebaserc`,
  deploy once manually to confirm the prod URL, then generate the
  `FIREBASE_SERVICE_ACCOUNT` JSON and hand it to Fiora.
- **Task 8** — `myapps-prod-deploy.yml` (Firebase Hosting live channel
  on `push: main` with `paths: apps/myapps/**`) and `deploy-relay.yml`
  (Cloud Run on `push: main` with `paths: apps/discord-relay/**`).
  MyApps uses `FirebaseExtended/action-hosting-deploy@v0` with
  `channelId: live`. No OIDC for MyApps; OIDC for the relay only.

**Wave D — Preview / coder plumbing (parallel with C):**
- **Task 7** — `myapps-pr-preview.yml`. Trigger: `pull_request` with
  `paths: apps/myapps/**`. Steps: checkout → `npm ci && npm run build`
  in `apps/myapps` → `FirebaseExtended/action-hosting-deploy@v0` with
  `firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}`,
  `projectId: ${{ vars.FIREBASE_PROJECT_ID }}`, `expires: 7d`. The
  action auto-posts the preview URL as a PR comment. **Guard against
  fork PRs**: `if: github.event.pull_request.head.repo.full_name ==
  github.repository` so the secret never leaks to a forked PR. Also
  configure branch protection (§2.5) via `gh api` from
  `.github/branch-protection.json`.
- **Task 11 (v2)** — Scaffold `apps/coder-worker/` per §2.3. TS Node
  project modeled on `apps/discord-relay/`. Entry point polls GitHub,
  serializes via local semaphore, acquires shared runlock, runs
  `claude -p`, commits, pushes, opens PR, swaps labels. NSSM install
  helper under `scripts/windows/install-coder-worker.ps1`. Duong
  registers and starts the service on his Windows box.
- **Task 13 (new)** — Delete `.github/workflows/coder-agent.yml` (née
  `issue-to-pr.yml`) and any associated `.github/coder-agent/` assets
  from the GitHub Actions side. Move `.github/coder-agent/system.md`
  into `apps/coder-worker/prompts/system.md` so it lives with the
  thing that actually consumes it. Commit message: `chore: drop
  issue-to-pr github action — coder agent runs locally on max plan`.
  - Concurrency group keyed on issue number so re-labeling doesn't spawn
    duplicates.
- **Task 12** — `auto-label-ready.yml`. Trigger: `issues.opened`. Action:
  apply label `ready` if issue body contains the triage-bot signature
  footer (discord-relay stamps a known sentinel into the issue body, e.g.
  `<!-- triaged-by: discord-relay -->`). Alternative simpler form:
  label every new issue with `ready` unconditionally — acceptable
  tonight since Duong waived gates.

**Wave E — Hardening + verification:**
- **Task 9** — Security review of the deploy pipeline (Pyke/Fiora target).
  Checklist: WIF attribute condition is repo-scoped; SA has no excess
  roles; no long-lived keys anywhere; secrets only in Secret Manager /
  GitHub Secrets; coder agent cannot write outside `apps/**`; auto-merge
  cannot merge PRs from forks (`pull_request` not
  `pull_request_target`); no `workflow_dispatch` without auth.
- **Task 10** — End-to-end smoke test: Duong posts a toy request in
  Discord ("add a hello banner to MyApps home page"). Watch the full
  chain land a deployed change on `<project>.web.app`. If any stage
  stalls, note exact point for follow-up.

### Execution order summary

```
   A(2) A(3) A(5)     B(WIF,secrets)
     \   |   /          /
      \  |  /          /
       v v v          v
         C(4,6,8)    D(7,11,12)
             \       /
              v     v
                E(9,10)
```

Tasks 2,3,5 and Wave B can start immediately and in parallel. Tasks 4,6,8
wait for A+B. Tasks 7,11,12 wait only for B. Task 9 waits for everything
else; Task 10 is the final gate.

## 4. Concrete File Manifest

Files this pipeline will create or modify. Implementers should not go
beyond this list without flagging:

| Path | Purpose | Task |
|---|---|---|
| `.github/workflows/myapps-pr-preview.yml` | Firebase Hosting preview channel on PR | 7 |
| `.github/workflows/myapps-prod-deploy.yml` | Firebase Hosting live channel on merge-to-main | 6, 8 |
| `.github/workflows/deploy-relay.yml` | Cloud Run deploy on main | 4, 8 |
| `.github/workflows/auto-label-ready.yml` | Stamp `ready` on new issues | 12 |
| `.github/branch-protection.json` | Source-of-truth protection config | 7 |
| `apps/coder-worker/` | Local Windows coder worker (TS Node, NSSM) | 11 v2 |
| `apps/coder-worker/prompts/system.md` | Hard-scoped system prompt for the worker | 11 v2 |
| `scripts/windows/install-coder-worker.ps1` | NSSM registration helper | 11 v2 |
| `apps/myapps/.firebaserc` | Pin Firebase project ID | 6 |
| *(deleted)* `.github/workflows/coder-agent.yml` | — | 13 |
| *(deleted)* `.github/coder-agent/system.md` | moved into coder-worker | 13 |
| `infra/gcp/enable-apis.sh` | Idempotent API enablement script | 2 |
| `infra/gcp/wif-bootstrap.sh` | One-shot WIF pool/provider/SA script | B |
| `infra/gcp/secrets-bootstrap.sh` | Seed Secret Manager from local env | 3 |
| `infra/gcp/README.md` | Runbook for the above | all |

Keeping the bootstrap scripts under `infra/gcp/` instead of one-shot shell
commands means we can re-run them on a clean GCP project if the current
one is ever torn down. Architecture before expedience.

## 5. Escalations (needs Duong's hands)

1. ~~**Anthropic API key**~~ — **CANCELLED (revision v2).** Coder agent
   runs locally on Duong's Max plan. No API key needed.
2. **GCP billing confirmation** — Cloud Run `min-instances=1` is
   outside free tier. Estimated cost at 512Mi / 1 vCPU / always-on in
   `asia-southeast1`: ~USD 10–15/month. Confirm acceptable.
3. **GitHub branch protection write** — requires admin on
   `Duongntd/strawberry`. If the bootstrap script's `gh api` call 403s,
   Duong must run it himself or grant the deploy PAT admin scope
   temporarily.
4. **Firebase project ID** — confirm which Firebase project MyApps
   targets. `firebase.json` has no project ID; `.firebaserc` is missing.
   Most likely already-existing project owned by Duong.
5. **Verify `strawberry-agents-discord` GCP project has billing linked**
   — Secret Manager + Cloud Run both require it.
6. **Discord bot permissions** — confirm the bot token in Secret
   Manager is the production token, not a dev token, and that the bot
   is invited to the target forum with `Read Messages`, `Send
   Messages`, and `Create Public Threads`.

Anyone hitting one of these should **stop their task, post in the team,
and wait**. Do not work around by hard-coding a value.

## 6. Risk Register + Fallbacks

| Risk | Likelihood | Impact | Fallback |
|---|---|---|---|
| `claude-code-action` marketplace action missing or broken | Medium | High | Custom inline workflow shelling out to `@anthropic-ai/claude-code` CLI. Pre-stage the fallback workflow file as `coder-agent.custom.yml.disabled`. |
| Coder agent writes bad code that lands in prod | Low | Medium | **Primary defense is the human gate** — Duong reviews the preview URL before merging. Required status checks (`lint`, `typecheck`, `test`, `myapps-pr-preview`) gate the merge button. Cloud Run keeps the previous revision; `gcloud run services update-traffic --to-revisions=PREVIOUS=100` instant rollback. Firebase Hosting `firebase hosting:rollback`. Ship a `rollback.sh` in `infra/`. |
| WIF OIDC configuration subtly wrong → workflows can't auth | Medium | High | `iam-credentials` errors are loud. Start with a one-shot `gh workflow run hello-gcp.yml` that just calls `gcloud auth list`. If this step fails, nothing else runs — fail fast, fix once. |
| Discord gateway dies on Cloud Run cold start | Low | High | `min-instances=1` already addresses. If Cloud Run still kills the gateway on revision rollout, switch to Cloud Run **Jobs** running `forever`, or fall back to the Hetzner VPS already hosting Evelynn's relay. |
| Auto-merge races coder-agent's commits | Low | Medium | Concurrency group on coder-agent workflow keyed by issue number, and auto-merge waits for required checks anyway. |
| Secret Manager IAM lag after creation | Low | Low | `sleep 10` after IAM binding before first Cloud Run deploy, or retry loop. |
| Windows coder worker box is off / rebooting when issue arrives | Medium | Low | Polling loop picks up the issue on next boot. Issues live in GitHub indefinitely. NSSM auto-restarts the service on crash. |
| Coder worker races Duong's own Claude Code session | Medium | Medium | Shared runlock at `~/.claude-runlock/claude.lock` serializes all `claude -p` invocations on the box. Same lock Bee worker uses. |
| Coder worker writes outside `apps/myapps/` scope | Medium | High | System prompt has hard scope clause (§2.3). Branch protection + Duong's PR review are the final defense. No OS-level sandbox — accepted risk. |
| Prompt injection via GitHub issue body | Medium | Medium | Issue body is attacker-controllable in theory but the repo is personal-scoped and the issue filer is Gemini triage + Duong. Pyke's assessment covers this. |
| Gemini triage files garbage issues | High | Low | Issues live in GitHub and are cheap to close. Coder agent fails cleanly on unintelligible input. Add a `needs-human` label path for Gemini-triage low-confidence outputs (follow-up, not tonight). |
| Forked-PR attack vector leaks `FIREBASE_SERVICE_ACCOUNT` | Low | High | `myapps-pr-preview.yml` uses `pull_request` (not `pull_request_target`) and guards with `if: github.event.pull_request.head.repo.full_name == github.repository`. External contributors' PRs will not get preview URLs — acceptable for a personal repo. |
| Bot opens PR and forgets to include the preview check, Duong merges blind | Low | Medium | Branch protection requires `myapps-pr-preview` as a mandatory check; merge button stays grey without it. |

## 7. Rollback / Kill-Switch

Every stage has a one-command rollback:

- **MyApps bad deploy:** `firebase hosting:rollback` (or re-deploy the
  previous `dist/`).
- **Relay bad deploy:** `gcloud run services update-traffic
  discord-relay --region=asia-southeast1 --to-revisions=PREVIOUS=100`.
- **Coder worker runaway:** `nssm stop coder-worker` on the Windows
  box. Or flip the `ready` label off the offending issue. Or disable
  `auto-label-ready.yml` so no new issues get `ready`.
- **Preview channel runaway:** `gh workflow disable
  myapps-pr-preview.yml`. Existing preview channels auto-expire in 7
  days.
- **Full kill:** branch protection already requires human approval;
  stopping merges is just "don't click the button." To pause inbound
  bot PRs entirely, flip the `ready` label off on the repo or disable
  `auto-label-ready.yml`.

## 8. What Ships Tonight vs Follow-Up

**Tonight:**
- Tasks 2, 3, 4, 5, 6, 7, 8, 11, 12 — full happy-path pipeline with
  human gate at the PR merge.
- Task 10 — at least one successful end-to-end run (issue → PR →
  preview URL → Duong merges → prod).

**Follow-up (defer if time runs out):**
- Task 9 — deeper security review (but the inline security checks in
  §2.2, §2.5, §6 are mandatory tonight).
- Gemini confidence-based `needs-human` routing.
- Observability: Cloud Run logs → Cloud Logging dashboard; Firebase
  Hosting deploy history dashboard; alerting on workflow failures via
  Discord webhook.
- Cost guardrails: budget alert on `strawberry-agents-discord`
  ≥ USD 20/month.
- `rollback.sh` consolidated script under `infra/`.

## 9. Contract for Implementers

Any executor picking up tasks 2–12:

1. **Read this plan first.** Your task description is a pointer; the
   authoritative scope is the §3 wave you belong to + the §4 manifest
   rows your task owns.
2. **Do not widen scope.** If you think something else needs to change,
   post in the team channel; do not freelance.
3. **Every commit uses `chore:` prefix.** Pre-push hook enforces.
4. **No secrets in files, ever.** Use the patterns in §2.4.
5. **Stop at escalations.** If you hit §5, don't work around it.
6. **On success, mark the task completed** and post a one-line summary
   to the team (what changed, which file(s), any follow-up).
7. **On failure,** keep your task `in_progress`, post the error and
   what you tried, and wait. Do not mark complete on partial work.

Swain is available for architectural decisions if new blockers surface.
