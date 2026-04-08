---
status: approved
owner: swain
date: 2026-04-09
slug: delivery-pipeline
---

# Delivery Pipeline — MyApps + discord-relay

End-to-end architecture to take an idea from Discord message → prod URL with
zero human gates. Pre-approved by Duong (`auto-approve everything, no human
gates, ship tonight`). This plan covers tasks 2–12 in the `delivery-pipeline`
team task list.

## 0. Tonight's Success Criterion

A single loop works unattended:

> Duong posts a message in a Discord forum → Gemini triage bot (on Cloud Run)
> files a GitHub issue labeled `ready` → a GitHub Action picks the issue up,
> runs a Claude-powered coder, pushes a branch, opens a PR → PR auto-merges
> into `main` → push to `main` deploys `apps/myapps` to Firebase Hosting
> and `apps/discord-relay` to Cloud Run. Duong receives the prod URL back in
> Discord.

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
                                        v (workflow: issues.labeled == ready)
                            +------------------------+
                            | .github/workflows/     |
                            | coder-agent.yml        |   [task 11]
                            |  - claude-code-action  |
                            |    (Anthropic API key) |
                            |  - creates branch      |
                            |  - opens PR w/ patch   |
                            +-----------+------------+
                                        |
                                        v (workflow: pull_request)
                            +------------------------+
                            | .github/workflows/     |
                            | auto-merge.yml         |   [task 7]
                            |  - waits for required  |
                            |    checks              |
                            |  - gh pr merge --auto  |
                            |    --squash            |
                            +-----------+------------+
                                        |
                                        v (push: main)
                +-----------------------+-----------------------+
                |                                               |
                v                                               v
  +-----------------------------+           +----------------------------------+
  | deploy-myapps.yml    [task8]|           | deploy-relay.yml          [task8]|
  |  - path filter: apps/myapps |           |  - path filter:                  |
  |  - npm ci && vite build     |           |    apps/discord-relay            |
  |  - firebase deploy          |           |  - gcloud auth via WIF           |
  |    --only hosting           |           |  - gcloud builds submit          |
  |  - (via WIF OIDC)           |           |  - gcloud run deploy             |
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

### 2.2 GitHub → GCP auth: Workload Identity Federation

No long-lived service account JSON keys. Use OIDC:

- Create a workload identity pool `github-pool` and provider
  `github-provider` bound to `token.actions.githubusercontent.com`, with
  attribute condition `assertion.repository == 'Duongntd/strawberry'`.
- Service account `github-deployer@strawberry-agents-discord.iam.gserviceaccount.com`
  with roles:
  - `roles/run.admin` (deploy Cloud Run)
  - `roles/iam.serviceAccountUser` (act as runtime SA)
  - `roles/artifactregistry.writer` (push images)
  - `roles/cloudbuild.builds.editor` (if using Cloud Build)
  - `roles/secretmanager.secretAccessor` (read deploy-time secrets)
  - `roles/firebasehosting.admin` (deploy hosting)
- Bind the pool's principal set to that SA via
  `iam.workloadIdentityUser`.
- Workflows use `google-github-actions/auth@v2` with
  `workload_identity_provider` + `service_account`. Zero secrets in CI for
  GCP auth.

### 2.3 Coder agent: `anthropics/claude-code-action` vs custom

**Decision: use `anthropics/claude-code-action` if it is published and
maintained on the GitHub Marketplace.** Rationale: reproduces the Claude Code
semantics Duong is already aligned with, supports `ANTHROPIC_API_KEY` out of
the box, handles sandboxing. **Fallback** (if the action is unpublished,
archived, or has open security CVEs at pickup time): custom workflow that
`npx @anthropic-ai/claude-code@latest -p "<prompt>" --permission-mode=accept`
inside an Ubuntu runner with a checked-out repo, then `gh pr create`.

- **Never route through Duong's Claude Max OAuth.** The coder agent uses a
  **separate pay-as-you-go Anthropic API key**, stored as GitHub Actions
  secret `ANTHROPIC_API_KEY` on the `Duongntd/strawberry` repository.
- Duong creates the key (escalation §5).

### 2.4 Secrets topology

| Secret | Home | Consumer |
|---|---|---|
| `DISCORD_BOT_TOKEN` | GCP Secret Manager (`discord-bot-token`) | discord-relay runtime |
| `GEMINI_API_KEY` | GCP Secret Manager (`gemini-api-key`) | discord-relay runtime |
| `GITHUB_TOKEN` (issue filing) | GCP Secret Manager (`gh-issue-bot-token`) | discord-relay runtime |
| `ANTHROPIC_API_KEY` | GitHub Actions Secret | coder-agent.yml |
| `FIREBASE_TOKEN` | not needed — use WIF | deploy-myapps.yml |
| GCP auth | OIDC (WIF), no secret | both deploy workflows |

Cloud Run wires Secret Manager secrets as env vars via
`--update-secrets=NAME=gcp-secret-name:latest`. No secrets ever appear in
source control or in plan files.

### 2.5 Auto-merge posture

- Branch protection on `main`:
  - Require status checks to pass before merging.
  - Required checks: `lint`, `typecheck`, `test` (existing MyApps CI) —
    start with whichever subset already passes; loosen if red tonight and
    Duong green-lights.
  - **Allow auto-merge: ON.** **Require approvals: 0** (Duong waived humans).
  - Enforce admins: OFF (so `gh pr merge --admin` is available as emergency
    override).
- `auto-merge.yml` runs on `pull_request.opened` and marks the PR with
  `gh pr merge --auto --squash` so it merges the moment checks go green.

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
- Set up Workload Identity Federation pool/provider/SA (step §2.2).
- Add GitHub repo secrets/variables: `GCP_WIF_PROVIDER`,
  `GCP_DEPLOY_SA`, `GCP_PROJECT_ID`, `FIREBASE_PROJECT_ID`,
  `GAR_REGION=asia-southeast1`, `ANTHROPIC_API_KEY`.

**Wave C — Deployment workflows (needs A + B):**
- **Task 4** — Deploy discord-relay to Cloud Run (one-shot, from main).
  `gcloud builds submit --tag` → `gcloud run deploy` with
  `--region=asia-southeast1 --min-instances=1 --max-instances=3
  --memory=512Mi --cpu=1 --port=8080
  --update-secrets=DISCORD_BOT_TOKEN=discord-bot-token:latest,...`.
- **Task 6** — Deploy MyApps to Firebase Hosting (one-shot, from main).
  `npm ci && npm run build && firebase deploy --only hosting`
  authenticated via WIF + `firebase-tools` with `--token` disabled (use
  application-default credentials from the WIF-issued token).
- **Task 8** — Convert both of the above into GitHub Actions triggered on
  `push: main` with path filters so MyApps changes don't redeploy the
  relay and vice versa.

**Wave D — Coder / merge plumbing (parallel with C):**
- **Task 7** — Configure branch protection (see §2.5) and add
  `auto-merge.yml`. Script-configure via `gh api` so it is reproducible,
  not clickops. Keep protection rules checked into
  `.github/branch-protection.json` as source of truth.
- **Task 11** — `coder-agent.yml`. Trigger:
  `issues.labeled where label.name == 'ready'`. Steps:
  1. `actions/checkout@v4`
  2. `anthropics/claude-code-action@v<latest>` with prompt assembled from
     issue title + body + a system prompt living at
     `.github/coder-agent/system.md` (scope: "you may only modify files
     under `apps/myapps/` or `apps/discord-relay/`; write tests; commit
     with `chore:` prefix").
  3. `peter-evans/create-pull-request@v7` (if the action doesn't open the
     PR itself) targeting `main`, label `coder-bot`.
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
| `.github/workflows/deploy-myapps.yml` | Firebase Hosting deploy on main | 6, 8 |
| `.github/workflows/deploy-relay.yml` | Cloud Run deploy on main | 4, 8 |
| `.github/workflows/auto-merge.yml` | `gh pr merge --auto --squash` | 7 |
| `.github/workflows/coder-agent.yml` | Claude issue → PR | 11 |
| `.github/workflows/auto-label-ready.yml` | Stamp `ready` on new issues | 12 |
| `.github/branch-protection.json` | Source-of-truth protection config | 7 |
| `.github/coder-agent/system.md` | System prompt for the coder agent | 11 |
| `apps/myapps/.firebaserc` | Pin Firebase project ID (if missing) | 5 |
| `infra/gcp/enable-apis.sh` | Idempotent API enablement script | 2 |
| `infra/gcp/wif-bootstrap.sh` | One-shot WIF pool/provider/SA script | B |
| `infra/gcp/secrets-bootstrap.sh` | Seed Secret Manager from local env | 3 |
| `infra/gcp/README.md` | Runbook for the above | all |

Keeping the bootstrap scripts under `infra/gcp/` instead of one-shot shell
commands means we can re-run them on a clean GCP project if the current
one is ever torn down. Architecture before expedience.

## 5. Escalations (needs Duong's hands)

1. **Anthropic API key** — new pay-as-you-go key, separate from Claude
   Max OAuth. Added to GitHub repo secrets as `ANTHROPIC_API_KEY`.
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
| Coder agent writes bad code that auto-merges and breaks prod | High | Medium | (a) Required status checks on `lint` + `typecheck` + `test` gate the merge even though humans don't. (b) Cloud Run keeps the previous revision; `gcloud run services update-traffic --to-revisions=PREVIOUS=100` as an instant rollback. (c) Firebase Hosting `firebase hosting:rollback`. Ship a `rollback.sh` in `infra/`. |
| WIF OIDC configuration subtly wrong → workflows can't auth | Medium | High | `iam-credentials` errors are loud. Start with a one-shot `gh workflow run hello-gcp.yml` that just calls `gcloud auth list`. If this step fails, nothing else runs — fail fast, fix once. |
| Discord gateway dies on Cloud Run cold start | Low | High | `min-instances=1` already addresses. If Cloud Run still kills the gateway on revision rollout, switch to Cloud Run **Jobs** running `forever`, or fall back to the Hetzner VPS already hosting Evelynn's relay. |
| Auto-merge races coder-agent's commits | Low | Medium | Concurrency group on coder-agent workflow keyed by issue number, and auto-merge waits for required checks anyway. |
| Secret Manager IAM lag after creation | Low | Low | `sleep 10` after IAM binding before first Cloud Run deploy, or retry loop. |
| `ANTHROPIC_API_KEY` rate-limited or billing runs out | Medium | Medium | Coder agent logs and no-ops. A failed coder run leaves the issue in `ready` state; Duong can retrigger by flipping the label. |
| Gemini triage files garbage issues | High | Low | Issues live in GitHub and are cheap to close. Coder agent fails cleanly on unintelligible input. Add a `needs-human` label path for Gemini-triage low-confidence outputs (follow-up, not tonight). |
| Forked-PR attack vector via auto-merge | Low | High | `pull_request` trigger only (no `pull_request_target`), and auto-merge workflow filters `github.event.pull_request.head.repo.full_name == github.repository`. |
| GitHub branch protection with 0 approvers blocks auto-merge on some plans | Low | Medium | Set "Require a pull request before merging" with "Required approvals = 0". If GitHub UI refuses, use Rulesets instead of legacy protection (`gh api -X POST /repos/.../rulesets`). |

## 7. Rollback / Kill-Switch

Every stage has a one-command rollback:

- **MyApps bad deploy:** `firebase hosting:rollback` (or re-deploy the
  previous `dist/`).
- **Relay bad deploy:** `gcloud run services update-traffic
  discord-relay --region=asia-southeast1 --to-revisions=PREVIOUS=100`.
- **Coder agent runaway:** remove `ANTHROPIC_API_KEY` from GitHub
  secrets; workflow no-ops immediately.
- **Auto-merge runaway:** disable `auto-merge.yml` via `gh workflow
  disable auto-merge.yml`; takes effect on next event.
- **Full kill:** flip branch protection to require 1 approval again
  (`gh api` with the JSON in `branch-protection.json` edited). That
  single knob pauses the entire pipeline.

## 8. What Ships Tonight vs Follow-Up

**Tonight:**
- Tasks 2, 3, 4, 5, 6, 7, 8, 11, 12 — full happy-path pipeline.
- Task 10 — at least one successful end-to-end run.

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
