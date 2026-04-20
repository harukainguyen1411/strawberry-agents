---
title: Coder-worker delivery feedback loop
status: proposed
owner: bard
date: 2026-04-09
---

# Coder-worker delivery feedback loop

## Goal

Close the loop from Discord suggestion → GitHub issue → coder-worker PR → Firebase preview → Discord approval → production deploy, so Duong can ship a feature end-to-end without leaving Discord except to eyeball the preview.

## Current state

- **discord-relay** (Node/TS, Windows NSSM): Discord message → Gemini triage → `gh issue create` with `coder-task` (or `myapps` + `app:<x>` + `type:<y>`) label in the right repo. Knows the source channel ID.
- **coder-worker** (Node/TS, Windows NSSM): Polls/webhook GitHub issues with `coder-task` label → Claude implements → opens PR. Currently no reviewer assignment, no Discord callback.
- **Firebase Hosting CI/CD**: `.github/workflows/firebase-hosting-pull-request.yml` already generates a preview channel URL on every PR. Output currently only lives in the Actions log / PR comment.
- **Staging**: skipped. Preview → prod directly on merge to main.

## Architecture overview

```
Discord (#app-x-suggestions)
   │  msg
   ▼
discord-relay ──► Gemini triage ──► gh issue create
   │                                    │  body carries:
   │                                    │    discord_channel_id
   │                                    │    discord_message_id
   │                                    │    discord_user_id
   │                                    ▼
   │                               GitHub issue (coder-task, app:x)
   │                                    │
   │                                    ▼
   │                            coder-worker picks up
   │                                    │
   │                                    ▼
   │                               PR opened
   │                                    │  PR body carries forwarded metadata
   │                                    │  + "Closes #<issue>"
   │                                    │  reviewer auto-assigned: Duongntd
   │                                    ▼
   │                        Firebase Hosting PR workflow
   │                                    │  preview URL produced
   │                                    ▼
   │                        New workflow step: notify-discord
   │                                    │  POST to discord-relay webhook
   │                                    │    { pr, preview_url, channel_id, issue }
   │◄───────────────────────────────────┘
   │  discord-relay posts in original channel:
   │    "PR #N ready — preview: <url>  react ✅ to merge"
   │
   ▼
Discord user (Duong) reacts ✅
   │
   ▼
discord-relay reaction handler
   │  auth-gates on discord_user_id == DUONG_DISCORD_ID
   │  calls GitHub API: merge PR
   ▼
main branch
   │
   ▼
Firebase Hosting merge workflow → production deploy
   │
   ▼
discord-relay posts "Shipped 🚀 <prod_url>" in same channel
```

## Component 1 — Metadata threading (issue → PR → Discord)

The single hardest problem is keeping the Discord channel ID alive across four system boundaries. Solution: encode it in the GitHub issue body as a fenced metadata block, and propagate forward.

### discord-relay change

When filing the issue, append a trailing hidden-ish block:

```markdown
<!-- strawberry-meta
discord_channel_id: 1234567890
discord_message_id: 9876543210
discord_user_id: 1111111111
discord_guild_id: 2222222222
origin: discord-relay
-->
```

- Must be the **last** block in the body.
- Parser is regex: `/<!-- strawberry-meta\n([\s\S]*?)\n-->/`.
- Values are `key: value` YAML-ish, no nesting.

### coder-worker change

When opening the PR:

1. Read the triggering issue body.
2. Extract the `strawberry-meta` block.
3. Re-emit the **same block verbatim** at the end of the PR body.
4. Also add a `Closes #<issue>` line above it so GitHub auto-closes the issue on merge.

### GitHub Actions change

The `notify-discord` step (Component 3) reads `${{ github.event.pull_request.body }}` and parses the same block. No GitHub secrets needed for the channel ID — it rides in the PR body.

## Component 2 — Auto-assign reviewers on coder-worker PRs

### Reviewers

Standard two-reviewer pattern for all coder-worker PRs:

| Role | Reviewer | Responsibility |
|------|----------|----------------|
| Reviewer 1 | **Lissandra** | Logic and security review |
| Reviewer 2 | **Bard** (plan `owner:`) | Plan author — implementation correctness |

### Config

Add to `coder-worker`'s config file (e.g. `config/reviewers.yaml` or env):

```yaml
reviewers:
  default: ["Duongntd"]
```

Single monorepo (`strawberry`), single user — no per-label reviewer overrides needed. `resolveReviewers` just returns the default list (minus the PR author).

### Env var

```
CODER_WORKER_DEFAULT_REVIEWERS=Duongntd
```

Comma-separated GitHub usernames. Config file wins if both set.

### Implementation

In the PR-open code path (`octokit.pulls.create` result in hand):

```ts
await octokit.pulls.requestReviewers({
  owner, repo,
  pull_number: pr.number,
  reviewers: resolveReviewers(issueLabels), // string[]
});
```

`resolveReviewers` walks `by_label` first, falls back to `default`, dedupes, drops the PR author (GitHub rejects self-review). Non-fatal on 422 — log warning, do not abort PR open.

### Tests

- Unit: `resolveReviewers` with empty labels → default.
- Unit: with matching label → label list.
- Unit: with PR author in list → filtered.
- Integration: mock octokit, assert `requestReviewers` called with expected shape.

## Component 3 — Post preview link back to Discord

### New GitHub Actions step

Edit `.github/workflows/firebase-hosting-pull-request.yml`. The existing `FirebaseExtended/action-hosting-deploy` action emits `outputs.details_url`. Add a new step **after** the deploy step:

```yaml
      - name: Notify Discord relay
        if: always() && steps.firebase_deploy.outputs.details_url != ''
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          PREVIEW_URL: ${{ steps.firebase_deploy.outputs.details_url }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          PR_URL: ${{ github.event.pull_request.html_url }}
          PR_BODY: ${{ github.event.pull_request.body }}
          REPO: ${{ github.repository }}
        run: node .github/scripts/notify-discord-preview.js
```

### Helper script

New file `.github/scripts/notify-discord-preview.js` (vanilla Node, no deps beyond stdlib `https` + `crypto`):

- Parses `strawberry-meta` out of `PR_BODY`.
- If no block → exit 0 (not every PR originated in Discord).
- POSTs JSON to `DISCORD_RELAY_WEBHOOK_URL` with HMAC-SHA256 of body under header `X-Strawberry-Signature` using `DISCORD_RELAY_WEBHOOK_SECRET`.
- Payload:
  ```json
  {
    "kind": "preview_ready",
    "pr_number": 123,
    "pr_url": "...",
    "pr_title": "...",
    "preview_url": "...",
    "repo": "duong/myapps",
    "discord_channel_id": "...",
    "discord_user_id": "...",
    "discord_message_id": "..."
  }
  ```

### discord-relay change — new HTTP endpoint

New route `POST /hooks/github` on the existing HTTP server (discord-relay already runs a health server on Windows).

1. Verify HMAC header using `DISCORD_RELAY_WEBHOOK_SECRET` (constant-time compare). Reject 401 on mismatch.
2. Switch on `kind`:
   - `preview_ready` → post an embed to `discord_channel_id` **as a reply to the original suggestion message** (`message_reference: { message_id: discord_message_id, channel_id: discord_channel_id, fail_if_not_exists: false }`):
     ```
     **PR #{pr_number}: {pr_title}**
     Preview: {preview_url}
     PR: {pr_url}
     React ✅ to merge, ❌ to close.
     ```
     Store `{message_id → {pr_number, repo, channel_id, requester: discord_user_id, source_message_id}}` in `state/pending-prs.json` (JSON file keyed by discord message ID, guarded by `proper-lockfile`).
   - `shipped` → "Shipped 🚀 <prod_url>" **also posted as a reply to the original suggestion message** (`message_reference` to `source_message_id`), so both the preview notification and the ship confirmation thread under the source suggestion.

### Exposing the webhook

discord-relay runs on a Windows box behind home NAT. Options, in order of preference:

1. **Cloudflare Tunnel (`cloudflared`)** — free, no router config, stable DNS. Recommended.
2. **Tailscale Funnel** — fine if Duong already runs Tailscale.
3. **ngrok paid static domain** — fallback.

Plan assumes Cloudflare Tunnel. Add to the discord-relay README: instructions to install `cloudflared` as a second NSSM service pointing at the relay's HTTP port, and register a hostname like `relay.strawberry.<duong-domain>`.

Stored as GitHub repo secret `DISCORD_RELAY_WEBHOOK_URL = https://relay.strawberry.<domain>/hooks/github`.

## Component 4 — Discord approval → merge

### Reaction handler

discord-relay already has a Discord.js Gateway connection. Add a `messageReactionAdd` listener.

Algorithm:

1. Ignore bot reactions.
2. Look up `reaction.message.id` in `state/pending-prs.json`. If miss → ignore.
3. Check `reaction.user.id === process.env.APPROVER_DISCORD_ID`. If mismatch → optionally react with ⛔ and bail.
4. If emoji is ✅:
   - Use an `octokit` instance authed with a classic PAT (`GITHUB_TOKEN` env, `repo` scope on the `strawberry` monorepo).
   - Call `octokit.pulls.merge({ owner, repo, pull_number, merge_method: 'squash' })`.
   - On success: react ✅ back on the message, post reply "Merging → prod deploy in flight".
   - Remove entry from `pending-prs.json`.
5. If emoji is ❌:
   - `octokit.pulls.update({ state: 'closed' })`.
   - Post reply "Closed PR #N."
   - Remove entry.
6. Any other emoji → ignore.

### Security

- **Only `APPROVER_DISCORD_ID` can approve.** Hard-coded check, no role-based fanciness. Env var, not config file.
- **HMAC on inbound webhook** prevents randoms calling `/hooks/github` to spoof preview URLs (which would poison `pending-prs.json` and let them trick Duong into merging).
- **Classic GitHub PAT** with `repo` scope on the `strawberry` monorepo (single private repo, single user — fine-grained buys nothing).
- **Rate limit** the reaction handler: max 1 merge per 30s to prevent runaway loops if the state file gets corrupted.
- **Audit log**: append every merge/close decision to `state/approval-audit.log` (JSONL, timestamp + pr + actor + action).

### Production deploy confirmation

The existing `firebase-hosting-merge.yml` workflow runs on `push: main`. Add the same `notify-discord-preview.js` call but with `kind: "shipped"` and the live hosting URL (from `details_url` of the merge deploy, or hardcoded per-repo).

To carry the Discord channel ID across merge commits, encode it in the squash-merge commit message. coder-worker's PR already has the `strawberry-meta` block in the body; GitHub's squash merge concatenates PR body into the commit message by default, so the block survives. The merge workflow parses it out of `${{ github.event.head_commit.message }}`.

## File-by-file change summary

### coder-worker

| File | Change |
|------|--------|
| `src/config/reviewers.ts` (new) | Load reviewers config + env, export `resolveReviewers(labels)` |
| `src/pr/open.ts` | After `pulls.create`, call `pulls.requestReviewers`; re-emit `strawberry-meta` from issue into PR body; add `Closes #<issue>` |
| `src/issue/parse.ts` (new or extend) | `extractStrawberryMeta(body): Record<string,string> \| null` |
| `config/reviewers.yaml` (new) | Default `Duongntd` + per-label overrides |
| `.env.example` | `CODER_WORKER_DEFAULT_REVIEWERS=Duongntd` |
| `README.md` | Document reviewer config + metadata passthrough |
| `test/reviewers.test.ts` (new) | Unit tests |
| `test/meta-passthrough.test.ts` (new) | Unit test for issue→PR meta block |

### discord-relay

| File | Change |
|------|--------|
| `src/triage/fileIssue.ts` | Append `strawberry-meta` block to issue body |
| `src/http/server.ts` | Register `POST /hooks/github` |
| `src/http/githubWebhook.ts` (new) | HMAC verify, dispatch by `kind` |
| `src/discord/postPreview.ts` (new) | Post embed, record in `pending-prs.json` |
| `src/state/pendingPrs.ts` (new) | JSON file read/write with file-lock (use `proper-lockfile`) |
| `src/discord/reactionHandler.ts` (new) | `messageReactionAdd` listener, approver gate, merge/close |
| `src/github/client.ts` (new or extend) | Octokit singleton with `GITHUB_TOKEN` |
| `src/state/auditLog.ts` (new) | Append-only JSONL audit |
| `.env.example` | `APPROVER_DISCORD_ID`, `GITHUB_TOKEN`, `DISCORD_RELAY_WEBHOOK_SECRET` |
| `README.md` | Cloudflare Tunnel setup, new env vars, flow diagram |
| `test/webhook.test.ts` (new) | HMAC verify happy path + tamper path |
| `test/reaction.test.ts` (new) | Approver gate, merge path mocked |

### GitHub Actions (`strawberry` monorepo — single repo, covers `myapps`)

| File | Change |
|------|--------|
| `.github/workflows/firebase-hosting-pull-request.yml` | Add `Notify Discord relay` step after deploy |
| `.github/workflows/firebase-hosting-merge.yml` | Same step with `kind: shipped` |
| `.github/scripts/notify-discord-preview.js` (new) | Parse meta, HMAC-sign, POST |

### Strawberry repo

| File | Change |
|------|--------|
| `architecture/coder-worker-feedback-loop.md` (new) | Sequence diagram + contract for `strawberry-meta` block + webhook payload schema |
| `secrets/coder-worker-feedback.env.example` | Example env |

## New env vars / secrets

### discord-relay (Windows, NSSM service env)

| Var | Purpose |
|-----|---------|
| `APPROVER_DISCORD_ID` | Duong's Discord user ID, gates merge reactions |
| `GITHUB_TOKEN` | Classic PAT with `repo` scope on the `strawberry` monorepo |
| `DISCORD_RELAY_WEBHOOK_SECRET` | Shared HMAC secret with GitHub Actions |
| `HTTP_PORT` | Already exists, confirm it's distinct from the health port |

Stored in `secrets/discord-relay.env` (gitignored), loaded by the NSSM wrapper.

### coder-worker (Windows, NSSM service env)

| Var | Purpose |
|-----|---------|
| `CODER_WORKER_DEFAULT_REVIEWERS` | Comma-separated GH usernames |

### GitHub repo secrets (`strawberry` monorepo)

| Secret | Value |
|--------|-------|
| `DISCORD_RELAY_WEBHOOK_URL` | `https://relay.strawberry.<domain>/hooks/github` |
| `DISCORD_RELAY_WEBHOOK_SECRET` | matches discord-relay |

## Rollout order

1. **Phase A — Metadata plumbing (no user-visible change):**
   - discord-relay emits `strawberry-meta` block.
   - coder-worker parses + re-emits in PR body.
   - Ship. Verify on a dummy issue.
2. **Phase B — Reviewer auto-assign:**
   - Ship coder-worker reviewer config.
   - Verify on a dummy PR.
3. **Phase C — Preview link back to Discord:**
   - Stand up Cloudflare Tunnel + relay HTTP endpoint (no auth yet, test local).
   - Wire HMAC + GitHub secret.
   - Add Actions step in `strawberry` repo (covers `myapps` — it's the only repo).
   - End-to-end test: file issue via Discord → wait for PR → expect preview message in Discord.
4. **Phase D — Reaction approval:**
   - Ship reaction handler behind `APPROVER_ONLY_MODE=true` safety flag (rejects all by default).
   - Manually test merge via reaction on a throwaway PR.
   - Flip flag on.
5. **Phase E — Shipped confirmation:**
   - Add merge-workflow notify step.
   - Verify "Shipped 🚀" lands in channel.

## Resolved decisions

1. **Tunnel: Cloudflare Tunnel.** Free, runs as a second NSSM daemon on the Windows box alongside discord-relay. No router config. Stable DNS via `relay.strawberry.<duong-domain>`.
2. **GitHub PAT: classic PAT with `repo` scope.** Strawberry is a single private monorepo with one user — fine-grained PAT's per-repo scoping buys nothing here. Classic is simpler to rotate and debug. Stored in `secrets/discord-relay.env` as `GITHUB_TOKEN`.
3. **Merge strategy: squash.** Cleanest history, and GitHub's squash merge concatenates the PR body into the commit message by default — the `strawberry-meta` block survives into `head_commit.message` for the merge workflow's `kind: shipped` notify step. Reaction handler calls `octokit.pulls.merge({ merge_method: 'squash' })`.
4. **`pending-prs.json` persistence:** `state/` alongside the discord-relay install dir, guarded by `proper-lockfile`.
5. **Repo scope: monorepo (`strawberry`) only.** `myapps` is the public apps collection *within* `strawberry`, not a separate repo. All PRs, Actions workflows, and GitHub secrets live in `strawberry`. No multi-repo plumbing needed — drop the per-label `reviewers.by_label` split and the "other repos join in Phase C iteration 2" rollout note. `notify-discord-preview.js` lives at `strawberry/.github/scripts/notify-discord-preview.js`.
6. **❌ reaction: close the PR.** Confirmed. `octokit.pulls.update({ state: 'closed' })`, reply "Closed PR #N.", remove from `pending-prs.json`. No separate "dismiss without closing" path.
7. **Discord message after merge: reply to the original.** discord-relay posts a new message in the same channel as a reply (Discord message reference) to the original suggestion message (`discord_message_id` from the meta block). No edit/strike-through on the original. Applies to both the preview notification and the "Shipped 🚀" confirmation — both use Discord's `message_reference` so they thread under the source suggestion.

## Non-goals

- Staging environment (deferred).
- Multiple approvers / role-based gates.
- Rollback via reaction.
- Preview URL screenshots / Playwright verification (see separate `agent-visible-frontend-testing` plan).
- Re-triage if Duong edits the original Discord message.
