---
status: approved
owner: azir
---

# Local Claude Code Usage Dashboard

## Goal

A local-first dashboard that answers one question Duong cannot answer today: **"Which Strawberry agents are burning my Max x20 quota, and when?"** Existing tools (`ccusage` CLI, the Reddit dashboard) show per-session and per-project tokens. None of them attribute usage to the Strawberry agent roster (Jayce, Viktor, Vi, Yuumi, Syndra, Ornn, Orianna, Evelynn, Azir, etc.). That attribution is the wedge — everything else (5h window, trends, cost comparison) is table stakes we get alongside.

v1 ships small on purpose: **one static page, local only, agent-attributed.** Trends, alerts, and Vercel hosting are v2+.

## Why Not Just Use `ccusage`?

`ccusage` is already installed (`/Users/duongntd99/.asdf/installs/nodejs/25.4.0/bin/ccusage`) and its JSON mode (`-j`) exposes daily/monthly/weekly/session/blocks with per-project breakdowns (`-i`, `-p`). It is the best available parser — and we will use it as the parsing engine, not replace it. What it does not do:

1. **No agent attribution.** `ccusage` groups by project directory. Strawberry sessions share one cwd (`~/Documents/Personal/strawberry`) but run as different agents. The agent identity is encoded in the transcript's first user message (`Hey Evelynn`, `[autonomous] Syndra, you have been launched...`, `You are Orianna`), not in cwd or metadata. `ccusage` does not read message content.
2. **No UI.** Terminal output is fine for spot checks, bad for spotting trends or hunting anomalies.
3. **No cross-project roll-up tuned to our two-repo / three-repo model** (strawberry + strawberry-app + work repos). We want one pane.

## Why Not Fork the Reddit Project?

OP had not published source as of the brief. Even if they do:

- Commenters flagged broken API-cost math, no time-series, no per-project, no export — we would rewrite most of it anyway.
- Their parser re-implements what `ccusage` already does correctly. Reusing `ccusage` as a subprocess is simpler than maintaining a parallel parser.
- **Zero agent-attribution hooks.** Our unique signal would have to be bolted on.

Conclusion: **reject fork.** Use it as inspiration only.

## Three Options Considered

| # | Option | Engine | UI work | Agent attribution | Verdict |
|---|--------|--------|---------|-------------------|---------|
| 1 | Fork Reddit project | Their parser | Medium (fix bugs + restyle) | Bolt-on | Reject — rewriting anyway |
| 2 | UI layer on `ccusage` | `ccusage -j` subprocess | Small (just the view) | Bolt-on via JSONL re-scan | **Recommended for v1** |
| 3 | Build parser from scratch | Custom JSONL reader | Large | First-class | v2+ if `ccusage` limits bite |

**v1 = Option 2.** Shell out to `ccusage -j` for tokens/cost/dates; run a small companion JSONL scanner *only* for agent attribution (cheap — we only need the first user message per session). If `ccusage` schema shifts, our agent scanner is still independently useful.

## Architecture (v1)

```
cron (every 10 min)
   |
   v
scripts/usage-dashboard/build.sh <!-- orianna: ok -->
   |-- ccusage session -j        -> session tokens, cost, model, cwd
   |-- ccusage blocks -j         -> 5h billing window state
   |-- ccusage daily -j          -> daily rollup for sparkline
   |-- agent-scan.mjs            -> { sessionId -> agentName } map <!-- orianna: ok -->
   |                                 (reads ONLY first user msg per JSONL)
   v
scripts/usage-dashboard/merge.mjs <!-- orianna: ok -->
   |-- joins ccusage JSON with agent map by sessionId
   |-- writes data.json          (<~200 KB for months of history)
   v
dashboards/usage-dashboard/      (static HTML + one JS file) <!-- orianna: ok -->
   |-- index.html                served from file:// by default <!-- orianna: ok -->
   |-- app.js                    fetch('./data.json'), render <!-- orianna: ok -->
   v
open file:///.../index.html      one-keystroke alias: `sbu` ("strawberry usage")
```

No server. No build step. No framework. One HTML file, one JS file, one `data.json`. Chart.js via CDN for sparklines (zero config, ~80 KB).

### Data Pipeline Detail

**`agent-scan.mjs`** (the only novel code):

```
for each .jsonl under ~/.claude/projects/**:
    open, read lines until first `type:"user"` record
    extract message.content[0].text
    match against patterns (in order, first win):
        /^Hey (\w+)/                                -> $1
        /^\[autonomous\] (\w+),/                    -> $1
        /^You are (\w+)[,.]/                        -> $1         (pinned prompts)
        /# (\w+) .* prompt \(pinned/                -> $1         (Orianna-style)
        fallback                                    -> "Evelynn"  (no-greeting default)
    emit { sessionId, agent, cwd, firstSeen }
write to: ~/.claude/strawberry-usage-cache/agents.json
```

Reading only first user line per file makes this O(sessions) not O(messages). Hundreds of sessions parse in under a second.

**`merge.mjs`** joins `ccusage session -j` output to `agents.json` by `sessionId`. Sessions with no agent match are bucketed as `unknown` (human-driven, not agent sessions — e.g., `login`, ad-hoc Duong sessions).

### Storage

All derived data lives under `~/.claude/strawberry-usage-cache/` — gitignored, local-only, regenerable. Never in repo.

### View (v1 scope)

One page, four stacked sections:

1. **5h billing window strip** — live countdown, tokens in/out/cache used, % of block, model breakdown. Read from `ccusage blocks -j`.
2. **Per-agent leaderboard (THE wedge)** — table sorted by tokens desc. Columns: agent, sessions, total tokens, input/output/cache split, cost-equivalent USD, avg tokens/session. One row per roster agent + `unknown` + totals.
3. **Per-project breakdown** — same shape, grouped by cwd (strawberry, strawberry-app, work/mmp, etc.).
4. **14-day sparkline** — one line per top-5 agents, tokens/day. Click a dot -> flat table of sessions for that agent/day.

No filters in v1 beyond "hide unknown." No date picker (show last 30 days fixed). No export (copy-paste from the table is enough for v1).

## Deployment Shape

**v1: static HTML, file://, no hosting.** Matches the constraint (Google + Claude free tier — no paid line items) and the local-first ethos. The transcripts never leave the laptop. No auth to worry about. Opening via `open` command (user-global rule).

**v2 consideration:** if Duong wants phone access, the right destination is `strawberry-app/dashboards/usage-dashboard/` deployed to Firebase Hosting (free tier) — the same pattern as test-dashboard. But that requires uploading usage data to Firestore, which is a different privacy posture (prompts can contain work data). v1 stays local to keep that decision deferrable.

Repo placement for v1:

- **Code**: `strawberry-app/dashboards/usage-dashboard/` — consistent with `dashboards/test-dashboard/` precedent. Static files only; no Cloud Run.
- **Scripts**: `strawberry-app/scripts/usage-dashboard/{build.sh, agent-scan.mjs, merge.mjs}`.
- **Crontab entry**: documented in plan, installed by `scripts/usage-dashboard/install-cron.sh`. <!-- orianna: ok --> Every 10 min. User-crontab, not root.

Both belong in `strawberry-app` (the public app repo) because they are code that ships; the agent-roster list they depend on is already public (agent definitions live in `agents/` which will migrate to the public `strawberry-agents` repo per `plans/approved/2026-04-19-public-app-repo-migration.md`).

**Agent roster source of truth:** one JSON file `dashboards/usage-dashboard/roster.json` seeded from `agents/memory/agent-network.md`. <!-- orianna: ok --> Regenerated by a CI script when the network file changes. Avoids hand-syncing.

## Features — v1 vs. Later

| Feature | v1 | v2 | v3 |
|---------|----|----|----|
| Per-agent leaderboard | yes (the wedge) | — | — |
| 5h window strip | yes | — | — |
| Per-project breakdown | yes | — | — |
| 14-day sparkline | yes | — | — |
| CSV/JSON export | — | yes | — |
| Date-range picker | — | yes | — |
| Alerts (quota / spike) | — | yes (email via free SMTP) | — |
| Hosted version (phone) | — | — | yes (Firebase, pending privacy call) |
| Per-task cost (inbox/MESSAGE correlation) | — | — | yes (needs message-thread model) |
| Cost vs. Max-value calculator | yes (static footer) | enhance w/ model-mix | — |
| Subagent-vs-main split | — | yes | — |

## Risks and Unknowns

- **`ccusage` schema drift.** We shell out and parse JSON; if keys rename upstream, our merge breaks silently. **Mitigation:** `merge.mjs` validates expected keys and fails loudly; pin `ccusage` version in `package.json` of the usage-dashboard directory.
- **Agent-name regex false negatives.** New agents added after v1 without matching greeting patterns will fall into `unknown`. **Mitigation:** roster.json becomes the authoritative list; `unknown` sessions get a one-line log in data.json so we can spot-check what we're missing.
- **Cost math accuracy.** Reddit commenters flagged this. `ccusage` does it right (verified by the `-m` mode flag and debug samples option). We do not recompute — we display what `ccusage` reports.
- **Multi-device sync.** Max x20 is one account, multiple devices. This dashboard only sees the local laptop's transcripts. Duong uses one Mac primarily, so v1 is correct for the 90% case. **Flag:** if Duong starts routinely coding from a second machine, v2 must aggregate across hosts (rsync the cache or upload to Firestore — decision deferred).
- **Privacy.** Transcripts contain prompts which may contain work content. v1 stays file:// precisely so nothing leaves the box. Any v2 hosting discussion must re-check this first.

## Handoff Notes (for Kayn/Aphelios, when this moves to approved)

- Reference implementations of interest: `ccusage` (we wrap it), `dashboards/test-dashboard/` in strawberry-app (same static-SPA shape, different data source), the Reddit post for UX inspiration only (do not port code).
- Task-1 candidate: scaffolding + `agent-scan.mjs` + roster.json generator. Small, testable in isolation.
- Task-2 candidate: `merge.mjs` + `build.sh` + cron installer.
- Task-3 candidate: `index.html` + `app.js` with Chart.js, the three-panel layout, styling matching test-dashboard.
- TDD-enabled (per CLAUDE.md rule 12): each task starts with an xfail test. Easy tests exist for `agent-scan.mjs` (fixture JSONLs) and `merge.mjs` (golden JSON). UI can use Playwright smoke matching test-dashboard precedent.

## Open Questions (for Duong)

1. **Infrastructure gate (per memory rule):** Are you OK with v1 being pure local (no hosting, no Firestore)? If yes, zero paid line items — confirmed free. If you want phone access on day 1, that flips to Firebase Hosting (free tier) + Firestore (free tier) but we need to green-light uploading transcript-derived data off the laptop.
2. **Repo placement:** confirmed `strawberry-app/dashboards/usage-dashboard/`? Or do you want it in the new `strawberry-agents` private repo since it is a Duong-only tool and transcripts have private context? (Counter-argument: it is code that could be open-sourced once agent-roster attribution is removed.)
3. **Agent attribution scope:** match only strawberry-repo sessions, or also `~/Documents/Work/mmp/workspace/agents/` (work agents)? v1 proposed = both, but bucketed separately in per-project view.
4. **Subagent cost:** JSONL has `isSidechain` for Task-tool subagents, but Strawberry agents run as top-level sessions and never tripped this flag in 50 transcripts sampled. Do you want a v2 story for Task-tool subagent attribution (different code path from roster attribution), or is that not how your usage works?
5. **Refresh cadence:** cron every 10 min vs. on-demand via `sbu` CLI alias. 10 min matches the Reddit reference and is free — any reason to go faster or slower?
6. **"Am I getting Max value?" math:** compute against on-demand API pricing for the same model mix (what `ccusage` already does) — confirm that's the number you want, or do you want subscription-vs-your-actual-blended-model-price?
7. **Retention:** keep `data.json` at unbounded history, or trim to last 90 days? v1 proposal = unbounded (file stays small — ccusage rollups compress years into a few hundred KB).
