---
status: approved
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

## Phases — v1 Capture vs. v2 Dashboard [Added 2026-04-19]

Duong's 2026-04-19 amendment: split this ADR into two independently shippable phases. Ship v1 immediately to stop ongoing signal loss (the `closed_cleanly` sentinel lives in `/tmp` today and evaporates at reboot/cleanup). v2 can follow when UI budget opens.

### v1 — Capture pipeline (ship now)

**Goal:** persist every byte of subagent attribution data to disk in a structured form, so no data is lost while v2 is still in flight.

| Component | Reference |
|---|---|
| SubagentStop hook amendment — sentinel into `~/.claude/strawberry-usage-cache/subagent-sentinels/<agent_id>` (replaces `/tmp`) | D9 |
| `subagent-scan.mjs` scanner — walks `~/.claude/projects/**/subagents/`, emits per-spawn records | D1 |
| Cron wiring — scanner runs after `agent-scan.mjs` in the existing `build.sh` tick (every 10 min) | D1 |
| Aggregate schema — per-spawn record, stored in `subagents.json` | D4 |
| Retention / cap enforcement — 10 MB / 90 d trim on `subagents.json`; sentinels garbage-collected on the same cadence | D6, D9 |
| `closed_cleanly` wiring — scanner correlates sentinel presence with JSONL rows | D9 |
| Mtime cache for incremental scan — skip closed JSONLs on subsequent ticks | Risks §Scanner cost |

v1 ships without a consumer UI. The data accumulates in `subagents.json` and is inspectable via `jq` / any JSON viewer until v2 lands.

### v2 — Dashboard UI (follow-up)

**Goal:** surface the v1 data on the existing file:// dashboard so Duong can see loops and runaways at a glance.

| Component | Reference |
|---|---|
| `merge.mjs` attaches `subagents.json` into `data.json` under a `subagents:` key | §Scope Delta |
| Panel 5 rendering in `index.html` + `app.js` | D5 |
| Group-by toggle — agent / task / flat; default task | D5 |
| "Show all" toggle — reads raw JSONLs to bypass the aggregate cap, optionally via a lazy `subagents-full.json` | D5, D6 |
| Drill-down tooltip + micro-breakdown `[in / out / cache]` | D5 |

v2 is pure read-path on top of v1 output. No new capture primitives; no changes to the hook or scanner.

### Risk of v1-without-v2

Accepted. We accumulate structured attribution data with no visual consumer for some period. Trade-off justification:

- The **alternative is worse:** without v1, the `/tmp` sentinel keeps evaporating and we permanently lose the `closed_cleanly` signal for every spawn that ran during the gap. That data cannot be reconstructed after the fact.
- `subagents.json` is small (mtime-cached scanner keeps it cheap) and gitignored, so carrying it on disk between v1 and v2 is free.
- A curious user can `jq` the file any time to answer the wedge question ad hoc; the dashboard is ergonomics, not novel capability.
- v1 is also the bigger testing surface — getting the scanner + hook right while the UI is still a spec reduces regression risk when Panel 5 lands.

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

### D2. Task identity — **use `description` from `agent-<id>.meta.json` verbatim** [Resolved 2026-04-19]

The Task tool already writes a `description` field into the meta sidecar (Evelynn-style: "Execute P1.4 first xfail Vitest", "Resolve DTD merge conflict", etc.). This is exactly the human-readable handle Duong wants to see in the leaderboard. **Confirmed by Duong 2026-04-19: use `description` verbatim.**

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
  "closed_cleanly":   true,                             // /end-subagent-session sentinel observed? (INCLUDED — see D9 for hook prerequisite)
  "jsonl_path":       "~/.claude/projects/.../subagents/agent-a142.jsonl"  // for drill-down
}
```

Fields worth adding beyond Duong's minimum list:

- `cache_creation` / `cache_read` — split out because cache reads are cheap; conflating them with fresh input tokens makes loops look worse than they are. Duong's "PR #25 CI loop" case specifically will hit heavy cache reads, and we want to visually distinguish "burned 60k fresh tokens" from "burned 60k but 50k was cache re-read."
- `parent_session_id` + `parent_agent` — lets us aggregate "how much did Evelynn delegate today" vs. "how much did Vi burn across all parents."
- `model` — Sonnet vs. Opus token weights matter for the cost math.
- `jsonl_path` — drill-down link from the dashboard row to the raw transcript.

### D5. Aggregator and view — **new Panel 5 at the bottom of the existing dashboard** [Resolved 2026-04-19]

Same page, new stacked panel under the four existing sections — explicitly a new Panel 5 at the bottom. Not a separate tab. Rationale: keep one file:// URL, one keystroke (`sbu`), one pane. The existing layout has room. **Confirmed by Duong 2026-04-19: bottom-panel v1; weaving into Panel 2 stays as a v2 polish pass (not blocking).**

**Panel 5 — Subagent tasks (last 7 days)**

Table, default-sorted by `total_tokens` desc, columns:

- Agent (roster badge color)
- Task (the `description` string, truncated with tooltip for full)
- Tokens (total, with a `[in / out / cache]` micro-breakdown on hover)
- Tool uses
- Duration (human-readable)
- Parent (Evelynn shard id or top-level session, link)
- Started at

**Group/filter controls [Resolved 2026-04-19]:** support BOTH group-by-agent AND group-by-task as first-class toggles. User flips between them with a control at the panel head. Default grouping is **by-task** (aligns with the wedge story — "PR #25 CI loop burned 60k"); a flat (ungrouped) mode is also available.

**Retention toggle [Resolved 2026-04-19]:** default view is the last-7-days window backed by the 10 MB / 90 d trimmed `subagents.json` (see D6). Panel head also carries a **"show all"** toggle that re-reads directly from the raw JSONLs in `~/.claude/projects/**/subagents/` — bypassing the on-disk aggregate cap entirely. Scanner's trim policy is unchanged; the toggle is a read-path choice on the UI side (via an on-demand `subagent-scan-full.mjs` or client-side `fetch` of a second data file `subagents-full.json` generated lazily). Cache stays lean; "show all" accepts the slower load cost.

No date picker in v2. Last-7-days fixed window in the default view, unbounded in "show all." Add picker if the table gets unwieldy.

### D6. Backfill — **forward-only with opportunistic scan of existing JSONLs**

The scanner runs on the first cron tick after deploy. It naturally processes every `subagents/` directory under `~/.claude/projects/` — there is no "new data" vs. "old data" distinction; the JSONLs are all already there.

Duong's local cache already has thousands of subagent spawns on disk. The scanner will surface all of them on first run. This is not "backfill" in the retroactive-instrumentation sense — we are just reading what the harness already wrote.

So **backfill is implicit and free.** No separate task needed.

Trim policy [Resolved 2026-04-19]: keep all spawns in `subagents.json` until the file exceeds **10 MB or 90 days**, then drop oldest by `ended_at`. This is the on-disk aggregate cap only — the dashboard's "show all" toggle (see D5) sidesteps the cap by reading directly from the raw JSONLs in `~/.claude/projects/**/subagents/`, which are never trimmed by this pipeline (harness owns their lifetime). Confirmed by Duong: trim the aggregate cache aggressively, but preserve user access to the full history via the UI toggle.

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

### D8. Relationship to TaskList audit trail [Resolved 2026-04-19 — deferred]

Out of scope for this ADR. TaskList is the authoritative delegation log; this dashboard is observability. **Confirmed by Duong 2026-04-19: defer TaskList correlation to a later ADR.** If Duong later wants to correlate TaskList entries (with their richer status + owner + subject fields) to token cost, that is a v3 join — needs Evelynn to write task IDs into Agent-tool prompts, and needs the subagent scanner to extract them from the first user message. Doable, not needed for this wedge.

### D9. `closed_cleanly` field and SubagentStop hook amendment [Resolved 2026-04-19 — include]

Duong confirmed the `closed_cleanly` field is high-value / low-cost and must be included. Currently the `/end-subagent-session` skill writes a sentinel to `/tmp/claude-subagent-<sid>-closed`, which is unreliable across reboots and can be cleaned up before the cron scanner runs.

**Prerequisite task — amend `.claude/settings.json` SubagentStop hook** to persist the sentinel into a durable location inside the cache dir:

```
~/.claude/strawberry-usage-cache/subagent-sentinels/<session_id>
```

The scanner reads these sentinel files (keyed by `agent_id` / `session_id` per the SubagentStop payload in §Capability Check) and populates `closed_cleanly:true` for matched rows. Absent sentinel → `closed_cleanly:false` (crashed, aborted, or stateless spawn that never ran the skill).

Implementation notes for the hook amendment:

- The SubagentStop hook already fires with `session_id` + `agent_id` in its payload (verified in §Capability Check).
- The amendment is a one-liner in the hook command: `mkdir -p ~/.claude/strawberry-usage-cache/subagent-sentinels && touch ~/.claude/strawberry-usage-cache/subagent-sentinels/<agent_id>` (or embed `session_id:agent_id` in the filename for easier correlation).
- The `/end-subagent-session` skill can keep its existing `/tmp` sentinel as a belt-and-suspenders signal, but the cron scanner only reads the durable cache-dir sentinels.
- Cleanup: scanner may garbage-collect sentinels older than 90 days at the same time it trims `subagents.json`.

This task is a hard prerequisite for shipping Panel 5 with a populated `closed_cleanly` column. Handoff notes (below) list it as T0.

## Scope Delta vs. Approved Plan

This ADR adds, not replaces:

- **Prerequisite (T0):** amend `.claude/settings.json` SubagentStop hook to persist sentinels into `~/.claude/strawberry-usage-cache/subagent-sentinels/` (see D9).
- New script: `scripts/usage-dashboard/subagent-scan.mjs` (lives in `strawberry-app/scripts/usage-dashboard/` per approved-plan placement). <!-- orianna: ok -->
- New data file: `~/.claude/strawberry-usage-cache/subagents.json`.
- New sentinel dir: `~/.claude/strawberry-usage-cache/subagent-sentinels/` (populated by the amended SubagentStop hook; read by the scanner).
- Optional lazy data file for "show all": `~/.claude/strawberry-usage-cache/subagents-full.json` (generated on-demand when the UI toggle flips; see D5).
- `build.sh` gains one extra step (runs subagent-scan after agent-scan).
- `merge.mjs` gains a pass that attaches subagent rows into the final `data.json` under a new `subagents:` key.
- `index.html` + `app.js` gain Panel 5 with group-by (agent/task, default task) and "show all" toggles.
- `roster.json` unchanged — existing agent list is reused.

**Scope of subagent spawns tracked [Resolved 2026-04-19]:** all projects under `~/.claude/projects/`, bucketed by `cwd` — matches the approved parent dashboard's cross-project behavior. Confirmed by Duong.

No changes to approved plan §Architecture, §Storage location, or §Deployment shape. Still file://, still cron every 10 min, still zero paid line items.

## Risks

- **Meta.json format drift.** Claude Code could rename `agentType` or drop `description`. Scanner validates both keys and falls back to JSONL inference (as in D2) rather than dropping the row. Add a loud console warning if the fallback fires; surface on dashboard as a "N spawns partially attributed" banner.
- **Cache-token classification.** `ccusage` computes "total tokens" one way; our `total_tokens` in D4 excludes cache reads to avoid double-counting loop re-reads. If a user compares the sum against `ccusage` they will see a discrepancy. Call this out in the dashboard footer: "Total excludes cache-read tokens; see ccusage for wall-total."
- **Disk growth.** `~/.claude/projects/**/subagents/` grows unbounded. We do not garbage-collect it — that is the harness's job. If Duong's disk fills, that is a harness issue, not this dashboard's.
- **Scanner cost.** Reading every subagent JSONL every 10 min is O(spawns × avg-size). Mitigation: cache per-file `mtime` in `subagents.json`; skip rescan if mtime unchanged. Already-closed JSONLs are immutable, so this is a huge win after the first run.

## Resolutions Log

All seven open questions were resolved by Duong on 2026-04-19 and folded inline into D2, D5, D6, D8, D9, and §Scope Delta. No further open questions remain. Summary:

1. **Task label** → `description` from meta.json (D2).
2. **Retention** → 10 MB / 90 d soft cap on the aggregate cache; UI "show all" toggle reads raw JSONLs for unbounded history (D5, D6).
3. **Panel placement** → new Panel 5 at the bottom; weave-into-Panel-2 deferred to v2 polish (D5).
4. **Group-by** → support both by-agent and by-task; default by-task (D5).
5. **TaskList correlation** → deferred to a later ADR (D8).
6. **`closed_cleanly`** → include; prerequisite SubagentStop hook amendment persists sentinels into `~/.claude/strawberry-usage-cache/subagent-sentinels/` (D9).
7. **Scope** → all projects under `~/.claude/projects/`, bucketed by cwd (§Scope Delta).

## Handoff Notes (for Kayn/Aphelios, once approved)

- **T0 (prerequisite):** amend `.claude/settings.json` SubagentStop hook per D9 — persist sentinels into `~/.claude/strawberry-usage-cache/subagent-sentinels/<agent_id>` instead of `/tmp`. This must land and bake for at least one session before T1 golden tests can assert `closed_cleanly:true` behavior end-to-end.
- Scanner is small: under 200 LOC. Shape mirrors `agent-scan.mjs` — read dir, parse JSONL header + assistant lines with `usage`, read meta.json, read matching sentinel for `closed_cleanly`, emit record, write atomically.
- Golden-test fixture: capture one real `subagents/<id>.jsonl` + `meta.json` pair (scrub prompt content) plus a fake sentinel, write expected output JSON, golden-diff in Vitest. Easy xfail candidate per rule 12.
- `merge.mjs` change is a one-liner: `data.subagents = JSON.parse(readFileSync(cacheDir + 'subagents.json'))`.
- UI change is one `<section>` in `index.html` + a render function in `app.js` that pivots the array into the table, plus the group-by toggle (agent/task, default task) and the "show all" toggle. No new deps — reuse existing Chart.js import (unused in this panel, fine).
- "Show all" path: either a lazy second scanner pass that writes `subagents-full.json` on demand, or a client-side `fetch` of the raw JSONL dir if the file:// origin can read them. Pick whichever is simpler at implementation time; document the choice in the T3 PR.
- Commit identity: this ships in the public app repo (`strawberry-app`) under `apps/**`-adjacent paths (scripts + dashboards), so normal PR-to-main flow with `chore:` or `feat:` prefix per rule 5 (feature-add → `feat:`). The hook amendment in T0 touches `.claude/settings.json` in `strawberry-agents` and uses `chore:` per rule 5.
- TDD-enabled: xfail the scanner golden test before the implementation lands (rule 12).
- Suggested task slices — aligned with the v1/v2 phase split (see §Phases):
  - **v1 (ship now):** (T0) SubagentStop hook amendment; (T1) scanner + golden test; (T2) `build.sh` cron wiring + retention trim + sentinel GC. v1 ships with no UI consumer — data lands in `subagents.json`.
  - **v2 (follow-up):** (T3) `merge.mjs` attaches subagents into `data.json`; (T4) Panel 5 UI incl. group-by (agent/task, default task) and "show all" toggles.
  - Each slice is independently testable after T0. v2 does not block v1.

## References

- Approved parent: `plans/approved/2026-04-19-claude-usage-dashboard.md`.
- Hook docs: `https://code.claude.com/docs/en/hooks` (SubagentStop payload — no usage fields).
- Existing hook wiring: `.claude/settings.json` (SubagentStart/SubagentStop already present from `plans/approved/2026-04-11-subagent-stop-hook.md`).
- TaskList delegation trail: commit `3c7d3c4` (PostToolUse Agent-matcher reminder hook).
- Evidence of usage data in subagent JSONLs: verified against `~/.claude/projects/-Users-duongntd99-Documents-Personal-strawberry-agents/1283cce9-a907-44a6-b273-4323c143cab4/subagents/agent-a142121c740c050bc.{jsonl,meta.json}`.
