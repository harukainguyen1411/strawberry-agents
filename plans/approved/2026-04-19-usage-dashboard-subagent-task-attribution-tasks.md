---
status: approved
owner: kayn
date: 2026-04-19
parent_adr: plans/approved/2026-04-19-usage-dashboard-subagent-task-attribution.md
extends: plans/approved/2026-04-19-claude-usage-dashboard-tasks.md
---

# Task Breakdown — Subagent-Task Attribution (v1 Capture Pipeline)

Executable task breakdown for the v1 phase of the subagent-task-attribution ADR. v1 lands the capture pipeline only — sentinel hook, scanner, aggregate, retention. No UI. v2 tasks (Panel 5, `merge.mjs` integration, group-by toggles, "show all") are explicitly out of scope below; a separate breakdown will follow once v1 is green and baked.

## Context and scope boundary

- Parent ADR is the authoritative spec. Every Decision reference below (D1, D4, D9, etc.) points at that ADR — do not re-interpret; read the Decision text verbatim before implementing.
- v1 extends the approved Claude usage dashboard (`plans/approved/2026-04-19-claude-usage-dashboard-tasks.md`, tasks T1–T10). Workspace = the already-scaffolded `dashboards/usage-dashboard/` + `scripts/usage-dashboard/` trees in `harukainguyen1411/strawberry-app`. Do not re-scaffold; extend.
- The harness writes `agent-<id>.jsonl` and `agent-<id>.meta.json` to `~/.claude/projects/<slug>/<session>/subagents/` for every spawn with zero instrumentation needed. See Evelynn learning `agents/evelynn/learnings/2026-04-19-harness-native-attribution-data.md`. The scanner reads those files directly.
- v1 ships with no UI consumer. `subagents.json` accumulates in `~/.claude/strawberry-usage-cache/` and is inspectable via `jq` until v2 lands.

## Cross-repo operating rules for executors

- T0 operates in `~/Documents/Personal/strawberry-agents/` (this repo — hooks live here).
- AT.1–AT.3 operate in `~/Documents/Personal/strawberry-app/` (the public app repo where the existing scanner pipeline lives).
- T0 touches `.claude/settings.json` in `strawberry-agents`: commit prefix `chore:` (not under `apps/**`, CLAUDE.md rule 5).
- AT.1–AT.3 touch `scripts/usage-dashboard/**` in `strawberry-app`: commit prefix `chore:` (not under `apps/**`, CLAUDE.md rule 5).
- Each task creates a branch via `scripts/safe-checkout.sh` (worktree; never raw `git checkout`, rule 3).
- Each implementation task MUST land an xfail test commit before the implementation commit on the same branch (CLAUDE.md rule 12). xfail tests must reference this plan path in a comment.
- No `git rebase`; merge only (rule 11).
- Do not merge own PR (rule 18); hand off to a reviewer after E2E green. T0 is a settings-only change in the agents repo, which is direct-to-main per local convention (no PR) — still commit via `chore:`.
- POSIX-portable shell for anything under `scripts/` outside `scripts/mac/`+`scripts/windows/` (rule 10).

## Task Summary

**4 tasks total** (1 hook prerequisite + 3 pipeline tasks). See dependency graph at end.

| #    | Task                                              | Repo                | Type    | Depends on       |
|------|---------------------------------------------------|---------------------|---------|------------------|
| T0   | SubagentStop hook amendment (durable sentinels)   | strawberry-agents   | config  | —                |
| AT.1 | `subagent-scan.mjs` scanner + golden test         | strawberry-app      | new     | T0 (soft)        |
| AT.2 | `build.sh` integration + retention + sentinel GC  | strawberry-app      | update  | AT.1             |
| AT.3 | Mtime-cache incremental scan (perf)               | strawberry-app      | update  | AT.1             |

**Parallel-eligible pairs**:
- AT.2 and AT.3 both extend AT.1 and touch independent surfaces (`build.sh` + retention vs. scanner internals). They can run in parallel once AT.1 merges; merging order between them does not matter.
- T0 can ship the day this plan is approved; AT.1's golden fixture does not require T0 to have baked (the fixture can carry its own fake sentinel). Real `closed_cleanly:true` observations only show up after T0 has been live through one SubagentStop cycle, so AT.2's real-data acceptance test soft-depends on T0 having run at least once.

**Strict sequential**: AT.1 → AT.2, AT.1 → AT.3 (both consume AT.1's scanner).

**Suggested wall-clock**: T0 lands today (trivial). AT.1 is the bulk of the work. AT.2 + AT.3 land in parallel after AT.1.

---

## T0 — SubagentStop hook amendment: durable sentinels

**Repo**: `strawberry-agents`
**Branch**: direct commit to main (settings-only, per local convention for this repo)
**Type**: config change
**ADR refs**: D9

**What**: Amend the SubagentStop hook in `.claude/settings.json` so each subagent-close event persists a sentinel into a durable cache-dir location instead of relying on `/tmp`, which evaporates at reboot/cleanup and currently destroys the `closed_cleanly` signal.

**Where**:
- `.claude/settings.json` — modify the `SubagentStop` hook block (currently at line 69–77; command at line 74).

**Behavior to implement**:
- On SubagentStop fire, in addition to the existing `/tmp` sentinel cleanup, `mkdir -p ~/.claude/strawberry-usage-cache/subagent-sentinels && touch ~/.claude/strawberry-usage-cache/subagent-sentinels/<agent_id>`.
- Pull `agent_id` from the SubagentStop payload (see ADR §Capability Check — field is literally named `agent_id`). Use `jq -r '.agent_id'` alongside the existing `jq -r '.session_id'` read.
- Preserve the existing `systemMessage` warning when `/tmp/claude-subagent-${sid}-closed` is absent (do not regress the `/end-subagent-session` miss detector).
- Preserve the existing `/tmp` sentinel cleanup at the tail (`rm -f ...started ...closed`).
- The command must remain a single POSIX-portable shell line (macOS + Git Bash on Windows, rule 10).

**ADR quote (D9)**: "The amendment is a one-liner in the hook command: `mkdir -p ~/.claude/strawberry-usage-cache/subagent-sentinels && touch ~/.claude/strawberry-usage-cache/subagent-sentinels/<agent_id>`".

**Inputs**: current `.claude/settings.json` SubagentStop block.
**Outputs**: amended hook command; sentinel file appears at `~/.claude/strawberry-usage-cache/subagent-sentinels/<agent_id>` on next subagent close.

**Verification**:
1. Fire a throwaway subagent spawn that calls `/end-subagent-session`. Inspect `~/.claude/strawberry-usage-cache/subagent-sentinels/` — sentinel file must exist, named after the spawn's `agent_id`.
2. Confirm `/tmp/claude-subagent-${sid}-started` and `/tmp/claude-subagent-${sid}-closed` are still cleaned at close (no regression of existing cleanup).
3. Confirm the "closed without running /end-subagent-session" systemMessage still fires when `/tmp/claude-subagent-${sid}-closed` is absent.
4. Manual sanity: `jq .` the settings file — must parse clean (JSON, no trailing commas).

**TDD note**: Settings-only hook edits are exempt from rule 12's xfail-first requirement (no test harness exists for `.claude/settings.json` commands, and the hook body is a shell one-liner). Verification is manual per the steps above. If the executor wants belt-and-suspenders, a shellcheck-pass assertion can be added but is not required.

**Commit**: `chore:` prefix per rule 5 (settings file, not under `apps/**`). Direct to main in `strawberry-agents` per local convention for hook tweaks.

**Out of scope (v2)**:
- `closed_cleanly` rendering in the dashboard UI — belongs to v2 Panel 5.
- Any change to the `/end-subagent-session` skill body — the skill's belt-and-suspenders `/tmp` sentinel stays as-is.

**Risk**: if the scanner (AT.1) ships before T0 has baked through at least one subagent cycle, `closed_cleanly` will be `false` for every spawn in the interim. This is not a correctness bug (matches ADR §D7 "crashed/aborted" handling) but is cosmetic noise until T0 propagates.

---

## AT.1 — `subagent-scan.mjs` scanner + golden test

**Repo**: `strawberry-app`
**Branch**: `chore/subagent-scan-v1`
**Type**: new script
**ADR refs**: D1, D2, D3, D4, D7, D9

**What**: Implement the post-hoc scanner that walks `~/.claude/projects/**/<session>/subagents/` and emits one record per `agent-<id>.jsonl` + `agent-<id>.meta.json` pair. Records land in `~/.claude/strawberry-usage-cache/subagents.json`.

**Where**:
- Implementation: `scripts/usage-dashboard/subagent-scan.mjs` <!-- orianna: ok --> (sibling to the existing `agent-scan.mjs` in this directory — mirror its file shape per ADR handoff notes).
- Fixture dir: `scripts/__tests__/fixtures/subagents/` <!-- orianna: ok --> — add one real-shape `agent-<id>.jsonl` (scrubbed of prompt content), its sibling `agent-<id>.meta.json`, and a fake sentinel file.
- Test: `scripts/__tests__/subagent-scan.test.mjs` <!-- orianna: ok --> (node --test, mirroring `agent-scan.test.mjs` style).

**Behavior to implement**:
- Walk `~/.claude/projects/**/<session>/subagents/*.jsonl` (glob the pattern cross-platform with Node's `fs.glob` or manual dir walk — mirror how `agent-scan.mjs` handles this).
- For each `agent-<id>.jsonl`:
  - Look up sibling `agent-<id>.meta.json`.
  - Parse `meta.json` → extract `agentType`, `description`.
  - Stream-read the JSONL; aggregate from assistant lines' `usage` block:
    - `tokens_in`      ← sum(`input_tokens`)
    - `tokens_out`     ← sum(`output_tokens`)
    - `cache_creation` ← sum(`cache_creation_input_tokens`)
    - `cache_read`     ← sum(`cache_read_input_tokens`)
    - `total_tokens`   ← `tokens_in + tokens_out + cache_creation`   **(explicitly excludes cache_read per ADR D4)**
    - `tool_uses`      ← count of `tool_use` content blocks across assistant lines
    - `model`          ← last assistant line's `model`
    - `started_at`     ← first JSONL line timestamp
    - `ended_at`       ← last JSONL line timestamp
    - `duration_ms`    ← `ended_at − started_at` in ms
    - `cwd`, `git_branch` ← first JSONL entry (use null-safe accessors; `git_branch` may be absent)
  - From meta.json / JSONL:
    - `spawn_id`       ← `meta.agentId` (or `agentId` on any JSONL line)
    - `parent_session_id` ← `sessionId` on any JSONL line
    - `agent`          ← `meta.agentType`
    - `task`           ← `meta.description`
  - From the sentinel dir:
    - `closed_cleanly` ← `fs.existsSync('~/.claude/strawberry-usage-cache/subagent-sentinels/' + spawn_id)`
  - `jsonl_path`       ← absolute path to the JSONL (for v2 drill-down)
  - `parent_agent`     ← best-effort lookup in `~/.claude/strawberry-usage-cache/agents.json` by `parent_session_id`. If `agents.json` is missing or the lookup misses, emit `null`. **Do not** block on `agent-scan.mjs`; ADR §Scope Delta says `build.sh` runs `agent-scan.mjs` first, but the scanner must tolerate a missing `agents.json` to stay testable in isolation.
- **Emit the exact record shape in ADR D4** — every field listed there must appear, even if null. The dashboard's v2 reader will assume the schema.
- **Fallbacks (ADR D2)**:
  - meta.json missing → `agent` = first user message truncated to 80 chars (from JSONL first `type:"user"` line's `message.content[0].text`); `task` = the same truncated string; log a console warning with the JSONL path.
  - `meta.agentType` missing but meta.json present → fall back to roster-regex match on first user message (reuse the regex set from `agent-scan.mjs` — import or copy; duplication acceptable for v1 to keep scanners decoupled).
  - `meta.description` empty or absent → `task` = `"unlabeled-<short spawn_id>"` where short = first 8 chars of spawn_id. ADR wording: "label as `unlabeled-<agent-id-short>` so it is still grouped, not dropped."
- **Atomic write**: collect all records into an array, write to `~/.claude/strawberry-usage-cache/subagents.json.tmp`, then `fs.rename` to `subagents.json`. Mirror `agent-scan.mjs`'s existing atomic-write pattern.
- **Output envelope**:
  ```
  {
    "schemaVersion": 1,
    "generatedAt": "<ISO>",
    "spawns": [ /* D4 records */ ],
    "partiallyAttributedCount": <int>,   // rows where meta fallback fired
    "scannedFiles": <int>,
    "skippedFiles": <int>                // reserved for AT.3's mtime cache
  }
  ```
- CLI: `node subagent-scan.mjs` — no flags required. Optional `--cache-dir <path>` for testability (defaults to `~/.claude/strawberry-usage-cache`). Optional `--projects-dir <path>` for testability (defaults to `~/.claude/projects`).
- Size target per ADR: "under 200 LOC. Shape mirrors `agent-scan.mjs`".

**Task-label resolution** — Each scanned spawn row must include a `task_label` field with this shape:

```
task_label: {
  source: "taskid" | "description" | "prompt-head",
  value: "<string>"
}
```

Resolution priority, first match wins:

1. **taskid** — if the spawn's first user message starts with `[task:<id>]`, look up `<id>` in the live task store and use the task's subject. `source: "taskid"`. *(Optional convention; not enforced. Scanner should handle absence gracefully.)*
2. **description** — if the `.meta.json` for this spawn records the Agent tool call's `description` field, use it verbatim. `source: "description"`.
3. **prompt-head** — fall back to the first non-empty line of the spawn's first user message, trimmed to 80 chars with ellipsis if truncated. `source: "prompt-head"`.

The scanner must never fail on an unresolvable task — every spawn gets a `task_label`, even if only the prompt head. Downstream UI uses `source` to show confidence.

**TDD (xfail first commit)** — per CLAUDE.md rule 12, commit the test file first with `.fixme()` / `t.skip()` wrappers that reference this plan path in a comment. Second commit removes the skip and lands the implementation. Test cases:

1. Golden: given fixture `agent-a142.jsonl` + `agent-a142.meta.json` + matching sentinel, scanner emits a record matching the committed golden `expected.json` byte-for-byte after `JSON.stringify(x, null, 2)`.
2. meta.json absent → `agent` = first-user-message-truncated; `task` = same; warning logged; row still emitted.
3. sentinel absent for spawn → `closed_cleanly === false`; row still emitted.
4. `meta.description` empty string → `task` matches `/^unlabeled-[a-f0-9]{8}$/`.
5. `meta.agentType` missing but first user message is `"Hey Vi\n..."` → `agent === "Vi"` via roster-regex fallback.
6. `total_tokens === tokens_in + tokens_out + cache_creation` (cache_read excluded — load-bearing per ADR D4).
7. Atomic write: kill the process mid-run (simulate by monkeypatching `fs.rename` to throw) → `subagents.json` stays unchanged from its prior state (never half-written).
8. Missing `~/.claude/strawberry-usage-cache/agents.json` → scanner still runs; `parent_agent === null` on every row; no crash.
9. JSONL with zero assistant lines (crashed spawn before first response) → row emitted with all token fields `0`, `ended_at === started_at`, `closed_cleanly` honored per sentinel.
10. Multiple spawns under the same session dir → one row per spawn; no double-counting; ordering stable by `spawn_id` for test determinism.
11. `task_label` taskid hit: first user message starts with `[task:abc123]` and the task store returns subject "Refactor pipeline" → `task_label.source === "taskid"` and `task_label.value === "Refactor pipeline"`.
12. `task_label` description hit: `meta.description` is non-empty and first user message has no `[task:...]` prefix → `task_label.source === "description"` and `task_label.value` equals the description verbatim.
13. `task_label` prompt-head fallback: `meta.description` absent and no `[task:...]` prefix → `task_label.source === "prompt-head"` and `task_label.value` equals the first non-empty line of the first user message, truncated to 80 chars with ellipsis appended when the original exceeds 80 chars.

**Inputs**: any `~/.claude/projects/**/<session>/subagents/` tree on disk; `~/.claude/strawberry-usage-cache/subagent-sentinels/` (may be empty pre-T0 bake).
**Outputs**: `~/.claude/strawberry-usage-cache/subagents.json` matching the envelope above.

**Verification**:
- `node scripts/usage-dashboard/subagent-scan.mjs` on Duong's machine produces a `subagents.json` with >0 spawns (thousands already on disk per ADR D6).
- `jq '.spawns | length'` > 0.
- `jq '.spawns[] | select(.total_tokens == null)'` returns nothing (every row has numeric totals).
- `node --test scripts/__tests__/subagent-scan.test.mjs` → all 13 tests green.

**Parallelism**: sequential first step of v1 pipeline. Blocks AT.2 and AT.3.

**Commit**: `chore:` prefix (scripts dir, outside `apps/**`).

**Out of scope (v2)**:
- `merge.mjs` integration and the `data.json` `subagents:` key — that is a v2 task.
- Any UI render.
- `subagents-full.json` lazy aggregate for the v2 "show all" toggle.
- TaskList correlation (ADR D8 — explicitly deferred).

---

## AT.2 — `build.sh` integration + retention + sentinel GC

**Repo**: `strawberry-app`
**Branch**: `chore/subagent-scan-build-wire`
**Type**: update existing script
**ADR refs**: D3, D6, D9, §Scope Delta

**What**: Wire `subagent-scan.mjs` into the existing `build.sh` cron step so it runs after `agent-scan.mjs` on every tick; add retention trim on `subagents.json` (10 MB / 90 d); add sentinel dir GC on the same cadence.

**Where**:
- Modify: `scripts/usage-dashboard/build.sh` — add one step after the existing `agent-scan.mjs` invocation.
- Optionally extract retention into a small helper: `scripts/usage-dashboard/subagent-trim.mjs` <!-- orianna: ok --> (or inline in the scanner — executor's call; inline is fine for v1 if it stays under the 200-LOC soft cap).
- Extend: `scripts/__tests__/build-sh.test.mjs` (existing) with the new cases listed under TDD below.

**Behavior to implement**:
- `build.sh` gains a line: `node "$SCRIPT_DIR/subagent-scan.mjs"` after the `agent-scan.mjs` line. Same error-propagation shape as the existing steps (`set -euo pipefail` already in force — inherit).
- Summary line at the end of `build.sh` adds a subagent count: e.g. `built data.json (X sessions, Y agents, Z unknown, S spawns)`.
- **Retention on `subagents.json`** (ADR D6):
  - After scan, check file size. If > 10 MB OR any `spawn.ended_at` is older than 90 days, sort `spawns[]` by `ended_at` ascending and drop from the front until both caps hold.
  - Atomic write: trim in-memory, write `subagents.json.tmp`, rename.
  - Log one line: `trimmed subagents.json: dropped N rows (size=<bytes>, oldest=<ISO>)` when a trim fires; silent otherwise.
- **Sentinel GC** (ADR D9): at scan end, delete any file under `~/.claude/strawberry-usage-cache/subagent-sentinels/` whose `mtime` is older than 90 days. One-liner with `find -mtime +90 -delete` in the build.sh step, guarded for macOS+Git-Bash portability (use `find ... -mtime +90 -print0 | xargs -0 rm -f` if `-delete` proves non-portable — mirror the portability pattern already in `build.sh`).
- POSIX-portable (rule 10).

**TDD (xfail first commit)** — commit the new test cases as `.fixme()` first referencing this plan path; second commit removes the skip and lands the implementation.

Extensions to `scripts/__tests__/build-sh.test.mjs`:
1. Happy path: stub `subagent-scan.mjs` to emit a fixture `subagents.json` with 3 rows → `build.sh` exits 0 and summary line includes `3 spawns`.
2. Retention size: seed `subagents.json` at 11 MB of synthetic rows → after build, file ≤ 10 MB, oldest row dropped first.
3. Retention age: seed `subagents.json` with rows dated 100 days ago + rows dated yesterday → after build, 100-day rows gone, yesterday rows kept.
4. Sentinel GC: seed `subagent-sentinels/` with one file whose `mtime` is 100 days ago and one whose `mtime` is today → after build, old file deleted, new file kept.
5. Scanner failure → `build.sh` exits non-zero; `subagents.json` is **not** clobbered (inherits the existing atomic-write invariant).

**Inputs**: existing `build.sh`, existing tests, outputs of AT.1.
**Outputs**: `build.sh` runs `subagent-scan.mjs`, retention+GC applied, counters exposed.

**Verification**:
- `bash scripts/usage-dashboard/build.sh` on Duong's machine completes in <6 s and produces both `agents.json` and `subagents.json` with sensible row counts.
- Running `build.sh` twice back-to-back is idempotent (no row duplication; retention counters don't drift).
- Size of `subagents.json` stays under 10 MB on real data (the trim should not fire on Duong's current corpus, but the logic must be exercised by the fixture tests).

**Parallelism**: after AT.1. Parallel with AT.3.

**Commit**: `chore:` prefix.

**Out of scope (v2)**:
- `merge.mjs` attaching `subagents.json` to `data.json` — v2 task.
- UI Panel 5 rendering — v2 task.
- `subagents-full.json` lazy aggregate — v2 task.

---

## AT.3 — Mtime-cache incremental scan (perf)

**Repo**: `strawberry-app`
**Branch**: `chore/subagent-scan-mtime-cache`
**Type**: update scanner
**ADR refs**: Risks §"Scanner cost", Phases §v1 "Mtime cache for incremental scan"

**What**: Add an mtime cache to `subagent-scan.mjs` so already-closed (immutable) JSONLs are skipped on subsequent ticks. ADR treats this as a first-class v1 component; after the first full scan, per-tick work drops to near-zero for closed spawns.

**Where**:
- Modify: `scripts/usage-dashboard/subagent-scan.mjs` (the scanner from AT.1).
- Extend: `scripts/__tests__/subagent-scan.test.mjs` with the new cases below.

**Behavior to implement**:
- Maintain a per-file `mtime` entry inside `subagents.json`:
  - Promote each row's record with an `_mtime: <number>` (unix ms). Kept at the row level, not a separate sidecar, so one atomic write preserves the cache.
  - Alternatively, add a top-level `mtimeCache: { "<jsonl_path>": <ms> }` alongside `spawns[]`. Executor's choice; top-level is easier to prune when rows are trimmed by AT.2 — **prefer top-level for that reason**.
- On each scan tick:
  - For each `agent-<id>.jsonl` on disk: `statSync(path).mtimeMs`.
  - If the path is in `mtimeCache` AND cached mtime === current mtime AND a corresponding row already exists in `spawns[]` → skip re-parse, increment `skippedFiles`, carry forward the existing row.
  - Otherwise, parse fully (AT.1 path) and update `mtimeCache`.
- A missing `mtimeCache` (first run after upgrade) behaves exactly like AT.1 — full parse of everything. The cache populates on the way out.
- Interaction with AT.2 retention: when a row is trimmed by age/size, **also** delete its entry from `mtimeCache`. Keep the two in lockstep; orphan `mtimeCache` entries are a memory leak that will slowly grow across 90-day windows.
- `closed_cleanly` revisit on skip: the sentinel for a spawn can appear AFTER the JSONL's last mtime (sentinel is written by the SubagentStop hook, JSONL's last line is a few ms earlier). So when a row is cached-hit but its prior `closed_cleanly` was `false`, the scanner MUST re-check the sentinel dir for that `spawn_id` and flip the flag to `true` if the sentinel has since appeared. Without this, every "scanned before sentinel landed" spawn stays permanently misattributed.

**TDD (xfail first commit)** — xfail first per rule 12, referencing this plan path.

Additions to `scripts/__tests__/subagent-scan.test.mjs`:
1. First run populates `mtimeCache` with one entry per JSONL parsed.
2. Second run against unchanged fixtures → `scannedFiles` unchanged, `skippedFiles` equals total files; `spawns[]` identical to prior run.
3. Touch a fixture JSONL (update mtime) → scanner re-parses that one only; others skipped.
4. Retention trim (AT.2) removes a row → the corresponding `mtimeCache` entry is gone from the next scan's output (lockstep invariant).
5. Sentinel appears AFTER first scan: seed fixture with no sentinel, run scanner (row has `closed_cleanly:false`), drop a matching sentinel file, run scanner again without touching JSONL mtime → row's `closed_cleanly` flips to `true`.
6. Perf guard: scanning 1000 fixture JSONLs with a hot mtime cache completes in <500 ms (first-run baseline not asserted — just the hot path).

**Inputs**: AT.1's scanner source.
**Outputs**: mtime-cached scanner; `subagents.json` envelope gains `mtimeCache` (or row-level `_mtime` — see note above; top-level preferred).

**Verification**:
- Run `subagent-scan.mjs` twice on Duong's real corpus; the second run's `skippedFiles` should be ≥ 99% of `scannedFiles` (nearly everything on disk is closed and immutable).
- Second-run wall time < 20% of first-run wall time (loose bound; ADR calls this "a huge win after the first run").
- All 10 AT.1 tests still green (no regression).

**Parallelism**: after AT.1. Parallel with AT.2.

**Commit**: `chore:` prefix.

**Out of scope (v2)**:
- Parallelizing the scan across CPU cores — not needed given the mtime-skip savings; revisit only if profiling shows first-run wall time > 30 s on a real corpus.

---

## Dependency Graph

```
T0 (hook amendment, strawberry-agents repo)
 |  (soft dep — T0 bake required for real `closed_cleanly:true`, not for AT.1 tests)
 v
AT.1 (subagent-scan.mjs + golden test)
 |
 +--> AT.2 (build.sh wire + retention + sentinel GC)      [parallel]
 |
 +--> AT.3 (mtime-cache incremental scan)                 [parallel]
```

## Parallelism summary

- **Strictly sequential**: AT.1 first; then AT.2 and AT.3 each consume it.
- **Parallel batch**: AT.2 ∥ AT.3 after AT.1.
- **T0 is independent** — can ship today, must bake before AT.2's real-data verification is meaningful.
- **Minimum wall-clock path**: T0 (same day) → AT.1 → max(AT.2, AT.3). Three serial waves; the final wave is half-width.

## Out of scope — v2 (separate breakdown)

Explicitly deferred to the v2 tasks plan. Do **not** slip any of these into v1:

- `merge.mjs` attaches `subagents.json` into `data.json` under a `subagents:` key (ADR §Scope Delta).
- Panel 5 rendering in `index.html` + `app.js` (ADR D5).
- Group-by toggle — agent / task / flat; default task (ADR D5).
- "Show all" retention-bypass toggle and any lazy `subagents-full.json` generation (ADR D5, D6).
- Drill-down tooltip + `[in / out / cache]` micro-breakdown (ADR D5).
- TaskList correlation (ADR D8 — explicitly deferred to a later ADR).
- Integration into Panel 2 (ADR D5 — deferred to v2 polish).
- Subagent roster regex tuning / `partiallyAttributedCount` banner in the UI (ADR Risks).

v2 will extend the approved usage-dashboard tasks plan in a separate proposed file; it will consume the v1 `subagents.json` envelope unchanged.

## Risks flagged during breakdown

- **T0 timing.** If AT.1 lands and runs before T0 has baked for at least one subagent cycle, every spawn captured in the interim will show `closed_cleanly:false`. This is cosmetic (matches the ADR's "crashed/aborted" handling) but can be mistaken for a real signal. Recommend running T0 at the top of the session and letting at least one `/end-subagent-session` cycle fire before running AT.1 against real data. Not a correctness bug; no schema impact.
- **`agents.json` coupling.** AT.1 reads `~/.claude/strawberry-usage-cache/agents.json` for `parent_agent` lookup. The ADR specifies `build.sh` runs `agent-scan.mjs` before `subagent-scan.mjs`, so in production that file exists. But the scanner must tolerate its absence (null `parent_agent`) to stay unit-testable without the full pipeline. Test 8 in AT.1 locks this.
- **`mtimeCache` vs. retention lockstep.** AT.3 introduces a subtle invariant: when AT.2 trims rows, it must also prune `mtimeCache`. If those drift, the cache slowly balloons and rows can "reappear" (scanner skips the JSONL because mtime matches, row has been trimmed, so scanner adds it back). Test 4 in AT.3 is the regression guard.
- **Sentinel-after-scan race.** Spawns closed between the SubagentStop hook firing and the scanner reading the sentinel dir will see `closed_cleanly:false` on the first scan, then flip to `true` on the next tick (AT.3 test 5). This is expected per ADR §D7 "crashed/aborted" handling, not a bug. Just means `closed_cleanly:false` on a <10-minute-old spawn means "too recent" not "died dirty" — worth a one-line comment in the scanner.
- **Commit-prefix scope.** All v1 work (T0 + AT.1–AT.3) lands outside `apps/**`. `chore:` is correct on every commit. If the pre-push hook complains, check the diff scope per CLAUDE.md rule 5 before escalating.
- **Cross-repo split.** T0 is in `strawberry-agents`; AT.1–AT.3 are in `strawberry-app`. An executor picking up the whole plan needs to switch repos between T0 and AT.1. Flag explicitly at assignment time.

## Open questions for Duong surfaced during breakdown

None. All seven open questions from the ADR were resolved inline by Duong on 2026-04-19 (see ADR §Resolutions Log). Every decision the tasks depend on (task label source, retention cap, sentinel mechanism, scope, `closed_cleanly` inclusion, group-by defaults, panel placement, TaskList deferral) is locked. v1 breakdown carries no new Duong-blockers.

Two minor implementer-level calls intentionally left to the executor, as noted inline:

1. AT.1 meta-regex reuse — import vs. copy from `agent-scan.mjs`. Both are fine for v1; recommend copy to keep scanners decoupled, but executor's call.
2. AT.3 `mtimeCache` placement — top-level vs. row-level. Recommend top-level for easy pruning alongside retention. Either works; tests must match the chosen shape.

Neither blocks dispatch.
