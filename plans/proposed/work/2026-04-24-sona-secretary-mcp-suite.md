---
title: Sona secretary — MCP suite + morning brief
status: proposed
concern: work
owner: swain
author: swain
created: 2026-04-24
kind: adr
tests_required: false
architecture_impact: workflow
---

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

Each `start.sh` pattern (template, adapted per MCP):

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="/Users/duongntd99/Documents/Personal/strawberry-agents"

# Decrypt into env of the child process only — never to disk.
TOKEN="$("$REPO/tools/decrypt.sh" "$REPO/secrets/work/encrypted/<name>.age")"
[ -n "$TOKEN" ] || { echo "<mcp>: decryption failed" >&2; exit 1; }

exec env \
  SOME_TOKEN="$TOKEN" \
  ... \
  uvx|node|python3 "$DIR/..."
```

Plaintext `.env` files in MCP dirs (currently present for most work MCPs) are **migrated away** as part of Phase 1. The ADR does not depend on Rule 6 being enforced at MCP boot — it IS the enforcement, applied consistently.

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
