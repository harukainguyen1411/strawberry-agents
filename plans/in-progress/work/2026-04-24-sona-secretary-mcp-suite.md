---
title: Sona secretary — MCP suite + morning brief
status: in-progress
concern: work
owner: swain
author: swain
created: 2026-04-24
kind: adr
tests_required: false
architecture_impact: workflow
---

## 0. Closed-PR scope correction (added 2026-04-25)

This plan was scope-corrected on 2026-04-25 after two consecutive PR closures stemming from the same architectural error:

- **PR #48 (closed)** — wrong codebase: changes landed in the personal-MCP directory, not the work-MCP path.
- **PR #33 (closed)** — wrong scope/repo: modified upstream company-shared MCP files inside `~/Documents/Work/mmp/workspace/mcps/`, which is a shared repo not under our control.

**Corrected architecture (non-negotiable for every remaining task in this plan):**

`~/Documents/Work/mmp/workspace/mcps/` is a **company-shared repo**. Other engineers and projects depend on those MCPs. They have no knowledge of strawberry-agents, age encryption, `tools/decrypt.sh`, or `STRAWBERRY_AGENTS` env vars. **WE DO NOT MODIFY THEIR FILES.** Anti-pattern (do not repeat): rewriting upstream `start.sh`, deleting upstream `.env` files, or adding strawberry-only setup steps to upstream MCPs.

**Correct shape:** OUR strawberry-agents repo holds wrapper launcher scripts. Each wrapper:
1. Locates our age-encrypted blob at `secrets/work/encrypted/<service>-<key>.age`.
2. Pipes ciphertext into `tools/decrypt.sh --target secrets/work/runtime/<service>.env --var <ENV_NAME> --exec --`.
3. The decrypt-exec then invokes the **unmodified company-shared MCP entrypoint** (e.g. `~/Documents/Work/mmp/workspace/mcps/slack/scripts/start.sh`) with our decrypted env populated.

The local `~/Documents/Work/mmp/workspace/.mcp.json` registers OUR wrapper at `~/Documents/Personal/strawberry-agents/mcps/wrappers/<service>-launcher.sh`. Other engineers register the upstream `start.sh` directly in their own `.mcp.json` — their flow is unchanged.

**Hard rule for executors:** if you find yourself opening any file under `~/Documents/Work/mmp/workspace/mcps/<service>/` for write, **stop**. The only file in the work workspace any task in this plan may modify is `~/Documents/Work/mmp/workspace/.mcp.json` (one-line registration change per service).

## 1. Context

Duong wants Sona (the work coordinator) to function as his Chief-of-Staff: live overlook of every information source he uses at MMP, and a synthesized daily brief delivered to Slack at 08:00 ICT. The current MCP surface is partial. The in-session state right now (verified by running `claude mcp list` from `/Users/duongntd99/Documents/Work/mmp/workspace/` at authoring time):

| System | Current state — verified 2026-04-24 | Gap |
|---|---|---|
| GitHub | `gh` CLI authed as `duongntd99` for work; `plugin:github` MCP present but "Failed to connect" | Confirm `gh` covers the secretary path; decide whether to resurrect the MCP or accept CLI-only |
| Slack (work) | `mcps/slack/` (FastMCP, `xoxp-` User OAuth, authed as `duong.nguyen.thai`) — Connected | No gap; the "broken slack" in the brief was the personal MCP at `~/Documents/Personal/strawberry-agents/mcps/slack/` — that one is Evelynn-scope and out of this ADR |
| Google Drive | `mcps/gdrive/` — Connected (Shared Drive fork) | Confirm scopes cover work drives Sona needs |
| Google Calendar | `mcps/gcalendar/` — Connected | Confirm write scope (create/update events) |
| Atlassian / Jira + Confluence | `mcps/mcp-atlassian/` — directory scaffolded, `.env` missing, not registered in `.mcp.json`, `uvx mcp-atlassian` ready | Provision credentials, register, smoke-test |
| HubSpot | Indirect via `mcp__mmp-fathom__hubspot_*` (6 tools: search, find_meeting, log_meeting, update_meeting, delete_meeting, get_associations) | Decide: is the Fathom passthrough enough, or do we want direct `mcp-hubspot`? |
| Asana | Not present | Add (pending OQ-1: is Asana actually used at MMP?) |
| LinkedIn | Not present | LinkedIn's public API forbids mention/DM scraping for third parties; scope realistically |
| Linear | Not present | Add (pending OQ-1) |
| Gmail | Not present | Add — community `@modelcontextprotocol/server-gmail` or `@gongrzhe/server-gmail-autoauth-mcp` |

Conversions that inform this ADR:

- `plans/implemented/personal/2026-04-24-custom-slack-mcp.md` established the **tool-name-encodes-intent** convention. The work-side Slack MCP already uses a similar verb-shape (`slack_list_channels`, `slack_send_dm`, `slack_search`) — no change needed for Phase 1.
- Per `CLAUDE.md` Rule 2 and `secrets/README.md`, plaintext tokens in `secrets/` are only for machines without decryption capability; reusable credentials live in `secrets/encrypted/*.age` with `tools/decrypt.sh`. Every new MCP in this ADR MUST use the encrypted path.
- Per `CLAUDE.md` Rule 10, `start.sh` files in MCP server dirs are already outside the portable-scripts zone (they target macOS + `uvx`/`node`), so no Windows parity is required.
- Per `agents/memory/agent-network.md`, `[concern: work]` is a prompt-level tag that subagents receive; MCP tool authorization is **not** currently gated by concern tag. The cross-concern firewall in §4 below is therefore a **process** firewall, not a hook firewall — see D5 for rationale on not building a new guard.

## 2. Decision

Build Sona's secretary surface as **one config file, ten MCP servers, one scheduled skill**. All servers live under `~/Documents/Work/mmp/workspace/mcps/`. All credentials under `secrets/work/encrypted/*.age` (new subdirectory — see D2) in the `strawberry-agents` repo, decrypted via `tools/decrypt.sh` at MCP start.

Keyed decisions, one per row:

| ID | Decision |
|---|---|
| D1 | The work-concern MCP set lives in `~/Documents/Work/mmp/workspace/.mcp.json` — not in `~/.claude.json` user-scope — so that Sona's surface activates only when she operates from the work workspace. Evelynn (running from `strawberry-agents`) never sees work-concern MCPs. This is the process-level firewall for §4. |
| D2 | Secrets for work-concern MCPs live under `secrets/work/encrypted/*.age` in `strawberry-agents` (new subdirectory, gitignored plaintext), decrypted via `tools/decrypt.sh`. One `.age` blob per credential. `start.sh` decrypts at MCP start, exports env to the child, never writes plaintext to disk. |
| D3 | Scheduler = **macOS `launchd`** at 08:00 Asia/Ho_Chi_Minh. Not cron (cron on macOS is deprecated and doesn't handle laptop sleep + wake cleanly). Not Claude Code `/loop` (requires an active session and is not a durable scheduler). The launchd agent spawns a **headless Claude Code subprocess** with a dedicated system prompt (`scripts/work/morning-brief.sh`), so the brief ships regardless of whether Duong has opened a session. See §3.2. |
| D4 | Synthesis = **staged**, not single-shot. One fan-out read call per source (parallel tool calls in one turn), one aggregation pass that writes the final brief. Rationale: single-shot context would balloon to ~100k tokens on a real day; staged lets each read stage scope itself and the aggregator only sees per-source bulleted summaries (~5k tokens). Cost ≈ same order of magnitude either way on Max plan; fidelity is measurably better staged. |
| D5 | Do **not** build a new `[concern: work]`-enforcing hook for MCP tool calls. The `.mcp.json` scope split (D1) already means Evelynn can't physically call work-concern MCPs from the `strawberry-agents` directory. Adding a second enforcement layer — runtime tool-name prefix check — costs real engineering against a threat that doesn't exist in the solo-dev model. If future cross-session tool-call leakage is observed, promote to a hook then. |
| D6 | Direct HubSpot MCP is Phase 3 (maybe-never). The six `mcp__mmp-fathom__hubspot_*` tools already cover the secretary-relevant CRM surface (meeting log, associations, search). Adding a second HubSpot plane is only justified if Phase 2's brief surfaces a concrete gap — deal-stage watches, ticket/pipeline events — that Fathom passthrough can't serve. |
| D7 | LinkedIn MCP is **deferred to Phase 4 with an explicit scope-narrowing note**. The official LinkedIn API forbids third-party tools from reading mentions, DMs, or feed content. Feasible read surface is limited to (a) Duong's own profile view metrics via LinkedIn Marketing API if he grants an app, (b) post-publication metrics on his own posts. The brief will have a "LinkedIn: not covered" line, not a flaky scraper. |
| D8 | Asana and Linear MCPs are **conditional on OQ-1** (which source of truth does MMP use?). If MMP uses only Jira, drop both; if only Linear, drop Asana; if mixed, add both. Default assumption until Duong answers: Jira-only (Atlassian MCP is already scaffolded — strongest signal of actual use). |
| D9 | Brief delivery = **Slack DM to `U03KDE6SS9J`** via `mcp__slack__slack_send_dm` (work-side MCP). Optional mirror to a Drive doc via `mcp__gdrive__create_document` into a `Sona Briefs/YYYY-MM-DD.md` location (OQ-3). Default on mirror = **yes** from Phase 2; Slack DMs roll off after ~90 days for Slack Free workspaces and the brief is cheap archaeology later. |
| D10 | Brief language = **English primary**, Vietnamese in quoted content only (e.g. if a Slack DM from a Vietnamese teammate is being summarized, quote verbatim; don't translate). This is a solo-user secretary, not a translator. (OQ-2.) |

## 3. Architecture

### 3.1 MCP inventory & target state

After this ADR lands, `~/Documents/Work/mmp/workspace/.mcp.json` contains these ten servers:

| # | Server name | Install | Auth | Scope | Phase |
|---|---|---|---|---|---|
| 1 | `slack` | `mcps/slack/` (FastMCP, already present) | `xoxp-` User OAuth in `.env` → migrate to `secrets/work/encrypted/slack-user-token.age` | Read channels/DMs/threads, list users, search, send DM, send message | Phase 1 (reconnect + secrets migrate) |
| 2 | `gdrive` | `mcps/gdrive/` (TS fork, already present) | `gcp-oauth.keys.json` + `.gdrive-server-credentials.json` → migrate to encrypted blobs | Read + create docs | Phase 1 |
| 3 | `gcalendar` | `mcps/gcalendar/` (already present) | OAuth refresh token in `.env` → encrypt | Read events, create/update/delete events | Phase 1 |
| 4 | `gmail` | New: `mcps/gmail/` via `@gongrzhe/server-gmail-autoauth-mcp` (community, well-maintained, the one that actually works on modern Gmail OAuth) | OAuth (reuse the Google refresh token already in `secrets/encrypted/google-refresh-token.age` if scopes align; else separate Google OAuth flow) | Read recent messages, search, send + draft replies | Phase 1 |
| 5 | `mcp-atlassian` | `mcps/mcp-atlassian/` (already scaffolded, not registered) | Atlassian API token (personal) + site URL in `.env` → encrypt | Read/write Jira issues, read/write Confluence pages | Phase 1 |
| 6 | `linear` | **New: `mcps/linear/`** via `@tacticlaunch/mcp-linear` or the official `linear-mcp-server` (compare at Phase 2); install only if OQ-1 confirms Linear is used | Linear API key (personal) → encrypt | Read issues/cycles/projects, create/update issues, comment | Phase 3 (conditional) |
| 7 | `asana` | **New: `mcps/asana/`** via `@roychri/mcp-server-asana`; install only if OQ-1 confirms | Asana Personal Access Token → encrypt | Read tasks/projects, create tasks, comment | Phase 3 (conditional) |
| 8 | `hubspot-direct` | **Deferred**: only add if Phase 2 brief surfaces an unmet CRM need that `mmp-fathom` can't serve | HubSpot Private App token | Read deals, contacts, pipelines | Phase 3 (contingent) |
| 9 | `github` (if resurrected) | Current: `plugin:github` HTTP MCP at `api.githubcopilot.com/mcp/` — currently "Failed to connect". Alternative: **drop the MCP, keep `gh` CLI** and have the brief skill shell out. | GitHub PAT (the `duongntd99` one — already available via `gh auth token`) | Read PRs/issues/reviews for `missmp/*` | Phase 1 (CLI path) / Phase 3 (MCP resurrect if Phase 2 proves CLI shell-out is too painful) |
| 10 | `mmp-fathom` | `mcps/mmp-fathom/` — already present | Fathom API + HubSpot Private App → verify encrypted | Meeting summaries, transcripts, HubSpot passthrough | Phase 1 (confirm scopes) |

Not installed (explicitly): LinkedIn MCP — see D7.

### 3.2 Morning-brief pipeline

Components:

```
launchd (08:00 ICT, UserAgent plist)
  │
  ▼
scripts/work/morning-brief.sh
  │
  ├── wait for network (max 5 min)
  ├── wake macOS if sleeping (caffeinate -u -t 5)
  ├── exec `claude-code --headless --system-prompt agents/sona/briefing-prompt.md \
  │             --concern work --skill-invoke briefing-v1`
  │
  ▼
Sona (headless) — skill `briefing-v1`
  │
  ├── Stage A (parallel, one tool call per source):
  │     mcp__slack__slack_list_channels(member_only=True)
  │     mcp__slack__slack_list_dms
  │     mcp__gcalendar__list_events(today..tomorrow+1d)
  │     mcp__gdrive__list_files(modifiedTime > yesterday_08)
  │     mcp__mcp-atlassian__jira_search(JQL: watcher=currentUser() or assignee=currentUser() updated>-1d)
  │     mcp__mmp-fathom__hubspot_search(recent_updated_deals, recent_meetings)
  │     gh pr list --state open --author @me --repo missmp/... (CLI fan-out)
  │     gmail search (is:unread newer_than:1d)
  │     grep strawberry-agents/plans/in-progress/work/ (decisions-needed scan)
  │
  ├── Stage B (per-source summary):
  │     For each non-empty source, one LLM call with the raw payload,
  │     producing a 200-500 token bulleted digest.
  │
  ├── Stage C (aggregate):
  │     Single LLM call: all digests + today's calendar + yesterday's
  │     open-threads delta → produce `brief.md` in the Chief-of-Staff
  │     sitrep format (§3.3).
  │
  └── Deliver:
        mcp__slack__slack_send_dm(user="U03KDE6SS9J", text=mrkdwn(brief))
        mcp__gdrive__create_document(title="Sona brief YYYY-MM-DD",
                                      content=brief,
                                      folder="Sona Briefs")
        write brief to agents/sona/briefs/YYYY-MM-DD.md (local archive)
```

**Failure handling:** each Stage-A call is wrapped with a per-source timeout of 60s. A source that times out or errors is replaced in the aggregate with a single line `*<source>: unavailable this morning (<error-class>)*`. The brief still ships. If more than three sources fail, the Slack DM header gets a `[DEGRADED — N/9 sources]` tag.

**Cost budget (rough):** Stage A = 0 LLM tokens (tool calls only). Stage B = 9 sources × ~2k input tokens × ~500 output tokens = ~22k in, ~5k out. Stage C = ~5k in, ~3k out. Total ≈ 30k input / 8k output per day = ~$0.50–$1/day on Opus 4.7 rates. Sustainable.

**Session lifecycle:** the headless session runs to completion and exits. No `/end-session` ritual (the skill writes a single memory shard `agents/sona/memory/last-sessions/brief-YYYY-MM-DD.md` before exit; no open-threads.md mutations — the brief is read-only for Sona's state). On next fresh Sona session, boot picks up the shard via INDEX.md.

### 3.3 Brief output format

Slack mrkdwn, one top-level message, threaded replies for overflow:

```
*Sona brief — YYYY-MM-DD (Thu) — 08:00 ICT*

*1. Next steps (top 3)*
• <item> — <why> — <owner>

*2. Today's calendar*
• HH:MM — <title> — <prep note if any>

*3. Tomorrow preview*
• HH:MM — <title>

*4. Slack*  <N new in M channels; top-priority threads>
• #channel: <thread gist + unresolved Q to you>

*5. Gmail*  <N unread overnight>
• <from> — <subject> — <1-line summary>

*6. Jira*  <N updates on your watched/assigned>
• <ISSUE-123> — <status change or new comment gist>

*7. CRM (Fathom/HubSpot)*
• <deal/meeting event>

*8. GitHub*  <N open PRs; N reviews pending>
• missmp/<repo>#<N> — <title> — <state>

*9. Plans needing decisions*
• plans/in-progress/work/<slug>.md — <OQ needing answer>

*10. Gaps / degraded sources*
• <source>: <reason>
```

A Drive doc mirror gets the same content as markdown (no mrkdwn-specific syntax; both formats accept `*bold*` + `-` lists).

## 4. Security and scope

### 4.1 Cross-concern firewall

**Rule:** Work-concern MCPs are reachable only from the work workspace directory (`~/Documents/Work/mmp/workspace/`). Evelynn, operating from `~/Documents/Personal/strawberry-agents/`, sees only personal-concern MCPs (the existing `mcps/` dir).

**Enforcement mechanism:** `.mcp.json` scope — Claude Code resolves `.mcp.json` from the CWD. Evelynn's sessions start in `strawberry-agents/`, Sona's in `mmp/workspace/`. No runtime hook required (D5).

**Trust boundary:** A subagent invoked by Evelynn that somehow `cd`s into the work workspace and opens a new `claude` subprocess would gain work-MCP access. This is theoretical — every subagent runs in the parent process with the parent's MCP surface. The concrete attack is "Evelynn calls a work-MCP tool from personal context," which requires the tool to be in scope, which requires the config to be loaded, which requires the CWD at parent-boot time to be `mmp/workspace/`. Evelynn never boots there.

### 4.2 Secret storage

All work MCP credentials encrypted at rest under `secrets/work/encrypted/*.age`:

```
secrets/work/encrypted/
├── slack-user-token.age
├── slack-bot-token.age               # if D6's notify_duong pattern carries over to work
├── gdrive-oauth-keys.age             # OAuth client JSON (not the user refresh token)
├── gdrive-server-credentials.age     # user refresh token
├── gcalendar-credentials.age
├── gmail-oauth.age                   # may reuse gdrive OAuth + extra scope
├── atlassian-api-token.age
├── atlassian-site-config.age         # URL + email, non-secret but bundled for lock-step rotation
├── linear-api-key.age                # if provisioned
├── asana-pat.age                     # if provisioned
├── hubspot-private-app-token.age     # if provisioned
└── github-pat-work.age               # Sona's path, separate from gh CLI's keychain
```

**SCOPE GUARDRAIL (critical, added 2026-04-25 after PR #48 + PR #33 closures).**
`~/Documents/Work/mmp/workspace/mcps/` is a **company-shared repo**. Other engineers and projects depend on it; nobody else there knows about strawberry-agents, age encryption, `tools/decrypt.sh`, or any strawberry-only env var. **WE DO NOT MODIFY UPSTREAM COMPANY MCP FILES.** Specifically: `mcps/<service>/scripts/start.sh`, `mcps/<service>/server.py`, `mcps/<service>/.env`, `mcps/<service>/pyproject.toml`, etc. inside `mmp/workspace/` are **READ-ONLY** for this ADR. Any task previously phrased as "rewrite `mcps/<service>/scripts/start.sh`" is wrong and was the scope error that closed PR #48 (wrong codebase) and PR #33 (wrong scope/repo). **Do not repeat.**

The correct shape is **wrap, don't modify**: OUR strawberry-agents repo holds wrapper launcher scripts that decrypt our age-encrypted blobs and `exec` the company-shared MCP entrypoint with the credentials populated in the child process env. Other engineers continue to register the company `start.sh` directly in their own `.mcp.json`; OUR `.mcp.json` registers OUR wrapper. Two non-overlapping consumption paths over one unmodified upstream.

**Wrapper location and naming (decision, this ADR):**
- Wrappers live at `mcps/wrappers/<service>-launcher.sh` inside `strawberry-agents` (sibling to the existing `mcps/` personal-MCP directory). Justification: strawberry-agents-scoped (so the encryption chokepoint stays local), sibling to `mcps/` (clear semantic — `mcps/wrappers/` = "wrappers around external MCPs we do not own"), and not under `scripts/` (these are MCP entrypoints registered in `.mcp.json`, not internal tooling).
- One file per wrapped service. POSIX-portable bash per Rule 10.

Each wrapper follows this canonical template (uses `tools/decrypt.sh --exec`, which NEVER emits plaintext to stdout):

```bash
#!/usr/bin/env bash
# mcps/wrappers/<service>-launcher.sh
# Wraps the unmodified company-shared MCP at ~/Documents/Work/mmp/workspace/mcps/<service>/.
# Decrypts our age blob and execs upstream's start.sh with credentials in env.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UPSTREAM_START="${UPSTREAM_START:-$HOME/Documents/Work/mmp/workspace/mcps/<service>/scripts/start.sh}"
cd "$REPO_ROOT"
exec ./tools/decrypt.sh \
  --target "secrets/work/runtime/<service>.env" \
  --var    "<UPSTREAM_ENV_NAME>" \
  --exec -- "$UPSTREAM_START"  < "secrets/work/encrypted/<service>-<key>.age"
```

How this pattern works:
- Ciphertext arrives on stdin via `< secrets/work/encrypted/<service>-<key>.age`; plaintext never touches argv or parent-shell memory past the `age -d` call inside `tools/decrypt.sh`.
- `--target secrets/work/runtime/<service>.env` writes a sibling runtime env-file (gitignored under `secrets/`) — this is required by the tool's current interface, which always materializes a target path. The runtime-dir path is ephemeral but on disk; wrappers may add a trap-cleanup if stricter residency is required.
- `--exec -- "$UPSTREAM_START"` replaces the shell with the **unmodified company-shared MCP entrypoint**; the env var (named by `--var`) lives in the child-process env only and is never echoed to stdout, logged, or captured by `$(...)`.
- The upstream `start.sh` typically does `set -a; source .env; set +a` then `exec ... server.py`. When our wrapper has already injected `<UPSTREAM_ENV_NAME>` into env, the upstream's `.env` source is harmless (either the file is empty/absent, or its values get overlaid — but they shouldn't conflict because the upstream `.env` is the company-engineer fallback path, not in use on our laptop). The upstream MCP server reads the env var as it always does.

**Plaintext `.env` files inside the upstream company-shared MCP dirs are NEVER touched by us.** Other engineers manage those. Our wrapper provides credentials via env, taking precedence; if a stale `.env` happens to exist locally on Duong's machine inside `mmp/workspace/mcps/<service>/`, it does not enter our threat model — we're not committing to that repo. Rule 6 enforcement applies to OUR ciphertext + OUR wrappers; the upstream `.env` story is unchanged for the company.

#### Multi-secret inventory (T-new-B — 2026-04-24)

Read-only survey of each Phase-1 MCP's `.env` (or `start.sh` if no `.env`). Only
secret/auth credential names are enumerated — no values read into context.

| MCP | credential name(s) | secret count | classification | T-new-C gate? |
|---|---|---|---|---|
| `slack` | `SLACK_USER_TOKEN` (`xoxp-` user OAuth) | 1 | **single** | No — can migrate immediately after T-new-D |
| `gdrive` | `gcp-oauth.keys.json` (OAuth client: `client_id` / `client_secret`) + `.gdrive-server-credentials.json` (user refresh token) | 2 credential files | **multi** | Yes — T-new-C must land before T7a/T7b/T8 |
| `gcalendar` | `gcp-oauth.keys.json` (OAuth client) + `.gcalendar-credentials.json` (user refresh token) — same structure as gdrive; may share the same GCP OAuth client (OQ-P1-5 still open) | 2 credential files | **multi** | Yes — T-new-C must land before T9 |
| `mmp-fathom` | `FATHOM_API_KEY` + `HUBSPOT_USER_TOKEN` + `SLACK_WEBHOOK_URL` | 3 | **multi** | Yes — T-new-C must land before T4 |
| `postgres` | `DB_DEV_TSE_URL` + `DB_DEV_EMAIL_URL` + `DB_DEV_MAILROUTER_URL` + `DB_PRD_TSE_URL` + `DB_PRD_EMAIL_URL` + `DB_PRD_MAILROUTER_URL` | 6 | **multi** | Yes — T-new-C must land before T5 |
| `wallet-studio` | `WALLET_STUDIO_API_KEY` + `WALLET_STUDIO_TOKEN` + `MCP_AUTH_TOKEN` (+ `WALLET_STUDIO_BASE_URL` which is a config URL, not a secret) | 3 auth credentials | **multi** | Yes — T-new-C must land before T6 |
| `mcp-atlassian` | `CONFLUENCE_TOKEN` + `JIRA_TOKEN` (+ `CONFLUENCE_URL`, `CONFLUENCE_USERNAME`, `JIRA_URL`, `JIRA_USERNAME` which are config, not secrets) | 2 auth tokens | **multi** | Yes — T-new-C must land before T10/T11 |
| `gmail` | `gmail-oauth.age` (single OAuth refresh token — separate Google OAuth flow required) | 1 | **single** | No — can migrate on canonical pattern after T14-Duong |

**Slack decision: single token.** The work-side Slack MCP (`mcps/slack/server.py`) consumes
`SLACK_USER_TOKEN` only. `SLACK_DEFAULT_USER` in `.env` is a user-ID config value (not a
credential). `SLACK_WEBHOOK_URL` appears in `.env` but is NOT consumed by the Slack MCP
server — it is present as residual config. Slack migration (P1-T2) proceeds immediately
after T-new-D on the canonical single-`--var` pattern. **T-new-C is NOT blocking for Slack.**

**T-new-C scope:** T-new-C is blocking for gdrive, gcalendar, fathom, postgres,
wallet-studio, and mcp-atlassian — six of the eight Phase-1 MCPs. Only `slack` and `gmail`
can migrate without T-new-C.

#### Multi-secret MCPs — known Phase-1 residual

`tools/decrypt.sh` currently accepts exactly ONE `--var` / `--target` pair per invocation. MCPs that require multiple secrets (Slack, if both bot and user tokens are in play; potentially others surfaced by T-new-B) cannot use the canonical `--exec` pattern as-is — a single `start.sh` can't chain two `exec` calls to install two env vars into the same child process.

Until `tools/decrypt.sh` gains a multi-var mode (see T-new-C below — repeatable `--var/--target` pairs, or an `--env-file` source mode that reads an age-encrypted blob containing multiple `KEY=value` lines), **multi-secret MCPs stay on their existing plaintext-`.env` pattern as a known Phase-1 residual**. They are listed in the migration tracker but gated on T-new-C landing. This is the one scope carve-out in Phase 1; all single-secret MCPs migrate on the canonical pattern immediately.

### 4.3 Data residency

Duong's work data (Slack DMs, Jira tickets, emails, CRM records, meeting transcripts) enters the Claude API context during brief synthesis. Acceptable — MMP is a Claude customer, Duong is the user, the data is Duong's to pass. No legal new ground. **Redaction rule:** the brief itself (which is Slack-persistent and Drive-persistent) does NOT embed raw PII from CRM records. Names, companies, and deal values are fine; contact emails, phone numbers, and attachments are not. The Stage B per-source prompt will include a `[redact: emails, phone numbers]` instruction.

### 4.4 Scope revocation

Each credential's revocation path is documented in `secrets/work/REVOCATION.md` (new file, Phase 1):

| Credential | Revocation path |
|---|---|
| Slack user token | Slack admin → OAuth tokens → Revoke |
| Gmail OAuth | myaccount.google.com → Security → Third-party access |
| Gcalendar/Gdrive OAuth | Same as Gmail |
| Atlassian API token | id.atlassian.com → API tokens → Revoke |
| Linear API key | Linear settings → API → Revoke key |
| Asana PAT | Asana settings → Apps → Revoke |
| HubSpot Private App | HubSpot settings → Integrations → Private Apps → Revoke |
| GitHub PAT | github.com/settings/tokens |

Rotation cadence: annually for long-lived tokens, immediately on suspicion. No automatic rotation in scope for this ADR.

## 5. Phased rollout

| Phase | Scope | Success criterion |
|---|---|---|
| **Phase 0** | Inventory sweep (commit this ADR) + reconnect status audit: run `claude mcp list` from `mmp/workspace/`, confirm the six existing MCPs are connected. | `claude mcp list` shows 6/6 connected; Slack MCP answers a `slack_list_channels` probe. |
| **Phase 1** | Migrate existing MCP secrets from `.env` plaintext to `secrets/work/encrypted/*.age` (Slack, Gdrive, Gcalendar, Fathom, Postgres, Wallet-Studio). Add two new MCPs: **Atlassian** (already scaffolded — register + provision) and **Gmail** (new install). | `claude mcp list` shows 8/8 connected; ad-hoc manual queries to each new tool succeed. |
| **Phase 2** | Morning-brief MVP: launchd plist + `scripts/work/morning-brief.sh` + `agents/sona/skills/briefing-v1/`. Brief covers Slack + Calendar + Gmail + Jira + Fathom + GitHub (CLI path) + plans-needing-decisions. Skip: Linear, Asana, HubSpot-direct, LinkedIn. | Brief lands in Duong's Slack DMs at 08:00 ICT for 5 consecutive weekdays with no degradation tags on > 1 source per run. |
| **Phase 3** | Conditional MCPs based on OQ-1 answer: Linear and/or Asana. Optional: HubSpot-direct if Phase 2 surfaced a Fathom-passthrough gap. Optional: GitHub MCP resurrect if Phase 2 CLI shell-out proved painful. | Brief coverage increases to match answered OQ-1; no regression in existing 7 sources. |
| **Phase 4** | Secretary writeback: promote Sona from read-mostly to action-capable. `mcp__gcalendar__create_event` for "book this meeting," `mcp__gmail__create_draft` for reply drafts, `mcp__mcp-atlassian__jira_create_issue` for ticket creation. Gated by a per-action `confirm:` boolean in tool args so Sona never fires a writeback tool without explicit user confirmation in the same turn. LinkedIn stays out per D7. | Sona can draft and await approval for three action types end-to-end without Duong leaving the Slack conversation. |

Each phase has a single plan that Aphelios breaks down. This ADR does not pre-author those plans.

## 6. Alternatives considered

**Alt A — Glean / Gemini for Workspace / Copilot as the aggregator.** Rejected: (a) adds a third-party surface to trust with MMP data that Anthropic doesn't already see, (b) loses the long tail of MCPs Sona needs for secretary-style actions (writeback to Jira, Drive doc creation), (c) costs per-seat licensing that the DIY path avoids. Reconsider only if DIY brief quality plateaus.

**Alt B — Zapier or n8n as the glue.** Rejected: (a) a second runtime to keep alive, (b) the brief's value is in LLM-level synthesis, which Zapier can't do natively — it would still call out to Claude — so Zapier adds a hop without adding capability, (c) credential sprawl across a second plane. n8n self-hosted is slightly better (local) but same logic applies.

**Alt C — Reduced-scope v1: Slack + Calendar + Gmail only.** Considered. Cost of cutting Jira + Fathom-passthrough + GitHub from Phase 2 is that the first week's briefs read as "inbox summary" not "Chief of Staff." The Jira and GitHub queries are the single highest signal for "what's blocking whom" — the whole point of the sitrep. Kept them in Phase 2. Linear/Asana/HubSpot-direct stay out because they're conditional and the day-1 value proposition doesn't require them.

**Alt D — Do the brief inside Duong's live Sona session instead of headless launchd.** Rejected: 08:00 ICT is before Duong's typical workday start in Vietnam, and on days he's traveling the brief wouldn't fire. Decoupling brief production from session lifecycle (D3) is the whole point.

**Alt E — Single-shot synthesis (one LLM call with every source in context).** Rejected per D4 — context bloat + per-call fidelity loss. Staged wins on cost and quality.

## 7. Consequences

**Positive.**
- Sona gains live overlook of 7–10 systems through a consistent tool surface.
- Brief delivery is session-independent (launchd + headless).
- Cross-concern firewall is structural (CWD-scoped `.mcp.json`) not procedural — Evelynn can't accidentally call a work MCP.
- Secret storage is uniform across all MCPs (encrypted `.age` blobs, one pattern).

**Negative.**
- Ten MCPs means ten auth flows, ten revocation paths, ten potential outages. The brief's failure-handling absorbs this but operationally it's a maintenance surface.
- Morning-brief headless runs are a new "agent acting without a human in the loop" mode. Writeback (Phase 4) has to be gated hard.
- launchd plist is macOS-only. If Duong ever moves to the Windows laptop primarily, the scheduler rehomes (not in scope — per task brief, work concern is macOS-only for this skill).
- Cost floor is ~$0.50–$1/day for the brief alone. Not a ceiling concern on Max plan but worth tracking if Phase 4 multiplies calls.

**Neutral.**
- The ADR locks in the "two `.mcp.json`s, one per concern, CWD-scoped" pattern for the long term. Any future cross-concern shared tool (hypothetical) would need its own resolution path.

## 8. Open questions

| ID | Question | Bearing |
|---|---|---|
| OQ-1 | Of {Jira, Asana, Linear}, which does MMP actually use as source of truth for work items? **Recommend: answer trims Phase 3 from three MCPs to one.** | Phase 3 scope |
| OQ-2 | Brief language — English primary with Vietnamese quoted verbatim (D10 default), or full bilingual? | §3.3 prompt design |
| OQ-3 | Drive-doc mirror: yes (D9 default, daily archive in `Sona Briefs/`) or Slack-only? | §3.2 delivery |
| OQ-4 | GitHub MCP vs `gh` CLI shell-out: the MCP is currently broken. **Recommend: keep it dead, use CLI for Phase 2, revisit only if shell-out is painful.** | §3.1 row 9 |
| OQ-5 | Commercial MCPs: the landscape has paid options (e.g. HubSpot Enterprise plugins). Budget ceiling for this suite? **Recommend: $0/month — every MCP in the target state is free / self-hosted / included with existing MMP seats.** | Phase 3 / Phase 4 |
| OQ-6 | Brief time: 08:00 ICT default (D3). Is that before or after Duong's preferred start? Shift by ±1h is trivial. | §3.2 scheduler |
| OQ-7 | Phase 4 writeback confirmation model: per-turn `confirm: true` arg (current D), or out-of-band Slack-reaction approval (thumbs up on a proposed draft)? | Phase 4 design |
| OQ-8 | Should Fathom-passthrough stay the HubSpot path (D6), or is there a concrete secretary-path need that justifies direct HubSpot in Phase 2? | D6 / Phase 2 scope |

## 9. Implementation handoff

On Duong's approval of §2 decisions and §8 open questions:

1. Orianna promotes `plans/proposed/work/2026-04-24-sona-secretary-mcp-suite.md` → `plans/approved/work/`.
2. Aphelios breaks the approved ADR into Phase-1 tasks (secrets migration + Atlassian register + Gmail install). Aphelios also authors a separate breakdown plan for Phase 2 (launchd + briefing-v1 skill) deferred until Phase 1 is clean.
3. Ekko executes Phase-1 wiring (start.sh migrations, `.mcp.json` edits, encrypted blob creation from existing `.env` sources).
4. Syndra authors the `briefing-v1` skill under `agents/sona/skills/briefing-v1/` using the patterns in `plans/implemented/personal/2026-04-24-custom-slack-mcp.md` §2 for tool-name intent-encoding.
5. Duong provisions Gmail OAuth (requires his Google account login) — the only step an agent can't do.
6. Phase 1 ships and operates for 1 week before Phase 2 lands.

No self-implementation in this ADR. `owner: swain` is authorship; Evelynn assigns implementers.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** ADR has clear owner (swain), concrete decisions D1-D10 with stated rationales, and a phased rollout with measurable success criteria per phase. All 8 open questions have been resolved by Sona under Duong's delegated hands-off authority (OQ-1 deferred to Phase 3; OQ-2 through OQ-8 accept the ADR defaults). Phase 1 scope is actionable and ready for Aphelios breakdown. `tests_required: false` is appropriate — this is a workflow ADR, not production code.

## Tasks — Phase 1

**Scope.** Migrate the six existing MCPs (`slack`, `gdrive`, `gcalendar`, `mmp-fathom`, `postgres`, `wallet-studio`) from `.env` plaintext to `secrets/work/encrypted/*.age`; register `mcp-atlassian` (scaffolded, not wired); install a new `gmail` MCP. Phase 1 success = `claude mcp list` from `~/Documents/Work/mmp/workspace/` shows 8/8 connected.

**Executor tiers in use.** Ekko (DevOps execution — start.sh edits, `.age` blob creation, `.mcp.json` edits, OAuth wiring). Syndra (MCP connection config — `claude mcp list` verification, smoke probes). Heimerdinger (advisory only — consulted during P1-T0 on the `tools/decrypt.sh` integration pattern; does not execute). Duong-in-the-loop (Gmail OAuth authorization — only Duong can sign into his Google account).

**Direct-to-main vs PR.** Rule 4 applies: plan edits direct-to-main, code/config edits via PR. Phase 1 groups into **4 PRs** (one prep PR, one secrets-migration PR per credential family — Google family is batched because the OAuth blobs cross gdrive/gcalendar/gmail — one Atlassian registration PR, one Gmail install PR). Rationale: a single mega-PR would mix six independent rotation-blast-radii; four small PRs are each independently revertable and reviewable.

**PR grouping.**

- **PR-A** (prep): `tools/decrypt.sh` integration-pattern decision + one-off reusable start.sh helper if P1-T0 lands one. Direct-to-main-eligible if no code change results; otherwise PR.
- **PR-B** (singleton secrets): Slack + Fathom + Postgres + Wallet-Studio `.env` → `.age` migration. Four independent credentials, one PR because each is a small (~5 line) start.sh edit + one encrypted blob + `.env` deletion.
- **PR-C** (Google family): gdrive + gcalendar credential encryption. Gmail install is a separate PR (PR-D) because it's net-new scaffolding plus a Duong-in-the-loop OAuth step that could stall the Google-family PR.
- **PR-D** (Atlassian register): `.env` provisioning (encrypted), `.mcp.json` registration, smoke test.
- **PR-E** (Gmail install): new `mcps/gmail/` scaffold, OAuth (Duong-authorized), `.mcp.json` registration, smoke test.

**Critical path.** P1-T0 → P1-T1 → (PR-B tasks in parallel) + (PR-C tasks sequentially: T7a → T7b → T8) + (PR-D: T9 → T10 → T11) + (PR-E: T12 → **T13-Duong** → T14 → T15) → **P1-T16** (final `claude mcp list` 8/8 verification). The gating serial legs are Google-family (OAuth reflows are finicky) and Gmail (T13 requires Duong). All PR-B tasks are parallelizable after T0/T1 land.

### Task list

#### OQ-P1-4 resolution tasks (inserted 2026-04-24 per Heimerdinger's advisory)

These tasks supersede the original P1-T0 "decide pattern" step. The pattern is ratified (`tools/decrypt.sh --exec`) and §4.2 is rewritten. What remains is inventory (T-new-B), the conditional multi-var extension (T-new-C), the reference start.sh (T-new-D), and a positive test (T-new-E). Secret-migration tasks (P1-T2…P1-T16) now blockedBy T-new-D rather than P1-T0 for single-secret MCPs; multi-secret MCPs additionally blockedBy T-new-C.

- [x] **T-new-A** — Rewrite ADR §4.2 to specify `--exec` as the canonical pattern, add the "Multi-secret MCPs" subsection documenting the known Phase-1 residual, and mark OQ-P1-4 RESOLVED. estimate_minutes: 30. Files: `plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md` (§4.2 + OQ table). DoD: §4.2 template is self-contained and reads cleanly on its own (no external advisory doc required); explanatory paragraph under the template covers stdin, `--target`, and `--exec` semantics; multi-secret carve-out documented; OQ-P1-4 row says RESOLVED. Owner: Aphelios (done in this commit). Direct-to-main (plan edit, Rule 4). Blocks: T-new-B, T-new-C, T-new-D, T-new-E. Status: DONE in the commit that introduces this section.

- [x] **T-new-B** — Inventory secretary MCPs for multi-secret needs. Read-only survey of each MCP in the Phase-1 scope (Slack, Gdrive, Gcalendar, Gmail, Atlassian, Fathom, Postgres, Wallet-Studio) to identify how many distinct secrets each requires at runtime. Output is a bullet list amended into the plan under a new "§4.2 multi-secret inventory" subsection OR a row added to the Phase-1 tasks table noting `single` / `multi` per MCP. Specifically confirm whether Slack uses one token (user `xoxp-`) or two (user + bot `xoxb-`). estimate_minutes: 15. Files: `plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md` (inventory subsection or table column). DoD: every Phase-1 MCP tagged single-secret or multi-secret with the credential names enumerated; if any multi-secret MCP is found, T-new-C is explicitly flagged blocking for that MCP's migration task. Owner: Ekko (read-only survey). Direct-to-main (plan edit). BlockedBy: T-new-A. Blocks: T-new-C (gate: only runs if >1 multi-secret MCP found), all multi-secret migration tasks.

- [ ] **T-new-C** (conditional on T-new-B outcome) — Extend `tools/decrypt.sh` with multi-var mode. Two candidate designs: (a) repeatable `--var` / `--target` pairs (same call decrypts multiple blobs, all env vars injected into the one `--exec` child); (b) `--env-file` source mode reading an age-encrypted blob containing multiple `KEY=value` lines. Syndra picks the design after reading the tool's current implementation, writes the extension, and Heimerdinger does a threat-model review focused on: (i) does plaintext leak to argv / env of sibling processes during the decrypt phase; (ii) does the new code path preserve the single-`exec` guarantee (never `$(...)`-capture). estimate_minutes: 60. Files: `tools/decrypt.sh`, `tools/tests/decrypt-multi-var.bats` or equivalent. DoD: either design works end-to-end with a fixture `.age` blob; threat-model review committed as a note in the commit body or a linked journal entry; no regressions in existing single-var callers. Owner: Syndra (code + test), Heimerdinger (threat-model review). PR (code change, not plan). BlockedBy: T-new-B (gate: only execute if T-new-B surfaces >1 secret for at least one MCP). Blocks: multi-secret MCP migration tasks (specifically P1-T3 if Slack has two tokens, plus any others flagged by T-new-B).

- [ ] **T-new-D (REVISED 2026-04-25, scope-corrected)** — Author the canonical wrapper launcher in **OUR strawberry-agents repo**, wrapping the **unmodified company-shared Slack MCP**. This is a wrapper, NOT a rewrite of `~/Documents/Work/mmp/workspace/mcps/slack/scripts/start.sh`. Slack chosen as reference because it is single-secret (`SLACK_USER_TOKEN`) and has no multi-var dependency on T-new-C. Wrapper lives at `mcps/wrappers/slack-launcher.sh` (path decision per §4.2). Implements exactly the §4.2 canonical template: locates `secrets/work/encrypted/slack-user-token.age`, redirects ciphertext on stdin into `tools/decrypt.sh --target secrets/work/runtime/slack.env --var SLACK_USER_TOKEN --exec --`, then exec's the unmodified company-shared `mcps/slack/scripts/start.sh` (resolved via `$UPSTREAM_START` env var with a default of `$HOME/Documents/Work/mmp/workspace/mcps/slack/scripts/start.sh`). Copy-pasteable template for subsequent wrapper tasks. **Hard scope guardrails:** (i) NO files under `~/Documents/Work/mmp/workspace/mcps/` may be modified, created, or deleted by this task; (ii) NO commits land in the upstream company-shared repo; (iii) the local `.mcp.json` change in P1-T2 will register OUR wrapper, not upstream's `start.sh`. estimate_minutes: 45. Files (all in strawberry-agents): `mcps/wrappers/slack-launcher.sh` (new, executable), `mcps/wrappers/.gitkeep` if first file, `secrets/work/runtime/.gitkeep`, `secrets/.gitignore` confirmation that `secrets/work/runtime/` is ignored. DoD: (a) `mcps/wrappers/slack-launcher.sh` exists and is executable, (b) script runs `shellcheck` clean, (c) wrapper is POSIX-portable bash per Rule 10, (d) explicit comment in wrapper header noting "wraps unmodified upstream — DO NOT modify the company-shared MCP," (e) the actual end-to-end smoke (T-new-D-smoke below) passes — wrapper exec's a probe that confirms `SLACK_USER_TOKEN` is in the child env. (f) NO files outside strawberry-agents have changed (verify with `git -C ~/Documents/Work/mmp/workspace status` showing clean). Owner: Talon. PR (code change in strawberry-agents only). BlockedBy: T-new-A, P1-T1 (for `secrets/work/encrypted/slack-user-token.age` — note: T-new-D can land the wrapper script with the blob provisioned later; smoke test gates on blob existence). Blocks: all per-MCP wrapper tasks (P1-T2, P1-T4..P1-T12).

- [ ] **T-new-D-smoke** — End-to-end smoke test for the Slack wrapper (co-lands with T-new-D in same PR; must pass before merge). NOT a grep-only check — earlier reviewer feedback explicitly called out grep-only smokes as insufficient. The smoke must actually `exec` the wrapper end-to-end. Implementation shape: `scripts/tests/wrapper-slack-launcher.bats` (or `.sh`) creates a fixture age blob (encrypted against `secrets/age-key.txt` or a throwaway in-test key) containing a known sentinel value `__SLACK_TEST_TOKEN__`, sets `UPSTREAM_START=/tmp/probe-upstream.sh` where probe is a script that asserts `[ "$SLACK_USER_TOKEN" = "__SLACK_TEST_TOKEN__" ]` and writes a marker file then exits 0, then invokes `mcps/wrappers/slack-launcher.sh`. Asserts: (i) wrapper exits 0; (ii) marker file written by probe (proving the env var was injected and the upstream entrypoint was exec'd); (iii) `secrets/work/runtime/slack.env` exists and is mode 0600 or absent post-cleanup; (iv) parent-process `env` does NOT contain `__SLACK_TEST_TOKEN__` (plaintext residency check). estimate_minutes: 45. Files: `scripts/tests/wrapper-slack-launcher.bats`, `tests/fixtures/wrapper/slack-fixture.age` + key fixture or in-test generator, `scripts/tests/probe-upstream-slack.sh`. DoD: test passes locally; test wired into the pre-commit hook test lane for changes under `mcps/wrappers/` and `tools/decrypt.sh`. Owner: Talon. PR (same PR as T-new-D). BlockedBy: T-new-D wrapper file existing.

- [ ] **T-new-D-xfail** — TDD xfail-first per Rule 12. **Must commit before T-new-D / T-new-D-smoke implementations.** Land a failing version of `scripts/tests/wrapper-slack-launcher.bats` that references `mcps/wrappers/slack-launcher.sh` (which does not yet exist) and is marked xfail / skip-with-todo, with a commit message including `Plan: 2026-04-24-sona-secretary-mcp-suite.md / T-new-D`. Pre-push TDD gate satisfied. estimate_minutes: 15. Files: `scripts/tests/wrapper-slack-launcher.bats` (xfail stub). Owner: Talon. PR (same branch as T-new-D, earlier commit). BlockedBy: T-new-A.

- [ ] **T-new-E** — Add a positive test under `scripts/tests/` exercising `tools/decrypt.sh --exec` with a fixture `.age` blob. The test creates a known-plaintext blob (age-encrypted against the repo's age key in a fixture subdir, or a throwaway key generated in-test), invokes `tools/decrypt.sh --target /tmp/fixture.env --var FIXTURE_TOKEN --exec -- /bin/sh -c 'test "$FIXTURE_TOKEN" = "expected"'`, and asserts exit 0. Also asserts: (i) `/tmp/fixture.env` is cleaned up or writable-only-by-owner; (ii) no plaintext appears in any parent-process log. estimate_minutes: 45. Files: `scripts/tests/decrypt-exec.bats` (or `.sh` if bats isn't in use), `tests/fixtures/decrypt/fixture.age` + fixture key or generator. DoD: test passes locally on macOS; test is wired into the pre-commit hook's test lane for `tools/` changes so future refactors of `tools/decrypt.sh` can't silently break the `--exec` contract. Owner: Syndra. PR (code change). BlockedBy: T-new-A. Runs in parallel with T-new-D.

#### Per-MCP wrapper migration tasks (REVISED 2026-04-25 — wrapper shape)

**Universal scope rule for every P1-T2..P1-T16 task below:**
- Wrappers go in `mcps/wrappers/<service>-launcher.sh` inside strawberry-agents. NOT in upstream.
- Age blobs go in `secrets/work/encrypted/<service>-<key>.age` inside strawberry-agents.
- `~/Documents/Work/mmp/workspace/.mcp.json` is updated to point at our wrapper. This is a single-line config change in the work workspace and is the ONLY file we touch outside strawberry-agents.
- Files under `~/Documents/Work/mmp/workspace/mcps/<service>/` are **READ-ONLY** for every task in this plan. No edits, no deletes, no `.env` migrations in upstream — leave it alone.
- Where a previous task description said "rewrite `mcps/<service>/scripts/start.sh`" or "delete `mcps/<service>/.env`," interpret as: "author `mcps/wrappers/<service>-launcher.sh` and update local `.mcp.json` to reference it; do not touch upstream files."
- For multi-secret MCPs (gdrive, gcalendar, fathom, postgres, wallet-studio, mcp-atlassian per §4.2 inventory), the wrapper depends on T-new-C delivering multi-var support to `tools/decrypt.sh`. Single-secret MCPs (slack, gmail) ship on the canonical single-`--var` pattern.

**Closed-PR callout — read before execution.** PR #48 (closed: wrong codebase — wrote into the personal MCPs dir) and PR #33 (closed: wrong scope/repo — modified upstream company-shared files). Both repeated the same scope error. The wrapper-shape pattern in this plan is the corrective architecture and is **not negotiable**. If you find yourself opening a file under `~/Documents/Work/mmp/workspace/mcps/<service>/` for write, **STOP** — that is the failure mode.

#### Original Phase-1 tasks (P1-T0 partially superseded — see above; T2..T16 reinterpreted per the wrapper rule above)

- [ ] **P1-T0** — Decide decrypt integration pattern. The ADR §4.2 template uses `TOKEN="$(tools/decrypt.sh ...)"` (stdout capture), but the current `tools/decrypt.sh` refuses to echo plaintext to stdout — it writes to a `secrets/<group>.env` file or execs a child with env injected via `--exec`. Heimerdinger + Ekko reconcile: either (a) adopt the `--exec` pattern in every `start.sh` (cleanest, no plaintext ever touches disk past the age-armored blob — preferred), or (b) add a narrow stdout-capable mode to `tools/decrypt.sh` gated by a flag. Amend §4.2 of the ADR inline with the chosen pattern before any migration task runs. estimate_minutes: 45. Files: `plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md` (§4.2 amendment), possibly `tools/decrypt.sh`. DoD: §4.2 template updated to reflect the sanctioned pattern; one reference start.sh (Slack, chosen because it's smallest) rewritten to demonstrate; Heimerdinger signs off in the plan commit trailer or a journal note. Owner: Heimerdinger (advise) + Ekko (execute). Direct-to-main for the plan amendment; PR-A for any `tools/decrypt.sh` change. Blocks: all secret-migration tasks.

- [ ] **P1-T1** — Create `secrets/work/encrypted/` subdirectory structure and `secrets/work/REVOCATION.md` stub per §4.4. No encrypted blobs yet, just the directory and the revocation doc with a placeholder row per credential that later tasks will fill in. estimate_minutes: 20. Files: `secrets/work/encrypted/.gitkeep`, `secrets/work/REVOCATION.md`. DoD: directory exists, `REVOCATION.md` has the §4.4 table skeleton committed. Owner: Ekko. PR: can ride with PR-A or be its own direct-to-main plan-adjacent commit (it's a new doc, no `apps/**` or `mcps/**` touched — `chore:` prefix). Blocks: all secret-migration tasks (T2-T8, T10, T14).

- [ ] **P1-T2 (REVISED — wrapper shape)** — Wire the Slack wrapper end-to-end against the real Slack token. Provision the age blob: read `SLACK_USER_TOKEN` from the upstream `~/Documents/Work/mmp/workspace/mcps/slack/.env` value (DO NOT modify or delete that file — read-only), age-encrypt into `secrets/work/encrypted/slack-user-token.age`. Update `~/Documents/Work/mmp/workspace/.mcp.json` so the `slack` server's command points to **OUR wrapper** at `~/Documents/Personal/strawberry-agents/mcps/wrappers/slack-launcher.sh`, replacing the previous direct `mcps/slack/scripts/start.sh` reference. Verify with `claude mcp list` from the work workspace CWD. The upstream `mcps/slack/.env` may remain on disk untouched (it is the company-engineer fallback and not in our scope to delete). estimate_minutes: 30. Files (strawberry-agents): `secrets/work/encrypted/slack-user-token.age`, `secrets/work/REVOCATION.md`. Files (work workspace, config-only): `~/Documents/Work/mmp/workspace/.mcp.json`. **Files NOT touched:** any file under `~/Documents/Work/mmp/workspace/mcps/slack/`. DoD: blob exists; `.mcp.json` points to our wrapper; `claude mcp list` shows slack Connected; `slack_list_channels` probe returns > 0 channels; `git -C ~/Documents/Work/mmp/workspace status` shows only `.mcp.json` modified. Owner: Talon. PR (strawberry-agents) + a separate small commit to the work workspace `.mcp.json` (config-only). BlockedBy: T-new-D, T-new-D-smoke, P1-T1.

- [ ] **P1-T3** — Migrate Slack bot token (if present in `.env`). `cat mcps/slack/.env` at T2 time will reveal whether a `SLACK_BOT_TOKEN` is present; if yes, second blob + second env line in start.sh. If absent, this task is a no-op — mark DONE with a comment in the plan. estimate_minutes: 20. Files: `secrets/work/encrypted/slack-bot-token.age` (conditional), `mcps/slack/scripts/start.sh` (conditional second env line). DoD: bot token either migrated and verified via a bot-posting probe, OR task retired with written confirmation. Owner: Ekko. PR-B (folded into T2 commit if small). BlockedBy: T2.

- [ ] **P1-T4** — Migrate Fathom API + HubSpot Private App tokens. `mcps/mmp-fathom/.env` contains both — one blob per credential: `fathom-api-token.age`, `hubspot-private-app-token.age`. Rewrite `mcps/mmp-fathom/scripts/start.sh` to decrypt both, delete `.env`, verify with a `list_meetings` probe and a `hubspot_search` probe. estimate_minutes: 35. Files: `secrets/work/encrypted/fathom-api-token.age`, `secrets/work/encrypted/hubspot-private-app-token.age`, `mcps/mmp-fathom/scripts/start.sh`, `mcps/mmp-fathom/.env` (deleted), `secrets/work/REVOCATION.md`. DoD: `.env` gone; both blobs exist; both probes succeed. Owner: Ekko. PR-B. BlockedBy: T0, T1.

- [ ] **P1-T5** — Migrate Postgres connection string(s). `mcps/postgres/.env` is 646 bytes — likely multiple `POSTGRES_URL_*` entries. One blob per distinct connection string (e.g. `postgres-prod.age`, `postgres-stg.age`, `postgres-local.age` — inventory at task time). Rewrite start.sh to decrypt each. estimate_minutes: 40. Files: `secrets/work/encrypted/postgres-*.age`, `mcps/postgres/scripts/start.sh`, `mcps/postgres/.env` (deleted), `secrets/work/REVOCATION.md`. DoD: `.env` gone; blobs exist per connection; `list_connections()` returns expected set; one `describe_table` probe on prod succeeds read-only. Owner: Ekko. PR-B. BlockedBy: T0, T1. **Flag:** if any connection string embeds a non-rotatable credential (e.g. a legacy service account), surface before encryption so OQ-P1-2 is answered.

- [ ] **P1-T6** — Migrate Wallet-Studio API key(s). `mcps/wallet-studio/.env` is 155 bytes — likely single-credential. One blob: `wallet-studio-api-key.age`. Rewrite start.sh, delete `.env`, verify with a read probe (the MCP exposes wallet read tools — pick the lightest-weight one for the probe). estimate_minutes: 25. Files: `secrets/work/encrypted/wallet-studio-api-key.age`, `mcps/wallet-studio/scripts/start.sh`, `mcps/wallet-studio/.env` (deleted), `secrets/work/REVOCATION.md`. DoD: `.env` gone; blob exists; read probe succeeds. Owner: Ekko. PR-B. BlockedBy: T0, T1.

- [ ] **P1-T7a** — Encrypt Gdrive OAuth client JSON. `mcps/gdrive/gcp-oauth.keys.json` is the OAuth **client** blob (app identity, not user identity — re-rotating it requires a new GCP OAuth client but is possible without user re-login). Age-encrypt into `secrets/work/encrypted/gdrive-oauth-keys.age`. Do NOT yet touch start.sh — T8 bundles the start.sh rewrite. estimate_minutes: 15. Files: `secrets/work/encrypted/gdrive-oauth-keys.age`, `secrets/work/REVOCATION.md`. DoD: blob exists; plaintext JSON still on disk (will be removed in T8). Owner: Ekko. PR-C. BlockedBy: T0, T1.

- [ ] **P1-T7b** — Encrypt Gdrive server credentials (user refresh token). `mcps/gdrive/.gdrive-server-credentials.json` is the **user** refresh token — NON-ROTATABLE without Duong re-authing. **Flag OQ-P1-1 before encrypting:** if this token is healthy, migrate now (one-time pain if re-auth needed); if broken, defer to next natural re-auth. estimate_minutes: 20. Files: `secrets/work/encrypted/gdrive-server-credentials.age`, `secrets/work/REVOCATION.md`. DoD: health-check done (run any read probe via current `gdrive` MCP); blob exists; original plaintext still on disk (will be removed in T8). Owner: Ekko (after Sona resolves OQ-P1-1 with Duong). PR-C. BlockedBy: T0, T1, OQ-P1-1 resolution.

- [ ] **P1-T8 (REVISED — wrapper shape)** — Author `mcps/wrappers/gdrive-launcher.sh` in strawberry-agents that decrypts both Gdrive blobs and exposes them to the unmodified upstream `~/Documents/Work/mmp/workspace/mcps/gdrive/scripts/start.sh`. Because the upstream node MCP reads OAuth credentials **from file paths, not env vars**, the wrapper writes plaintext into a strawberry-side tmp dir (e.g. `secrets/work/runtime/gdrive-oauth-keys.json` and `secrets/work/runtime/gdrive-server-credentials.json`, both mode 0600, gitignored), exports `GDRIVE_OAUTH_PATH` and `GDRIVE_CREDENTIALS_PATH` env vars pointing at those files, then exec's the upstream `start.sh`. Trap-cleanup on wrapper exit removes the runtime files. Update `~/Documents/Work/mmp/workspace/.mcp.json` so `gdrive` points at our wrapper. **NEVER modify upstream files** — the upstream `gcp-oauth.keys.json` and `.gdrive-server-credentials.json` inside `mmp/workspace/mcps/gdrive/` stay where they are; our wrapper supersedes them via the env-var path overrides if upstream supports them, or via shadowing `cd` into the runtime dir. If upstream's start.sh hardcodes the credential paths inside the upstream dir without honoring env-var overrides, that is a multi-var T-new-C concern AND requires the wrapper to materialize the runtime files at the upstream-expected relative paths via tmpfs symlinks — but those symlinks live in OUR runtime dir, never overwriting upstream. estimate_minutes: 60. Files (strawberry-agents): `mcps/wrappers/gdrive-launcher.sh`, `secrets/work/runtime/.gitkeep`. Files (work workspace, config-only): `~/Documents/Work/mmp/workspace/.mcp.json`. **Files NOT touched:** anything under `~/Documents/Work/mmp/workspace/mcps/gdrive/`. DoD: wrapper exec's upstream cleanly; `list_files` probe succeeds; `git -C ~/Documents/Work/mmp/workspace status` shows only `.mcp.json` modified; trap-cleanup verified. Owner: Talon. PR (strawberry-agents). BlockedBy: T7a, T7b, T-new-D, T-new-C (multi-var). **Note:** this is the single largest task in Phase 1 because the upstream node MCP reads credentials from file paths, not env. If upstream's path-resolution behavior is unclear at task time, surface as new OQ before proceeding.

- [ ] **P1-T9** — Encrypt Gcalendar credentials. `mcps/gcalendar/.env` is absent per current listing — credentials are likely embedded in the node dist or passed differently. Ekko inspects `mcps/gcalendar/dist/index.js` + `scripts/start.sh` to identify where Gcalendar reads its OAuth state; produces one `gcalendar-credentials.age` blob covering whatever that source is. If it's the same Google OAuth refresh token as gdrive, document the reuse and link to `gdrive-server-credentials.age` rather than duplicating. estimate_minutes: 35. Files: `secrets/work/encrypted/gcalendar-credentials.age` (may be a symlink-via-doc note if shared), `mcps/gcalendar/scripts/start.sh`, `secrets/work/REVOCATION.md`. DoD: encryption strategy documented; start.sh decrypts; `list_events` probe on today's calendar succeeds. Owner: Ekko. PR-C. BlockedBy: T0, T1, T7b (only if shared refresh token).

- [ ] **P1-T10** — Provision Atlassian API token + encrypt. Duong generates an Atlassian personal API token at `id.atlassian.com → API tokens`; Ekko ages it into `atlassian-api-token.age` and the site URL + email into `atlassian-site-config.age` (bundled per §4.2 for lock-step rotation). **Duong-in-the-loop:** only Duong can generate the API token — surface this as a one-line ask. estimate_minutes: 30 (excluding Duong's wait time). Files: `secrets/work/encrypted/atlassian-api-token.age`, `secrets/work/encrypted/atlassian-site-config.age`, `secrets/work/REVOCATION.md`. DoD: both blobs exist; plaintext never persists. Owner: Ekko (after Duong provides token). PR-D. BlockedBy: T1.

- [ ] **P1-T11** — Rewrite `mcps/mcp-atlassian/scripts/start.sh` to decrypt both Atlassian blobs and pass as `--confluence-*` / `--jira-*` flags to `uvx mcp-atlassian`. No `.env` file ever created. estimate_minutes: 30. Files: `mcps/mcp-atlassian/scripts/start.sh`. DoD: start.sh runs clean from a shell manual test; no `.env` exists under `mcps/mcp-atlassian/`. Owner: Ekko. PR-D. BlockedBy: T10.

- [ ] **P1-T12** — Register `mcp-atlassian` in `~/Documents/Work/mmp/workspace/.mcp.json` (append a 7th `mcpServers` block pointing at `mcps/mcp-atlassian/scripts/start.sh`). Verify with `claude mcp list` — expect 7/7 Connected. estimate_minutes: 15. Files: `~/Documents/Work/mmp/workspace/.mcp.json`. DoD: `claude mcp list` shows 7 servers, all Connected; a `jira_search` probe returns at least one recent issue. Owner: Syndra (config nudge). PR-D. BlockedBy: T11.

- [ ] **P1-T13** — Gmail MCP: scaffold `mcps/gmail/` and install `@gongrzhe/server-gmail-autoauth-mcp` per §3.1 row 4. Ekko stands up the directory, writes `scripts/start.sh`, `MCP.md`, installs the package (npm or npx-based per upstream README at task time). No OAuth yet — that's T14. estimate_minutes: 45. Files: `mcps/gmail/scripts/start.sh`, `mcps/gmail/MCP.md`, `mcps/gmail/package.json` or lockfile as the upstream requires. DoD: `bash mcps/gmail/scripts/start.sh` exits cleanly with an "OAuth required" error (expected — pre-T14). Owner: Ekko. PR-E. BlockedBy: T1. **Note:** if upstream README changed or is unmaintained at task time, Ekko surfaces OQ-P1-3 (swap to `@modelcontextprotocol/server-gmail` or alternative).

- [ ] **P1-T14-Duong** — **Duong-in-the-loop:** authorize the Gmail MCP against Duong's Google account via the upstream `autoauth` browser flow. Only Duong can do this. Output is a refresh-token JSON that the MCP reads. estimate_minutes: 20 (Duong's clock time). Files: whatever local path the upstream auth flow writes (will be encrypted in T15). DoD: the post-OAuth token file exists on disk at the expected path; a Gmail `search is:unread newer_than:1d` probe from Duong's live session returns. Owner: Duong (Ekko provides the command to run and the expected prompt). PR-E. BlockedBy: T13.

- [ ] **P1-T15 (REVISED — wrapper shape)** — Encrypt the Gmail OAuth refresh token to `secrets/work/encrypted/gmail-oauth.age` and author `mcps/wrappers/gmail-launcher.sh` in strawberry-agents. Same pattern as `gdrive-launcher.sh` (T8) if upstream reads credentials from a file path, or canonical single-`--var` pattern (T-new-D) if upstream accepts env vars. Note: the Gmail MCP scaffold itself (T13) lives at `~/Documents/Work/mmp/workspace/mcps/gmail/` (or wherever upstream installs it) and is **not modified by us** — only the wrapper is ours. Update `~/Documents/Work/mmp/workspace/.mcp.json` to point at our wrapper. Delete the plaintext refresh-token file ONLY if it sits in OUR scope (e.g. if Duong wrote it to `~/Downloads/` or strawberry-agents during T14-Duong); if it landed inside the upstream MCP dir, leave it for the company-engineer flow to manage. estimate_minutes: 40. Files (strawberry-agents): `secrets/work/encrypted/gmail-oauth.age`, `mcps/wrappers/gmail-launcher.sh`, `secrets/work/REVOCATION.md`. Files (work workspace, config-only): `~/Documents/Work/mmp/workspace/.mcp.json`. DoD: blob exists; wrapper decrypts on boot and exec's upstream Gmail MCP; Gmail probe succeeds; no upstream files modified. Owner: Talon. PR (strawberry-agents). BlockedBy: T14-Duong, T-new-D.

- [ ] **P1-T16** — Register `gmail` in `~/Documents/Work/mmp/workspace/.mcp.json` (8th `mcpServers` block). Run final `claude mcp list` from the work workspace CWD and verify **8/8 Connected**. estimate_minutes: 15. Files: `~/Documents/Work/mmp/workspace/.mcp.json`, `agents/sona/memory/sona.md` (phase-1-done shard). DoD: Phase 1 success criterion met — `claude mcp list` shows exactly 8 servers, all Connected; one representative probe per MCP (scripted or manual) returns non-empty. Owner: Syndra (config) + Ekko (verification script if automated). PR-E. BlockedBy: T15. This is the Phase 1 acceptance task.

### Phase 1 gates

1. **After T1**: `secrets/work/encrypted/` exists + revocation doc committed. Unblocks all migration tasks.
2. **After T0**: decrypt pattern ratified in §4.2. Unblocks all start.sh rewrites.
3. **After T2-T9**: six existing MCPs migrated + Connected. Intermediate `claude mcp list` should show 6/6 still. **If any MCP fails post-migration, revert that MCP's PR-B or PR-C commit and open a bug task — do not proceed to T10.**
4. **After T12**: Atlassian Connected. 7/7.
5. **After T16**: Phase 1 acceptance. 8/8.

### Test plan — T-new-D and T-new-D-smoke (added 2026-04-25)

Although the plan-level `tests_required: false` reflects that the ADR is a workflow document, T-new-D introduces shipped code (`mcps/wrappers/slack-launcher.sh`) and therefore inherits Rule 12 (xfail-first) and Rule 14 (pre-commit unit tests).

**Invariants the smoke test protects (in priority order):**

1. **End-to-end exec-chain works.** The wrapper actually `exec`s the upstream MCP with `SLACK_USER_TOKEN` populated. Grep-only checks (e.g. "wrapper file mentions SLACK_USER_TOKEN") are insufficient — earlier reviewer feedback explicitly flagged this as a class-of-bug. Smoke must spawn the chain and verify env injection from the child's perspective.

2. **No upstream-file mutation.** After running the smoke, `git -C ~/Documents/Work/mmp/workspace status` must show clean (or only `.mcp.json` modified, depending on which task). Any other modification under `mmp/workspace/mcps/` is a hard fail.

3. **Plaintext residency.** The decrypted token must NOT appear in: parent-shell env (assert via `env | grep -v __SLACK_TEST_TOKEN__`), wrapper stdout/stderr, any committed file, or any file outside `secrets/work/runtime/`. The runtime env-file under `secrets/work/runtime/slack.env` must be mode 0600.

4. **Cleanup behavior.** When the wrapper exits (clean or via signal), the runtime env-file should be removed (trap cleanup) — or at minimum, never world-readable.

**Test mechanics for T-new-D-smoke:**

- Fixture-driven: in-test generation of an age key + encrypted blob containing sentinel `__SLACK_TEST_TOKEN__`. No reliance on `secrets/age-key.txt` or real Slack tokens.
- `UPSTREAM_START` env override → `scripts/tests/probe-upstream-slack.sh`, a probe that asserts `SLACK_USER_TOKEN=__SLACK_TEST_TOKEN__`, writes a marker file, exit 0.
- Wired into pre-commit hook test lane for changes touching `mcps/wrappers/` or `tools/decrypt.sh`.

**Full integration test (P1-T2 acceptance, runs after blob is provisioned with the real Slack token):**

- `claude mcp list` from `~/Documents/Work/mmp/workspace/` shows `slack` Connected after `.mcp.json` is updated to point at our wrapper.
- `slack_list_channels` MCP probe returns > 0 channels.
- `git -C ~/Documents/Work/mmp/workspace diff` shows ONLY the `.mcp.json` line change.

**Out of scope for T-new-D smoke (deferred to per-MCP wrapper tasks):** wrapper-launcher tests for gdrive, gcalendar, gmail, fathom, postgres, wallet-studio, atlassian — those tasks each get their own analogous smoke once T-new-C lands multi-var support.

### Open questions surfaced during breakdown

| ID | Question | Bearing | Who resolves |
|---|---|---|---|
| OQ-P1-1 | Is Duong's current Gdrive user refresh token at `mcps/gdrive/.gdrive-server-credentials.json` healthy, or has it silently broken since the last use? If broken, do we migrate-as-is (encrypt a broken token — useless) or defer T7b until next natural re-auth? | T7b blocks on this. | Sona asks Duong; Ekko runs a health probe first to inform the ask. |
| OQ-P1-2 | Does `mcps/postgres/.env` contain any connection string with a non-rotatable embedded credential (service account provisioned by a MMP admin other than Duong, legacy readonly user, etc.)? If yes, is migration-in-place acceptable or do we need a rotation-first step? | T5 blocks on this. | Ekko inspects during T5; escalates to Sona if any row is non-rotatable. |
| OQ-P1-3 | The ADR §3.1 row 4 names `@gongrzhe/server-gmail-autoauth-mcp`. At T13 execution time, is that package still maintained (last commit < 90d) and functional against current Gmail OAuth? If not, which alternative (`@modelcontextprotocol/server-gmail` or other community fork) do we swap to? | T13 blocks on this. | Ekko inspects at task time; Sona approves the swap if needed. |
| OQ-P1-4 | **RESOLVED (2026-04-24)** — Heimerdinger's advisory ratified the `tools/decrypt.sh --exec` canonical pattern (ciphertext on stdin, env-var name via `--var`, runtime target via `--target`, child process replaces the shell via `--exec --`). §4.2 rewritten inline with the canonical template + a "Multi-secret MCPs" carve-out. Multi-secret MCPs (Slack if two tokens, any others from T-new-B inventory) stay on plaintext `.env` until T-new-C extends the tool. New Phase-1 tasks T-new-A (this amendment), T-new-B (inventory), T-new-C (conditional multi-var extension), T-new-D (reference start.sh), T-new-E (positive test) appended to the task list. | Resolved. Was blocking T0 (now superseded by T-new-A/D). | Heimerdinger (advised) + Aphelios (amended plan). |
| OQ-P1-5 | Gcalendar: no `.env` exists; the node dist likely reads credentials from a hardcoded relative path or from the gdrive refresh token. T9's inspection step may reveal the credential is SHARED with gdrive (same Google OAuth refresh token). If shared, do we keep one `.age` blob and symlink-via-doc, or duplicate for decoupled rotation? | T9 design decision. | Ekko proposes during T9; Sona ratifies. |

### Task count and critical path summary

- **Total tasks:** 22 (T-new-A [DONE], T-new-B, T-new-C [conditional], T-new-D, T-new-E, plus original T0, T1, T2, T3, T4, T5, T6, T7a, T7b, T8, T9, T10, T11, T12, T13, T14-Duong, T15, T16). T3 may no-op and fold into T2. T-new-C conditional on T-new-B finding multi-secret MCPs.
- **Critical path (updated):** T-new-A (DONE) → T-new-D → then P1-T2/T4/T5/T6 secret-migration cluster can fan out. T-new-C specifically gates Slack migration (P1-T3) if Slack has multiple tokens. Gmail leg still: T13 → **T14-Duong** → T15 → T16. Duong's Gmail OAuth step remains the longest real-world-clock gate.
- **Parallelizable after T0+T1:** PR-B cluster (T2, T4, T5, T6), PR-C cluster (T7a → T7b → T8 → T9), PR-D cluster (T10 → T11 → T12). Ekko can run PR-B and PR-D in parallel if Duong has pre-generated the Atlassian token.
- **Duong-in-the-loop tasks:** T10 (Atlassian token generation, ~2 min), T14-Duong (Gmail OAuth, ~20 min), OQ-P1-1 resolution (async).

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** approved → in-progress
- **Rationale:** Plan was scope-corrected today (commit 70d275f9) after two consecutive PR closures (#48, #33) revealed an architectural error — modifying upstream company-shared MCP files instead of wrapping them. The correction is structural: §0 preamble, rewritten §4.2 specifying wrappers at `mcps/wrappers/<service>-launcher.sh` in strawberry-agents, universal scope rule on T2-T16 making upstream files read-only, T-new-D rewritten as wrapper authorship with co-landing xfail (T-new-D-xfail) and end-to-end smoke (T-new-D-smoke) protecting four named invariants. Tasks are actionable with clear owners (Talon for wrappers, Ekko for blob/config, Syndra for verification, Duong-in-loop for OAuth). T-new-D is dispatch-ready.
- **Simplicity:** WARN: possible overengineering — §4.2 inventory enumerates 6/8 MCPs as multi-secret, gating much of Phase 1 on T-new-C (`tools/decrypt.sh` multi-var extension); a per-MCP runtime env-file with `set -a; source` shape may be simpler than extending the tool surface. Also the four-PR split (PR-A..PR-E) for what is functionally one wave of credential migrations adds rollout ceremony — a single per-MCP commit cadence would achieve the same revertability.
- **Estimate totals:** T0 (45) + T1 (20) + T2 (35) + T3 (20) + T4 (35) + T5 (40) + T6 (25) + T7a (15) + T7b (20) + T8 (50) + T9 (35) + T10 (30) + T11 (30) + T12 (15) + T13 (45) + T14 (20) + T15 (35) + T16 (15) = **530 min of active work (~8.8h)** plus Duong wait time. Wall-clock expectation: 1.5–2 days with Ekko executing sequentially, ~1 day if PR-B and PR-D parallelize.
