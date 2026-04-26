---
date: 2026-04-26
author: lux
category: research
concern: personal
target: Claude Code statusline — display 5h + 7d usage windows
state: active
owner: lux
session: none
---

# Claude usage in the Claude Code statusline — research note

Goal: surface two rolling-window usage figures in the Claude Code statusline:
- **5h window** — Anthropic session quota cadence
- **7d window** — Anthropic weekly quota cadence

Investigation covered native Claude Code mechanisms, Anthropic API surface,
community plugins, and the OTel emission path. The TL;DR is at §Recommendation.

---

## §1 Native paths

### 1a. Statusline stdin JSON — the canonical surface

Claude Code invokes the configured statusline command on each render and feeds
it a JSON payload via stdin. The payload includes a documented set of fields
(session, workspace, cost, context_window) plus — and this is the load-bearing
finding — a `rate_limits` object on Pro/Max accounts:

```json
{
  "cwd": "...",
  "session_id": "...",
  "transcript_path": "...",
  "model": { "id": "...", "display_name": "..." },
  "workspace": { "current_dir": "...", "project_dir": "...", "added_dirs": [] },
  "version": "...",
  "output_style": "...",
  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_api_duration_ms": ...,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 8,
    "remaining_percentage": 92,
    "total_input_tokens": ...,
    "total_output_tokens": ...,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,
  "rate_limits": {
    "five_hour":  { "used_percentage": 23.5, "resets_at": 1738425600 },
    "seven_day":  { "used_percentage": 41.2, "resets_at": 1738857600 }
  }
}
```

Caveats per community write-ups:
- `rate_limits` appears **only on Claude.ai Pro/Max accounts** and **only after
  the first API response of the session**. On a brand-new session, the field
  may be absent for the first render or two.
- `resets_at` is a Unix epoch timestamp.
- `used_percentage` is a float; Anthropic does not expose absolute token counts
  for the quota windows here — only the percentage. (Sufficient for a
  statusline display; insufficient if you wanted absolute tokens-remaining.)

Sources for the schema: official statusline docs page
(https://code.claude.com/docs/en/statusline) and the curated AKCodez gist
(https://gist.github.com/AKCodez/ffb420ba6a7662b5c3dda2edce7783de).

The schema is also confirmed by `leeguooooo/claude-code-usage-bar`, which
explicitly states "rate-limit data comes directly from Anthropic's official
API headers exposed to Claude Code statusline commands through stdin."

### 1b. /cost — not pipeable for our purposes

`/cost` is an interactive slash command rendered into the TUI. It is not
designed to be invoked programmatically and shells out to the same accounting
the JSON `cost` object exposes. Not a viable statusline source.

### 1c. Environment variables during statusline rendering

The runtime exposes some `CLAUDE_*` and `ANTHROPIC_*` env vars during
statusline execution — `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY`,
`CLAUDE_CODE_DISABLE_AUTO_MEMORY`, `CLAUDE_CODE_EFFORT_LEVEL`,
`CLAUDE_CODE_DEBUG_LOG_LEVEL`, `ANTHROPIC_MODEL`,
`CLAUDE_CODE_SUBAGENT_MODEL`. **None expose usage or quota state.**

### 1d. Local state files

Claude Code maintains JSONL transcripts under
`~/.claude/projects/<project-slug>/<session-id>.jsonl`, recording every API
exchange with `usage` blocks (input_tokens, output_tokens, cache_*_tokens) per
turn. This is the substrate `ccusage` reads. Useful for **local computation of
arbitrary windows** but only reflects this user's CLI sessions — it does not
include any non-Claude-Code traffic on the same Anthropic account, so the 5h
and 7d totals derived this way will diverge from Anthropic's official
quota counters whenever you also use claude.ai chat or other API integrations.
Anthropic itself surfaces the authoritative quota numbers via the `rate_limits`
JSON field above.

Source for transcript path: ccusage docs and several community statusline
projects (`benabraham/claude-code-status-line`, `sirmalloc/ccstatusline`).

---

## §2 API paths

### 2a. The undocumented oauth/usage endpoint

Several community statuslines (notably `ohugonnot/claude-code-statusline`)
bypass the statusline JSON and call:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer $(jq -r .accessToken ~/.claude/.credentials.json)
```

This returns session (5h) and weekly (7d) quota utilisation as percentages
plus ISO-8601 reset timestamps — i.e. exactly the same shape as
`rate_limits.*` in the statusline JSON. The endpoint is **undocumented**;
Anthropic has made no commitment to keep it stable. Useful **only** if you
want to refresh the figure outside a statusline tick (e.g. from a separate
TUI panel or a dashboard).

### 2b. Documented Anthropic API

There is no documented public endpoint for "current 5h / 7d quota state."
Anthropic's documented usage/cost APIs target organisation-level admin
billing, not per-user quota windows.

### 2c. How does Claude Code itself know?

It learns from the response headers (`anthropic-ratelimit-*`) returned on
every Messages API call, then surfaces them through the statusline JSON. The
oauth/usage endpoint is a separate, internal-ish surface used by some other
Anthropic surfaces (claude.ai usage UI).

---

## §3 Community solutions

In rough order of relevance to our goal:

| Project | Source | Approach |
|---|---|---|
| `benabraham/claude-code-status-line` | github.com/benabraham/claude-code-status-line | Reads `rate_limits.five_hour` + `seven_day` from statusline JSON. Closest to native. |
| `ohugonnot/claude-code-statusline` | github.com/ohugonnot/claude-code-statusline | Calls undocumented `oauth/usage` endpoint. Caches in `~/.claude/usage-exact.json` ~60s TTL. |
| `daniel3303/ClaudeCodeStatusLine` | github.com/daniel3303/ClaudeCodeStatusLine | Hybrid — statusline JSON + Anthropic API; 60s cache. |
| `leeguooooo/claude-code-usage-bar` | github.com/leeguooooo/claude-code-usage-bar | Pure statusline-JSON consumer; renders ASCII progress bar. |
| `sirmalloc/ccstatusline` | github.com/sirmalloc/ccstatusline | Theme-rich powerline; supports rate_limits + ccusage block timer. |
| `levz0r/claude-code-statusline` | github.com/levz0r/claude-code-statusline | Cost + tokens; less focus on 5h/7d. |
| `ryoppippi/ccusage` | github.com/ryoppippi/ccusage | Reconstructs 5h "billing blocks" from local JSONL transcripts. Provides `ccusage statusline` subcommand. Not authoritative for account-level quota — only counts CLI usage. |

The `awesome-claude-code` list (hesreallyhim/awesome-claude-code) is the
canonical roll-up.

---

## §4 OTel telemetry path

`CLAUDE_CODE_ENABLE_TELEMETRY=1` enables OpenTelemetry export. Per the
official monitoring docs (https://code.claude.com/docs/en/monitoring-usage):

- **Metrics** (counters/gauges, default 60s export interval): token usage by
  category (input, output, cache_creation, cache_read), API cost, session
  count, session duration, lines added/removed.
- **Events/Logs** (default 5s interval): per-API-call and per-tool-execution
  snapshots with usage attached.
- Exporters: `otlp` (grpc/http), `prometheus`, `console`, `none`, configured
  via `OTEL_EXPORTER_OTLP_*` env vars.

What OTel **does not** emit: the `rate_limits.five_hour` / `seven_day`
percentages. The OTel surface gives you raw token counters per session/turn,
not Anthropic's quota-window state.

To use OTel for our 5h+7d display we would have to:
1. Stream OTel metrics into the existing JSONL retrospection pipe
   (DuckDB-over-JSONL, per the retrospection-dashboard plan).
2. Compute rolling 5h and 7d sums of `claude_code.token.usage` from this
   source.
3. Accept that the figures count **only** local Claude Code traffic, not
   account-wide usage (same caveat as ccusage). Therefore they are useful as a
   "how much have I burned in this CLI today" gauge, but NOT as a
   "am-I-about-to-hit-Anthropic's-quota-wall" gauge — the statusline JSON
   `rate_limits` block is the only source for the latter.

The OTel route does, however, align with the retrospection-dashboard work
already on our roadmap, and its data is **persistent** across sessions — the
`rate_limits` field lives only in stdin per-render. If we want history /
trend lines / per-day burn charts, OTel is the path; if we want a live
statusline number, `rate_limits` is the path.

---

## §5 Recommendation

**Primary path — statusline stdin JSON, `rate_limits.five_hour` and
`rate_limits.seven_day`.** This is the cleanest, lowest-risk, no-extra-network
solution. It uses the data Claude Code already pushes to every statusline
invocation and reflects Anthropic's authoritative quota state.

Effort estimate: **~1-2 hours.**
- Write a tiny POSIX-portable script (jq + printf) that reads stdin, extracts
  `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage`,
  and the `resets_at` epochs, and prints a one-line summary like:
  `5h 23% (resets 14:30) | 7d 41% (resets Wed)`.
- Wire it via `~/.claude/settings.json` `statusLine.command`.
- Defensive: handle `rate_limits` being absent (fresh session, non-Pro/Max
  account) by falling back to `--` placeholders.
- Optional: add a coloured progress bar (ANSI), red >80%, yellow 50-80%.

**Secondary path — graceful degradation via undocumented oauth/usage.**
Add **only if** the primary path proves flaky (e.g. `rate_limits` field too
often absent on slow first-turn renders). Cache to `~/.claude/usage-exact.json`
with 60s TTL to stay polite. Cost: another ~2 hours plus ongoing fragility
risk if Anthropic deprecates the endpoint. **Do not adopt unless required.**

**Tertiary path — OTel + retrospection dashboard.** Keep this for the
broader "usage history" and "burn-rate trends" use case, not for the live
statusline figure. It is complementary, not a substitute. Its 5h/7d window is
CLI-local and therefore lower-fidelity than `rate_limits.*`.

**Do not** adopt `ccusage`-style transcript reconstruction as the live
source: it duplicates information Anthropic already gives us, drifts from
account-truth whenever the user uses claude.ai web, and adds I/O cost on
every statusline tick.

### Concrete next step

Hand off to the implementation agent with a one-paragraph spec:
> "Write a POSIX bash + jq statusline script that reads JSON on stdin and
> emits a single line containing model name, context_window.used_percentage,
> rate_limits.five_hour.used_percentage with countdown to resets_at, and
> rate_limits.seven_day.used_percentage with countdown. Fall back to `--`
> when fields are missing. Wire via `~/.claude/settings.json` and include a
> short README under `architecture/` documenting field semantics and the
> Pro/Max-only caveat."

---

## Sources

- [Customize your status line — Claude Code docs](https://code.claude.com/docs/en/statusline)
- [Monitoring — Claude Code docs](https://code.claude.com/docs/en/monitoring-usage)
- [Issue #52089 — expose session token usage to hooks/statusline](https://github.com/anthropics/claude-code/issues/52089)
- [Issue #11535 — expose token usage data to statusline scripts](https://github.com/anthropics/claude-code/issues/11535)
- [Issue #8861 — add token usage details to statusline API](https://github.com/anthropics/claude-code/issues/8861)
- [Statusline JSON schema reference gist (AKCodez)](https://gist.github.com/AKCodez/ffb420ba6a7662b5c3dda2edce7783de)
- [benabraham/claude-code-status-line](https://github.com/benabraham/claude-code-status-line)
- [ohugonnot/claude-code-statusline (oauth/usage endpoint approach)](https://github.com/ohugonnot/claude-code-statusline)
- [daniel3303/ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine)
- [leeguooooo/claude-code-usage-bar](https://github.com/leeguooooo/claude-code-usage-bar)
- [sirmalloc/ccstatusline](https://github.com/sirmalloc/ccstatusline)
- [levz0r/claude-code-statusline](https://github.com/levz0r/claude-code-statusline)
- [ryoppippi/ccusage (transcript-derived)](https://github.com/ryoppippi/ccusage)
- [ccusage statusline guide](https://ccusage.com/guide/statusline)
- [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [Dan Does Code — building a custom statusline](https://www.dandoescode.com/blog/claude-code-custom-statusline)
- [codelynx — show Claude Code usage limits in statusline](https://codelynx.dev/posts/claude-code-usage-limits-statusline)
- [SigNoz — Claude Code monitoring with OpenTelemetry](https://signoz.io/blog/claude-code-monitoring-with-opentelemetry/)
