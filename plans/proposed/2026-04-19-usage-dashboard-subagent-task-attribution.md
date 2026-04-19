---
status: proposed
owner: azir
date: 2026-04-19
extends: plans/approved/2026-04-19-claude-usage-dashboard.md
---

# Usage Dashboard — Per-Subagent Per-Task Token Attribution

## Goal

Extend the approved Claude usage dashboard with a new view that answers:

> "For every subagent Evelynn spawned, which task was it working on and how many tokens did it burn?"

Concrete examples Duong wants to see:

- Ekko burned 60k tokens on the PR #25 CI-loop task.
- Yuumi burned 28k tokens on the DTD resolution.
- Vi burned X on the E2E diagnosis.

This is a second-order wedge on top of the existing roster-attribution wedge. The existing dashboard groups tokens by agent across all work. This extension groups tokens by agent × task — so Duong can spot loops, runaways, and disproportionate task cost.

## Capability Check — Hook vs. Transcript vs. JSONL

Before choosing a capture mechanism, I verified what data is actually reachable.

### SubagentStop hook input (verified against Claude Code docs)

```
{
  "session_id":            "<parent session>",
  "transcript_path":       "~/.claude/projects/<slug>/<session>.jsonl",
  "cwd":                   "<pwd>",
  "permission_mode":       "default",
  "hook_event_name":       "SubagentStop",
  "stop_hook_active":      false,
  "agent_id":              "<subagent id>",
  "agent_type":            "<agent name, e.g. Vi>",
  "agent_transcript_path": "~/.claude/projects/<slug>/<session>/subagents/agent-<id>.jsonl",
  "last_assistant_message":"<subagent final reply text>"
}
```

**Explicitly missing:** `tokens_in`, `tokens_out`, `usage`, `cost`, `stop_reason`. The hook payload has no usage fields. Confirmed at `https://code.claude.com/docs/en/hooks`.

**Explicitly present and load-bearing:** `agent_type` (the roster name), `agent_id` (unique per spawn), `agent_transcript_path` (points at a JSONL that DOES contain usage data), and the sibling file `agent-<id>.meta.json`.

### Subagent transcript files (verified empirically against local cache)

Spot-checked `~/.claude/projects/-Users-duongntd99-Documents-Personal-strawberry-agents/1283cce9-.../subagents/`. Each spawn writes two files:

- **`agent-<id>.jsonl`** — full subagent conversation. Every assistant line carries:

  ```
  "usage": {
    "input_tokens": N,
    "cache_creation_input_tokens": N,
    "cache_read_input_tokens": N,
    "output_tokens": N,
    "server_tool_use": { "web_search_requests": N, "web_fetch_requests": N },
    "cache_creation": { "ephemeral_5m_input_tokens": N, "ephemeral_1h_input_tokens": N }
  }
  ```

  Plus `timestamp`, `model`, `isSidechain:true`, `cwd`, `sessionId` (parent), `agentId`, and the first user message (the verbatim Evelynn prompt — which carries the task identity).

- **`agent-<id>.meta.json`** — two-field sidecar:

  ```
  { "agentType": "Vi", "description": "Execute P1.4 first xfail Vitest" }
  ```

  `description` is the Task tool's short label (<= ~80 chars). This is the canonical human-readable task handle.

This is the bedrock finding: **the data exists, fully labeled, on disk, per-spawn, with zero code changes.** We do not need Duong's SubagentStop-capture plan at all. We need a scanner.

## Decisions

### D1. Capture mechanism — **post-hoc scanner over `subagents/` directory**

Reject the SubagentStop-hook-captures-tokens approach: the hook payload has no usage fields. It would work only as a cue to run a scanner — which we do not need, because the scanner can run on the same cron cadence as the existing `build.sh` pipeline.

Reject the "subagent writes a sidecar during `/end-subagent-session`" approach: (a) not every subagent runs the skill — Yuumi, Skarner, and any bare `Task()` spawn with no agent frontmatter do not; (b) it adds a moving piece to the skill that could silently drift; (c) redundant given the JSONL and meta.json already exist.

**Chosen:** a new scanner `subagent-scan.mjs` that walks `~/.claude/projects/**/<session>/subagents/`. For each `agent-<id>.jsonl` + `agent-<id>.meta.json` pair it emits one record (schema in D4). Runs on the existing `build.sh` cron (every 10 min) right after `agent-scan.mjs`.

Rejected alternatives:

| Option | Rejected because |
|---|---|
| SubagentStop hook captures tokens directly | Hook payload has no usage data (verified in docs). Would need a sub-scanner of the JSONL anyway. |
| SubagentStop hook triggers the scanner | Scanner on cron is simpler, handles non-hook spawns (bare `Task()`, crashed subagents), and idempotent. |
| Subagent writes sidecar in `/end-subagent-session` | Stateless agents (Yuumi, Skarner) skip the skill. Silently loses ~X% of spawns. |
| Parse `claude cost` output | `cost` has no per-subagent granularity; stops at session level. |
| Fork `ccusage` | `ccusage` reads flat session JSONLs, not the nested `subagents/` structure. Adding this upstream is out of scope. |

### D2. Task identity — **use `description` from `agent-<id>.meta.json` verbatim**

The Task tool already writes a `description` field into the meta sidecar (Evelynn-style: "Execute P1.4 first xfail Vitest", "Resolve DTD merge conflict", etc.). This is exactly the human-readable handle Duong wants to see in the leaderboard.

Reject "hook looks up TaskList for owner=<agent>": TaskList is the delegation audit trail (per commit `3c7d3c4`), but TaskList IDs are not in the meta.json or the JSONL. Correlating would require Evelynn to write a task-id into the Agent-tool prompt and the subagent to echo it — two new moving pieces. Not worth it given `description` already nails the use case for the dashboard.

Reject "Evelynn threads task ID into the prompt, subagent echoes it back": same reason, plus every roster prompt template would need to change. The dashboard is a read-only observability tool; it should not reach into the delegation protocol.

**Fallback for edge cases:**

- No meta.json (unusual — old/crashed spawns): fall back to the first user message in the JSONL truncated to 80 chars.
- `agentType` missing: fall back to matching first user message against the existing `roster.json` patterns (reuse `agent-scan.mjs`'s regex set).
- `description` empty: label as `unlabeled-<agent-id-short>` so it is still grouped, not dropped.

### D3. Storage — **same cache dir, new file**

`~/.claude/strawberry-usage-cache/subagents.json`. Parallel to the existing `agents.json`. Same gitignored, local-only, regenerable posture. Same JSON shape conventions.

Separate file (not merged into `agents.json`) because:

- Different cardinality — one spawn per row, vs. one roster-agent per row.
- Different lifetime — we may want to trim subagent history more aggressively than top-level session history.
- The existing `merge.mjs` schema is stable and approved; extending it vs. adding a parallel file is a lower-risk change.

Reject Firestore: the approved dashboard is explicitly local-first and file:// to keep transcript-derived data on the laptop. Subagent prompts contain even richer task context than top-level sessions — uploading them off-box flips the privacy posture for a v2 feature. Defer.

### D4. Schema — per-spawn record

```
{
  "spawn_id":         "a142121c740c050bc",              // from agentId in meta/JSONL
  "parent_session_id":"1283cce9-a907-44a6-b273-...",   // parent top-level session
  "parent_agent":     "Evelynn",                        // resolved via agents.json (agent-scan.mjs)
  "agent":            "Vi",                             // from meta.agentType
  "task":             "Execute P1.4 first xfail Vitest",// from meta.description
  "model":            "claude-sonnet-4-6",              // from last assistant line
  "tokens_in":        N,                                // sum(input_tokens)
  "tokens_out":       N,                                // sum(output_tokens)
  "cache_creation":   N,                                // sum(cache_creation_input_tokens)
  "cache_read":       N,                                // sum(cache_read_input_tokens)
  "total_tokens":     N,                                // tokens_in + tokens_out + cache_creation (NOT cache_read — it's not billed as new)
  "tool_uses":        N,                                // count of tool_use blocks in JSONL
  "duration_ms":      N,                                // last_ts - first_ts
  "started_at":       "2026-04-18T18:52:33.266Z",      // first JSONL timestamp
  "ended_at":         "2026-04-18T19:07:11.102Z",      // last JSONL timestamp
  "cwd":              "/Users/.../strawberry-agents",   // from JSONL first entry
  "git_branch":       "main",                           // from JSONL first entry if present
  "closed_cleanly":   true,                             // /end-subagent-session sentinel observed? (optional, nice-to-have)
  "jsonl_path":       "~/.claude/projects/.../subagents/agent-a142.jsonl"  // for drill-down
}
```

Fields worth adding beyond Duong's minimum list:

- `cache_creation` / `cache_read` — split out because cache reads are cheap; conflating them with fresh input tokens makes loops look worse than they are. Duong's "PR #25 CI loop" case specifically will hit heavy cache reads, and we want to visually distinguish "burned 60k fresh tokens" from "burned 60k but 50k was cache re-read."
- `parent_session_id` + `parent_agent` — lets us aggregate "how much did Evelynn delegate today" vs. "how much did Vi burn across all parents."
- `model` — Sonnet vs. Opus token weights matter for the cost math.
- `jsonl_path` — drill-down link from the dashboard row to the raw transcript.

### D5. Aggregator and view — **new panel on the existing dashboard**

Same page, new stacked panel under the four existing sections. Not a separate tab. Rationale: keep one file:// URL, one keystroke (`sbu`), one pane. The existing layout has room.

**Panel 5 — Subagent tasks (last 7 days)**

Table, default-sorted by `total_tokens` desc, columns:

- Agent (roster badge color)
- Task (the `description` string, truncated with tooltip for full)
- Tokens (total, with a `[in / out / cache]` micro-breakdown on hover)
- Tool uses
- Duration (human-readable)
- Parent (Evelynn shard id or top-level session, link)
- Started at

Group-collapse toggle: group by agent (shows one row per agent with sum + expand), group by task (one row per task string — catches loops where the same task spawned N times), or flat.

No date picker in v2. Last-7-days fixed window. Add picker if the table gets unwieldy.

### D6. Backfill — **forward-only with opportunistic scan of existing JSONLs**

The scanner runs on the first cron tick after deploy. It naturally processes every `subagents/` directory under `~/.claude/projects/` — there is no "new data" vs. "old data" distinction; the JSONLs are all already there.

Duong's local cache already has thousands of subagent spawns on disk. The scanner will surface all of them on first run. This is not "backfill" in the retroactive-instrumentation sense — we are just reading what the harness already wrote.

So **backfill is implicit and free.** No separate task needed.

Trim policy: keep all spawns in `subagents.json` until the file exceeds 10 MB (sparklines + leaderboard only need aggregates; raw rows are for drill-down). Then drop the oldest by `ended_at`. Revisit if 10 MB fills up faster than 90 days.

### D7. Attribution edge cases — explicit handling

| Case | Handling |
|---|---|
| Subagent runs without `/end-subagent-session` | Still captured. Scanner reads the JSONL and meta.json — neither depends on the sentinel file. `closed_cleanly:false` noted in the row (see optional field in D4). |
| Stateless agents (Yuumi, Skarner) | Same as above. They never write a sentinel but they do write JSONLs. Fully captured. |
| Multiple tasks in one spawn | Modeled as one row. The `description` is whatever Evelynn passed at spawn time. If Evelynn re-purposes a subagent mid-flight (rare; violates the one-task-per-spawn delegation rule), the row reflects the original task label. This is the right trade — forcing the scanner to detect mid-spawn topic shifts would be brittle LLM territory. |
| Tasks created mid-spawn (TaskCreate fired inside a subagent) | Not a thing on our roster (subagents do not spawn subagents; Strawberry uses one-level delegation). If it becomes a thing, revisit — currently out of scope. |
| Crashed / aborted subagents (no final assistant message) | JSONL still ends at the last assistant turn. Tokens up to that point counted. `ended_at` = last assistant ts. Flag with `closed_cleanly:false`. |
| Bare `Task()` with no agent frontmatter | `meta.agentType` is still populated by the harness (it names the tool type). Rows land under `agent:"<tool-type>"` if no roster match; acceptable fallback. |
| Parent session compacted / resumed | Scanner keys by `agent_id` (unique per spawn), not session_id. Compaction of parent does not corrupt subagent rows. |
| Concurrent scanners (Evelynn-shard A and B both running `build.sh` against the same cache dir) | Scanner is read-only on JSONLs and writes via temp-file + rename on `subagents.json`. Idempotent. Existing `build.sh` already has this shape for `agents.json`. |

### D8. Relationship to TaskList audit trail

Out of scope for this ADR. TaskList is the authoritative delegation log; this dashboard is observability. If Duong later wants to correlate TaskList entries (with their richer status + owner + subject fields) to token cost, that is a v3 join — needs Evelynn to write task IDs into Agent-tool prompts, and needs the subagent scanner to extract them from the first user message. Doable, not needed for this wedge.

## Scope Delta vs. Approved Plan

This ADR adds, not replaces:

- New script: `scripts/usage-dashboard/subagent-scan.mjs` (lives in `strawberry-app/scripts/usage-dashboard/` per approved-plan placement).
- New data file: `~/.claude/strawberry-usage-cache/subagents.json`.
- `build.sh` gains one extra step (runs subagent-scan after agent-scan).
- `merge.mjs` gains a pass that attaches subagent rows into the final `data.json` under a new `subagents:` key.
- `index.html` + `app.js` gain Panel 5.
- `roster.json` unchanged — existing agent list is reused.

No changes to approved plan §Architecture, §Storage location, or §Deployment shape. Still file://, still cron every 10 min, still zero paid line items.

## Risks

- **Meta.json format drift.** Claude Code could rename `agentType` or drop `description`. Scanner validates both keys and falls back to JSONL inference (as in D2) rather than dropping the row. Add a loud console warning if the fallback fires; surface on dashboard as a "N spawns partially attributed" banner.
- **Cache-token classification.** `ccusage` computes "total tokens" one way; our `total_tokens` in D4 excludes cache reads to avoid double-counting loop re-reads. If a user compares the sum against `ccusage` they will see a discrepancy. Call this out in the dashboard footer: "Total excludes cache-read tokens; see ccusage for wall-total."
- **Disk growth.** `~/.claude/projects/**/subagents/` grows unbounded. We do not garbage-collect it — that is the harness's job. If Duong's disk fills, that is a harness issue, not this dashboard's.
- **Scanner cost.** Reading every subagent JSONL every 10 min is O(spawns × avg-size). Mitigation: cache per-file `mtime` in `subagents.json`; skip rescan if mtime unchanged. Already-closed JSONLs are immutable, so this is a huge win after the first run.

## Open Questions (for Duong)

1. **Task-identity fallback:** confirm `description` from meta.json is the right handle vs. the first line of the Evelynn prompt truncated to 80 chars. They are usually similar; when they diverge the first-line is more verbose ("Execute P1.4 of the deployment-pipeline plan: write the first failing..." vs. "Execute P1.4 first xfail Vitest"). I recommend `description` for brevity; happy to flip if you want the fuller label.
2. **Retention:** is the 10 MB / 90-day soft cap on `subagents.json` right? You can easily afford 100+ MB on a Mac; the constraint is really "don't make `data.json` too big for the browser to swallow in one `fetch`." If you want me to trim harder, say so.
3. **Panel placement:** new panel at the bottom of the existing page, or do you want subagent rows woven into the per-agent leaderboard (Panel 2) as drill-down expando rows? Weave is prettier, bottom-panel is cheaper to build. I lean bottom-panel for v1-of-this-feature; weave as a v2 polish pass.
4. **Group-by default:** default to flat, by-agent, or by-task? I lean by-task because the wedge story ("PR #25 CI loop burned 60k") is a task-grouped story. Let me know.
5. **Task-ID hook into TaskList:** defer to a later ADR, or add to this one? I kept it out of D8 because it requires touching Evelynn's prompt plumbing and the delegation protocol — larger blast radius than an observability-only change. Happy to do it as a follow-up if you want the correlation.
6. **Cost of `closed_cleanly`:** the sentinel `/tmp/claude-subagent-<sid>-closed` is the signal. But scanner runs on cron, after the sentinel may have been cleaned up by the SubagentStop hook. If you want this field reliable, we need the SubagentStop hook to persist the signal (e.g., write a file into the cache dir instead of `/tmp`). Low-value field; drop it if we do not want to touch the hook.
7. **Scope of subagent spawns to track:** every spawn across all `~/.claude/projects/`, or filter to strawberry-agents + strawberry + strawberry-app? Approved plan tracks both work and personal projects in one pane (bucketed). I default to same-behavior: all projects, bucket by cwd. Confirm.

## Handoff Notes (for Kayn/Aphelios, once approved)

- Scanner is small: under 200 LOC. Shape mirrors `agent-scan.mjs` — read dir, parse JSONL header + assistant lines with `usage`, read meta.json, emit record, write atomically.
- Golden-test fixture: capture one real `subagents/<id>.jsonl` + `meta.json` pair (scrub prompt content), write expected output JSON, golden-diff in Vitest. Easy xfail candidate per rule 12.
- `merge.mjs` change is a one-liner: `data.subagents = JSON.parse(readFileSync(cacheDir + 'subagents.json'))`.
- UI change is one `<section>` in `index.html` + a render function in `app.js` that pivots the array into the table. No new deps — reuse existing Chart.js import (unused in this panel, fine).
- Commit identity: this ships in the public app repo (`strawberry-app`) under `apps/**`-adjacent paths (scripts + dashboards), so normal PR-to-main flow with `chore:` or `feat:` prefix per rule 5 (feature-add → `feat:`).
- TDD-enabled: xfail the scanner golden test before the implementation lands (rule 12).
- Suggested task slices: (T1) scanner + golden test; (T2) merge.mjs wiring + build.sh step; (T3) Panel 5 UI. Each independently testable.

## References

- Approved parent: `plans/approved/2026-04-19-claude-usage-dashboard.md`.
- Hook docs: `https://code.claude.com/docs/en/hooks` (SubagentStop payload — no usage fields).
- Existing hook wiring: `.claude/settings.json` (SubagentStart/SubagentStop already present from `plans/approved/2026-04-11-subagent-stop-hook.md`).
- TaskList delegation trail: commit `3c7d3c4` (PostToolUse Agent-matcher reminder hook).
- Evidence of usage data in subagent JSONLs: verified against `~/.claude/projects/-Users-duongntd99-Documents-Personal-strawberry-agents/1283cce9-a907-44a6-b273-4323c143cab4/subagents/agent-a142121c740c050bc.{jsonl,meta.json}`.
