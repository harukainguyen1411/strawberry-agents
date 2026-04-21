---
status: proposed
owner: bard
revised: 2026-04-08
supersedes_shape: 2026-04-03 Discord-CLI (Claude-on-VPS) revision
---

# Discord to GitHub Issues Triage Bridge

## Summary

A thin Discord bot that listens to one channel, triages every message with **Gemini 2.0 Flash** (Google AI Studio free tier), and files a structured **GitHub issue** in the Strawberry monorepo, tagged for **MyApps** (the product at `apps/myapps/`, not the Strawberry agent system itself). The bot replies in Discord with the issue URL. That is the entire scope.

**Important framing.** Strawberry is Duong's personal meta-agent system. MyApps is the actual product Duong's friends use and file issues against — it lives as a subtree at `apps/myapps/` inside the Strawberry monorepo. Issues live in the Strawberry GitHub repo (same repo as this plan), but are labeled `myapps` so they're filterable and so the autonomous-delivery-pipeline can route them correctly. The Discord bot's mental model is "MyApps the product" — its codebase context is scoped to `apps/myapps/`, not the whole monorepo.

**Claude never runs in this path.** Downstream, Duong's autonomous-delivery-pipeline (see `2026-04-08-autonomous-delivery-pipeline.md`) watches GitHub issues on Duong's own hardware under Duong's own Max login and decides which issues to pick up. The Discord bot has no knowledge of Claude and no coupling to any Claude runtime.

This plan is a ground-up rewrite of the previous Discord-CLI revision. The "Claude-CLI-as-Evelynn on a VPS" shape and the "home-box + runlock" shape are both dead. Both collapsed once Duong clarified that Discord has third-party friends in it, which makes any path that routes non-Duong messages through Duong's Max OAuth a Consumer ToS violation. Moving Claude out of the Discord path entirely removes the compliance question.

## Why the pivot

1. **Third parties in the Discord server.** Friends post there, not just Duong and his agents. Any architecture that pipes those messages into a Claude subscription owned by Duong turns third-party humans into "users" of Duong's Max plan, which Consumer ToS does not permit. See tonight's Max ToS research brief.
2. **Move Claude out of the Discord path.** The bot files structured issues; the autonomous-delivery-pipeline — which runs on Duong's hardware under Duong's login — decides what to do with them. This is identical in compliance posture to any personal `claude` headless automation.
3. **Gemini 2.0 Flash via AI Studio free tier.** Commercial terms explicitly permit building services on the API. Free tier ceiling (~1,500 requests/day, ~1M tokens/day input, ~15 RPM) is ~1000x what a friend-group Discord bot will spend. This is a different product from Duong's Google One AI Premium consumer subscription, which does not cover programmatic API use — the key used here is an AI Studio key.
4. **Codebase-aware triage.** Gemini Flash's 1M token context window easily fits Strawberry (~150–300k tokens estimated). Stuffing the repo into the system prompt lets the bot write issues that reference the right files, modules, plans, and agents instead of generic stubs.

## Architecture

Single process. Single channel. Single monorepo subtree. Outbound-only network. No inbound tunnel, no home-box dependency, no process supervisor coupling, no shared runlock with Bee.

**Code location.** The bot lives at `apps/discord-relay/` — a skeleton already exists there from the previous Claude-CLI revision (discord.js Gateway wiring, `sanitize()` helper, Express `/health` server, package.json with discord.js + express). This plan **repurposes that skeleton**: the Gateway connection, sanitize helper, and health server stay; the filesystem event bus internals (`DATA_DIR`, `EVENTS_DIR`, `RESPONSES_DIR`, `processResponses`, `startResponseWatcher`, forum-thread machinery) are deleted and replaced with the Gemini → GitHub path described below. Add TypeScript at this point — the existing `src/index.js` becomes `src/index.ts` during the rewrite, and the package gets `@google/generative-ai`, `@octokit/rest`, and TypeScript toolchain deps.

```
Discord Gateway (outbound WebSocket)
    |
    v
triage-bot (Node.js, discord.js)
    |   watches ONE channel (TRIAGE_DISCORD_CHANNEL_ID)
    |
    +--> Context cache (in-memory)
    |        triage-context.md (hand-written)
    |        + repo dump (git ls-files, filtered)
    |        + last 50 open issues (gh issue list)
    |        refresh: every N hours (default 6), optional GitHub push webhook
    |
    +--> Gemini 2.0 Flash (AI Studio API)
    |        system: context cache
    |        user: sanitized Discord message + author + channel + ts
    |        response_mime: application/json
    |        schema: {title, body, labels[], priority, dupe_of_issue_number}
    |
    +--> GitHub REST API (or `gh` CLI)
    |        if dupe_of_issue_number: POST comment on existing issue
    |        else: POST new issue in TRIAGE_TARGET_REPO
    |
    +--> Discord reply in-thread: "Filed as #N: <url>"
                                  or "Added to existing #M: <url>"
```

### Components

| Component | File / Module | Purpose |
|---|---|---|
| Discord client | `apps/discord-relay/src/discord.ts` | Gateway connection, message listener on one channel (sanitize helper preserved from existing skeleton) |
| Context loader | `apps/discord-relay/src/context.ts` | Build + cache the Gemini system prompt from `apps/myapps/` subtree |
| Gemini client | `apps/discord-relay/src/gemini.ts` | One call: stuffed context + user message → JSON verdict |
| GitHub client | `apps/discord-relay/src/github.ts` | Create issue or append comment on dedupe match, always with `myapps` label |
| Quota guard | `apps/discord-relay/src/quota.ts` | Per-UTC-day Gemini call counter with daily reset |
| Observability | `apps/discord-relay/src/log.ts` | Append-only JSONL of every triage decision |
| Health check | `apps/discord-relay/src/health.ts` | HTTP `/health` — Discord connected, last Gemini ok, last GitHub ok (reuses Express scaffold) |
| Hand-written context | `apps/myapps/triage-context.md` | Duong-maintained MyApps product overview, colocated with the code it describes |
| Entry point | `apps/discord-relay/src/index.ts` | Wires everything, owns process lifecycle |

### 1. Context loader

**Refresh triggers.**
- **Timer.** Every `TRIAGE_CONTEXT_REFRESH_HOURS` hours (default 6). In-memory cache with a `stale_after` timestamp. First request after expiry rebuilds synchronously; subsequent requests use the fresh cache.
- **Optional GitHub push webhook.** If hosted where an HTTP endpoint is practical (Cloud Run, Firebase Functions HTTP trigger), a `/webhook/github-push` route invalidates the cache on push to `main`. Not required for v1 — the 6-hour timer is the baseline. If the webhook path adds operational complexity, skip it and rely on the timer.

**Repo dump construction (scoped to the MyApps subtree).**
1. `git ls-files apps/myapps/` — scoped to the subtree only. **Never dumps the whole Strawberry monorepo** (agents/, plans/, mcps/, .claude/ are all irrelevant to MyApps triage and would waste context and leak agent-system internals into Gemini's view).
2. Include extensions: `.md`, `.ts`, `.tsx`, `.js`, `.vue`, `.json`, `.yml`, `.yaml`, `.css`, `.html`, `.sh`.
3. Exclude path prefixes (relative to `apps/myapps/`):
   - `node_modules/`
   - `dist/`, `build/`, `.firebase/`
   - `e2e/` snapshot dirs and `test-results/`
   - `.cursor/` (editor-local)
   - anything matching `*.lock`, `*.min.*`, `*.map`
4. Exclude any file > 200 KB.
5. Concatenate with `=== apps/myapps/<relative path> ===\n<contents>\n\n` headers into one string. Paths are kept prefixed with `apps/myapps/` so Gemini emits file references that work from the monorepo root when the downstream pipeline reads them.

**Open issues snapshot (filtered by `myapps` label).**
- `gh issue list --label myapps --state open --json number,title,body,labels --limit 50`
- No `--repo` flag needed — the bot runs inside the Strawberry repo checkout and `gh` defaults to the current repo. Alternatively pass `--repo Duongntd/strawberry` explicitly; confirm the exact owner handle (see open questions).
- Truncate each body to 500 chars before serializing. Include for dedupe signals.
- Dedupe decisions consider only `myapps`-labeled issues. Strawberry-infra issues, agent issues, and plan issues are intentionally invisible to the triage bot.

**System prompt layout (exact order).**
```
<triage-context.md verbatim>
---
# Open Issues Snapshot
<serialized list of 50 open issues>
---
# Repository Dump
<concatenated repo files>
---
# Instructions
<triage instructions, output schema, dedupe rules>
```

The hand-written `triage-context.md` sits at the top because Gemini weights early-system content heavily, and Duong's vocabulary / labels / tone should dominate the model's framing.

### 2. `apps/myapps/triage-context.md` (new file, Duong-maintained)

Lives inside the MyApps subtree so the context is colocated with the code it describes. The bot reads it fresh on every context rebuild (it's one of the files included in the repo dump step). Duong editing it takes effect on next refresh (or immediately if paired with the GitHub push webhook).

Template sections (Duong fills in and keeps current):
- **What MyApps is.** One paragraph. The product, not the agent system. Vue + Firebase app, whatever features currently ship (Read Tracker, Portfolio Tracker, Task List based on the current subtree).
- **Feature areas.** One line each: `read-tracker`, `portfolio-tracker`, `task-list`, `auth`, `sync`, `i18n`, etc. Used as label hints.
- **User flows.** Two to three paragraphs on the main flows a friend would actually hit — so Gemini writes issues that reference the right screens and components.
- **Issue taxonomy.** The label set the bot is allowed to use, with one-line definitions each. e.g. `type/bug`, `type/feature`, `type/chore`, `type/question`, `area/read-tracker`, `area/portfolio-tracker`, `area/task-list`, `area/auth`, `priority/p0..p3`. Every filed issue also receives the fixed `myapps` label automatically (not selected by Gemini).
- **Tone.** "Direct. No hedging. Use Duong's vocabulary." Link to the global style conventions.
- **Exact terms to use.** Product-level vocabulary ("book" not "entry", "session" not "log", etc.) — Duong fills this in from the MyApps codebase conventions.
- **When to dedupe.** Rules like "if an open `myapps` issue within 90% semantic overlap exists, comment on it instead."
- **What NOT to file.** Strawberry agent-system problems, MCP problems, plan-lifecycle problems — if the user is reporting something that isn't MyApps, Gemini should reply in Discord with "this looks like a Strawberry issue, not MyApps — file it manually" and skip issue creation.

The bot reads this file fresh on every context rebuild. Duong editing it takes effect on next refresh (or immediately if paired with the GitHub push webhook).

### 3. Gemini call

- **Model:** `gemini-2.0-flash` at plan-execution time. Pin the exact model ID in `bot/src/gemini.ts` as a constant; upgrade by editing one line. If Google has shipped a newer stable Flash-tier by execution time, use it but note the version bump in the commit.
- **SDK:** `@google/generative-ai` (official Node SDK).
- **Call shape:**
  - `systemInstruction`: the composed system prompt from the context loader.
  - `contents`: one user turn containing `author: <handle>, channel: <id>, ts: <iso>, message: <sanitized text>`.
  - `generationConfig.responseMimeType`: `application/json`.
  - `generationConfig.responseSchema`: JSON schema for the verdict (below).
  - `generationConfig.temperature`: 0.3 (we want consistent classification, not creative prose).
- **Verdict schema:**
  ```json
  {
    "title": "string, <=80 chars",
    "body": "string, GitHub-flavored markdown",
    "labels": ["string", ...],
    "priority": "p0|p1|p2|p3",
    "dupe_of_issue_number": "integer or null"
  }
  ```
- **Strict JSON mode** (no retry/repair loop for v1). If parse fails, log, post "triage failed, try rephrasing" in Discord, do not file.

### 4. GitHub issue creator

- Prefer the REST API via `@octokit/rest` with `GITHUB_TOKEN`. Cleaner error handling than shelling out.
- **Target repo is the current repo** — the Strawberry monorepo that holds this plan. Derive at startup via `gh repo view --json nameWithOwner` (or read `GITHUB_REPOSITORY` if set by the host env). No `TRIAGE_TARGET_REPO` env var.
- **Every filed issue gets the fixed `myapps` label added automatically**, merged with whatever Gemini returns in `labels[]`. This is a code-level wire, not a Gemini decision — guarantees downstream filtering always works even if Gemini forgets.
- If `dupe_of_issue_number` is non-null: `POST /repos/{owner}/{repo}/issues/{N}/comments` with a body that cites the original Discord message and its author. Before posting, verify the target issue actually carries the `myapps` label — if it doesn't (Gemini hallucinated an issue number from an unrelated Strawberry issue), fall through to filing a new issue instead.
- Otherwise: `POST /repos/{owner}/{repo}/issues` with `title`, `body`, `labels` (Gemini-chosen labels ∪ `{myapps}`). Append a footer to the body: `---\n_Filed via triage-bot from Discord #<channel> by <author> at <ts>._`
- Reply in Discord (same channel, threaded off the originating message) with the issue URL.
- On API failure: reply with an error in Discord, log the failure, do not retry automatically for v1.

### 5. Configuration (env vars)

| Var | Purpose | Required |
|---|---|---|
| `DISCORD_BOT_TOKEN` | Discord Gateway auth | yes |
| `GEMINI_API_KEY` | Google AI Studio free-tier API key | yes |
| `GITHUB_TOKEN` | PAT with `repo:issues` scope for the Strawberry repo | yes |
| `TRIAGE_DISCORD_CHANNEL_ID` | The single channel the bot watches | yes |
| `TRIAGE_TARGET_SUBTREE` | Repo subtree to dump as context, default `apps/myapps` | no |
| `TRIAGE_TARGET_LABEL` | Label added to every filed issue + used for dedupe filter, default `myapps` | no |
| `TRIAGE_CONTEXT_REFRESH_HOURS` | Cache TTL, default `6` | no |
| `TRIAGE_DAILY_QUOTA` | Max Gemini calls per UTC day, default `1000` | no |
| `LOG_PATH` | JSONL log file path | no |

No `TRIAGE_TARGET_REPO` — the bot runs inside a Strawberry checkout and reads `nameWithOwner` from `gh repo view` (or `GITHUB_REPOSITORY` env) at startup.

Secrets at rest: live in `secrets/` (gitignored) as an encrypted `triage-bot.env.age`, decrypted at process start via `tools/decrypt.sh`. The decrypted plaintext only exists in the child process env (see Rule 11). On a hosted environment (Cloud Run / Firebase), use Secret Manager and bind secrets as env vars at deploy time — the `tools/decrypt.sh` path is the local/dev fallback.

### 6. Allowlist

**Channel-level only.** The bot listens to exactly one channel. Anyone Discord permits to post in that channel may file issues. Per-user gating is managed at the Discord permission layer, not in bot code. This keeps the bot stateless w.r.t. identity and lets Duong add/remove friends via normal Discord role management.

### 7. Rate limiting and quota guardrails

- **Per-day Gemini quota.** Counter keyed by `YYYY-MM-DD` in UTC, persisted to a small local file (`quota-state.json`). Increments on each Gemini call, resets at UTC midnight via a cheap date-rollover check on each request.
- **Soft cap:** at 80% of `TRIAGE_DAILY_QUOTA`, append a warning to every triage reply ("approaching daily quota").
- **Hard cap:** at 100%, skip the Gemini call entirely, reply in Discord: "Daily triage quota exhausted — resets at 00:00 UTC. File manually in GitHub if urgent: <repo-issues-url>".
- **Per-minute throttle:** simple token bucket, 10 RPM (well under Gemini's 15 RPM free-tier ceiling). Over-budget messages are queued in memory up to 20 slots, then rejected with a Discord reply.
- **Message-length cap:** truncate the Discord message to 4000 chars before passing to Gemini; note the truncation in the issue body if it happened.

### 8. Observability

Append one JSONL record per triage attempt to `LOG_PATH`:
```json
{
  "ts": "2026-04-08T12:34:56Z",
  "discord_user": "handle#1234",
  "discord_channel": "id",
  "discord_message_id": "id",
  "message_preview": "first 120 chars",
  "outcome": "filed|deduped|quota|parse_error|api_error",
  "issue_url": "https://github.com/...|null",
  "dupe_of": "N|null",
  "gemini_calls_today": 47,
  "duration_ms": 1820
}
```

On Cloud Run: log to stdout and let Cloud Logging ingest. On a local host: a rolling file in `var/log/triage-bot/`. No dashboard in v1. `grep` is fine.

### 9. Health check

HTTP `GET /health` returns JSON:
```json
{
  "discord_connected": true,
  "last_gemini_ok_age_s": 142,
  "last_github_ok_age_s": 87,
  "gemini_calls_today": 47,
  "quota_remaining": 953,
  "context_cache_age_s": 3600,
  "ok": true
}
```

`ok` is true iff Discord is connected AND `last_gemini_ok_age_s` < 24h (or bot has never been asked to triage yet) AND `last_github_ok_age_s` < 24h. Cloud Run / Firebase liveness probes point here. On a local host, a cron hits `/health` and pings Duong's Telegram bridge if it flips to false.

## Hosting recommendation

**Cloud Run with `min_instances=1`.**

Reasoning:
- Google ecosystem consistency with Bee (Duong asked for Google infra).
- Discord Gateway is a long-lived outbound WebSocket. Firebase Functions (Gen 1 or Gen 2) are request-response and not designed to hold a persistent connection — you'd burn billable time keeping a Function "alive" just to stay connected, and cold starts drop the Gateway link. Cloud Run's `min_instances=1` is the correct primitive: one warm container, cheap, Google-managed, free tier covers a single always-on instance (~`720 CPU-hours/month` per instance on the always-free tier with idle scaling billing still within the free monthly credits for a small bot).
- Outbound-only network fits Cloud Run without extra networking config.
- Secrets via GCP Secret Manager bound to the service at deploy time.
- Deploy via `gcloud run deploy` in a simple script (`scripts/deploy-triage-bot.sh`). Source-based deploys from the repo are fine for v1.
- HTTP `/health` and optional `/webhook/github-push` endpoints fall out of Cloud Run naturally — it already wants an HTTP server.

**Fallbacks** (any of these work; pick only if Cloud Run hits an unexpected wall):

| Host | Pros | Cons |
|---|---|---|
| Firebase Functions Gen 2, `minInstances: 1` | Google infra, shares Bee's Firebase project | Poor fit for long-lived WebSockets, more expensive for always-on than Cloud Run |
| Fly.io | Dead simple, great for always-on processes | Not Google infra |
| Home box (Windows) | Free, Duong controls it | Couples to a box that can reboot, loses the "runs anywhere" benefit, reintroduces supervisor complexity |

Firebase Functions is **not** recommended as the primary because of the WebSocket-vs-stateless-handler mismatch. Cloud Run is Google-native, keeps the Gateway connection warm, and gives a clean HTTP surface for health and webhooks.

## Compliance posture

Three bullets. That's the whole section.

- **Discord → Gemini.** Gemini API commercial terms explicitly permit building services on top of the API. The AI Studio free tier is the intended entry point for exactly this kind of hobby bot. No grey area.
- **Discord → GitHub.** Standard GitHub REST API use with a PAT. No policy wall.
- **Claude is not in this path.** Claude only runs downstream in the autonomous-delivery-pipeline, on Duong's own hardware under his own Max OAuth login, for jobs his own pipeline decides to pick up. That is identical in posture to any personal `claude` headless automation and is fully compliant with Anthropic Consumer ToS. The Discord bot has no Claude dependency, no Claude binary, no Claude credentials, and no code path that could be extended into one without a new plan.

The old Layer A/B/C table from the previous revision is deleted. It was only relevant while Claude sat in the Discord path.

## What survives from the previous revision

- `discord.js` + Gateway transport (outbound WebSocket).
- Bot token stored in `secrets/` and decrypted via `tools/decrypt.sh` (for local/dev).
- Reply-with-issue-URL convention.
- The general "Discord is a lightweight intake UI for a bigger system" framing.
- Event sanitization (strip XML-like tags, instruction-override patterns, cap message length).
- Health-ping pattern.

## What dies from the previous revision

- NSSM Windows service story.
- `~/.claude-runlock/claude.lock` coupling with Bee. Bee still needs the runlock for its own coupling with the pipeline (Syndra's plan); this plan is no longer a participant and makes no claims on that file.
- Home-box hardware prerequisites section (Windows, Node per-user install, etc.).
- Process-supervision dependency of any kind.
- Ownership of `architecture/claude-runlock.md`. **The doc itself stays in scope for the Bee plan** — Syndra's Bee revision will own it going forward. This plan does not touch it.
- The Scope A/B/C decision section.
- `claude` binary on PATH.
- Per-user Claude OAuth prerequisites.
- The `~/data/discord-events/` / `discord-responses/` / `discord-processed/` filesystem bus. There is no filesystem bus in this architecture — Discord message in, Gemini call, GitHub API call, Discord reply, done.
- The `claude --message` tiered invocation table.

## Scope

- **v1:** single product (MyApps), single subtree (`apps/myapps/`), single label (`myapps`), single channel. Target repo is whatever Strawberry checkout the bot runs inside. English only (Gemini handles multilingual fine but v1 makes no promises).
- **v2 extensions (out of scope here, noted for planning hygiene):**
  - Multi-product routing. The Strawberry monorepo may gain other `apps/*` subtrees; a second label + subtree wire would let one bot triage for multiple products. Needs per-product context caches and a product-routing section in each `triage-context.md`.
  - Multi-channel support with per-channel product mapping.
  - Reaction-based confirmations ("react to approve issue filing").
  - Interactive clarification before filing ("do you mean X or Y?" in Discord).
  - Cross-repo support if MyApps ever leaves the monorepo.

## Cross-references

- **`plans/proposed/2026-04-08-autonomous-delivery-pipeline.md`** — I read it. Its subsystem 1 ("Intake — Discord to GitHub Issue") already expects the discord-relay bot to file GitHub issues (option (a), "extend the existing discord-relay bot"). Its classifier and dispatcher subsystems then consume the issue. The pipeline assumes MyApps is its primary target — subsystem 5 explicitly runs PRs against `myapps`, and it cross-references `plans/approved/2026-04-05-myapps-task-list.md` and the myapps snapshot. **This plan's bot plays the role of that intake layer**, with one material difference: the pipeline plan envisioned "intentionally dumb at the bot layer — prefix parsing, classifier runs later as a separate Claude Haiku call." This plan replaces that with **Gemini-powered rich triage at the bot layer**, producing labels/priority/dedupe hints directly.

  **Does the pipeline watch MyApps issues?** The pipeline plan describes GitHub labels as state-of-record and expects issues to flow through its filesystem event bus, but the concrete "poll or webhook" mechanism for `issue.created` isn't pinned down in subsystem 2, and it doesn't explicitly filter by label (`myapps` vs. Strawberry-infra). This triage bot files issues with the `myapps` label so the pipeline can filter, but **the pipeline plan needs a small revision** to (a) make the GitHub-issue trigger concrete (webhook or poll), (b) filter to `label:myapps` so it doesn't accidentally pick up Strawberry-infra issues, and (c) mark its subsystem 3 classifier as optional-or-fallback since Gemini-side triage already produces the signal. I am not editing that plan here — noted for Evelynn to route.

- **`plans/approved/2026-04-05-myapps-task-list.md`** — the existing task list for MyApps. The autonomous-delivery-pipeline expects this to be the source of the first real issues. The triage bot is the human-facing path for *new* issues from Discord; the task list is the seed set the pipeline may chew through in parallel. No code coupling between the two — they both end up as GitHub issues with the `myapps` label.

- **`assessments/2026-04-08-myapps-snapshot.md`** — the current MyApps snapshot. The pipeline plan flags that this snapshot incorrectly claimed MyApps was in `apps/myapps/` as a divergent duplicate of a standalone repo. For *this* plan, `apps/myapps/` is the source of truth — we dump that subtree and file issues against the monorepo. If Duong later untangles the duplicate-repo situation, `TRIAGE_TARGET_SUBTREE` is the one place to adjust.

- **`plans/proposed/2026-04-09-sister-research-agent-karma.md`** — Bee is a fully separate plan with different architecture and different infrastructure. There is no longer any coupling between this plan and Bee beyond "both run somewhere Duong controls" and "both respect the secrets policy." The `claude-runlock.md` doc stays Bee's concern.

- **Max ToS research brief (2026-04-08).** The reason the Claude-in-Discord shape was killed. That brief is the canonical justification for this pivot; cite it in the commit body when this plan moves to approved.

## Open questions

1. **GitHub push webhook for context invalidation — worth it or skip?** The 6-hour timer is the baseline and is probably fine. The push webhook is a small extra HTTP endpoint on Cloud Run and makes the bot feel immediate after commits. Recommend shipping v1 with timer-only and adding the webhook in v1.1 once the bot is stable.
2. **Confirm the exact owner/name of the Strawberry repo on GitHub.** I've been writing `Duongntd/strawberry` throughout but the bot derives it at runtime via `gh repo view`, so the plan is correct regardless. This is only a confirmation so Duong can sanity-check the `gh` CLI login matches the intended remote, and so the `GITHUB_TOKEN` PAT is scoped to the right repo.
2b. **Confirm `apps/myapps/` remains the MyApps source of truth.** The myapps snapshot hinted at a divergent standalone repo. If MyApps moves out of the monorepo, `TRIAGE_TARGET_SUBTREE` changes (or, if it becomes a separate repo entirely, the bot needs to clone/pull it or switch to REST tree/blob reads — a v2 change).
3. **Does Duong want the bot to react-emoji on the originating Discord message in addition to replying?** A quick `✅` / `🔁` (deduped) / `⏳` (quota) / `❌` (error) gives instant visual signal without reading the reply text. Trivial to add. Recommend yes.
4. **Pipeline classifier overlap.** See the cross-reference above. Does Duong want the pipeline's Haiku classifier removed entirely now that Gemini does the job upstream, kept as a second opinion, or kept only for Gemini-failure fallbacks? My vote: remove for MVP, add back only if Gemini triage quality is measurably poor.
5. **Cost ceiling on Cloud Run.** `min_instances=1` with light traffic sits inside the always-free tier for most months but can tip over on heavy Discord activity or if the context cache rebuild is expensive. Recommend setting a GCP billing alert at $5/month as a safety rail and reviewing after the first month of real usage.
6. **Dedupe quality.** Gemini's `dupe_of_issue_number` decision is only as good as the "Open Issues Snapshot" we feed it. 50 open issues is plenty for a hobby repo now; if the backlog grows past ~200 open, we may need to switch to embedding-based retrieval instead of stuffing all open issues. Not urgent — v2 concern.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Gemini free-tier quota drained by abuse | Bot goes silent for the day | Daily cap with soft warning + hard reply; per-minute throttle |
| Prompt injection via Discord message | Gemini writes a hostile issue body | Input sanitization (strip tags/instruction-override patterns); strict JSON mode; labels constrained to the allowlist from `triage-context.md` |
| Gemini model deprecation | Bot crashes on Gemini call | Model ID pinned in one constant; health check flips red; swap and redeploy |
| Cloud Run cold start breaks Gateway | Missed messages during restart | `min_instances=1` holds a warm instance; health check catches any drop |
| GitHub PAT expiry | All filings fail | Use a fine-grained PAT with long expiry; health check catches the first 401 |
| Repo dump exceeds 1M tokens | Gemini rejects system prompt | Size guard in context loader: fail build, log, fall back to a minimal context (triage-context.md + open issues only), reply in Discord "operating in degraded context mode" |
| Discord bot token leak | Third party posts as the bot | Token in Secret Manager only; never logged; rotate on any suspicion |
| Issue spam from friends | GitHub inbox flooded | Channel-level permission is the control; if needed, tighten the Discord channel to a role |

## Deliverables (not an implementation checklist — pipeline phase ordering, not assignments)

1. Rework `apps/discord-relay/` in place: strip the filesystem-event-bus internals from the existing `src/index.js`, keep the Gateway wiring + sanitize helper + Express health server, convert to TypeScript, add `@google/generative-ai` and `@octokit/rest` to `package.json`.
2. `apps/myapps/triage-context.md` seeded with Duong's hand-written MyApps overview.
3. Context loader scoped to `apps/myapps/` subtree with 6-hour TTL and label-filtered open issues snapshot.
4. Gemini client with pinned model ID and strict JSON schema.
5. GitHub client with file-new-or-comment-on-dupe behavior.
6. Quota guard + per-minute throttle.
7. Observability JSONL logger.
8. HTTP `/health` endpoint.
9. `scripts/deploy-triage-bot.sh` — Cloud Run source deploy with Secret Manager bindings.
10. Smoke test: post a test message in the configured channel, verify issue filed, verify Discord reply, verify log entry.
11. Companion update to the autonomous-delivery-pipeline plan acknowledging Gemini-side triage (noted in cross-references — **Evelynn to route**, not assigned here).

Rule 8 compliance: this plan assigns no implementer. Evelynn decides delegation after Duong approves.
