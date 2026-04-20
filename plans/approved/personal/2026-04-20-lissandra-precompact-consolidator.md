---
status: approved
orianna_gate_version: 2
concern: personal
complexity: normal
owner: azir
created: 2026-04-20
tags: [agent-addition, memory, session-lifecycle, hooks]
supersedes: []
related:
  - plans/implemented/2026-04-20-agent-pair-taxonomy.md
  - architecture/agent-pair-taxonomy.md
  - .claude/skills/end-session/SKILL.md
  - .claude/skills/end-subagent-session/SKILL.md
  - plans/proposed/2026-04-18-evelynn-memory-sharding.md
architecture_changes:
  - architecture/agent-pair-taxonomy.md  # row 16 added (single-lane memory-consolidator, T7)
  - architecture/compact-workflow.md      # new doc (T9)
orianna_signature_approved: "sha256:a24957c87a2dd006412ddd915fffb2fbe5c3ee9cd6cb8c5836767ac122db09b3:2026-04-20T16:35:07Z"
---

# Lissandra — pre-compact memory consolidator

## 1. Problem & motivation

When Duong runs `/compact` on a coordinator session (Evelynn or Sona), Claude Code compresses the conversation into a summary and continues. The in-memory summary survives, but the **durable artifacts produced by `/end-session`** do not fire:

- No cleaned transcript under `agents/<coordinator>/transcripts/`.
- No journal entry in `agents/<coordinator>/journal/cli-YYYY-MM-DD.md`.
- No handoff shard in `agents/<coordinator>/memory/last-sessions/<uuid>.md`.
- No session shard in `agents/<coordinator>/memory/sessions/<uuid>.md`.
- No learnings file in `agents/<coordinator>/learnings/`.
- No commit.

Result: everything the session discovered — decisions reached, open threads, fact-check outcomes, routing lessons — is collapsed into a compacted summary that lives only in the post-compact context window. If that window is later cleared, reset, or the session is closed without a subsequent `/end-session`, the knowledge is **lost**.

Duong has confirmed the behavioral reality: he forgets to run `/end-session` before `/compact`, and frequently *doesn't want* to end the session — compact is a context-management operation, not a session boundary. The current protocol forces a false binary (end or lose it).

### 1.1 Why a new agent (not a skill-only approach)

The consolidation work is **judgment-heavy summarization**:
- Reading a live jsonl and distinguishing durable from transient content.
- Deciding whether a session produced a generalizable lesson vs. routine execution (same decision gate as `/end-subagent-session`).
- Writing first-person journal prose in the **coordinator's voice** (not Lissandra's).
- Extracting handoff notes that capture what a future instance would need.

That is Sonnet-medium work. A pure shell skill cannot make those judgments. A Sonnet agent with adaptive thinking can.

### 1.2 Scope boundary

In-scope: **coordinator sessions only** (Evelynn, Sona). Subagent sessions are explicitly out — they already have `/end-subagent-session` (which the subagent invokes itself), and subagent state does not survive compact in a way that matters (their conversation is embedded in the parent's transcript; compact of the parent session does not compact a subagent session in isolation).

## 2. Decision

Add **Lissandra**, a single-lane Sonnet-medium agent in the **memory-consolidator** role slot. Lissandra is a sibling to Skarner (memory excavator) — Skarner searches and logs; Lissandra consolidates at session boundaries the coordinator doesn't mark.

### 2.1 Frontmatter shape

```yaml
---
model: sonnet
effort: medium
thinking:
  budget_tokens: 6000
tier: single_lane
role_slot: memory-consolidator
permissionMode: bypassPermissions
name: Lissandra
description: Pre-compact memory consolidator — mirrors the coordinator's /end-session protocol on their behalf when /compact is imminent. Reads the live transcript jsonl, detects the active coordinator (Evelynn or Sona), and writes the handoff note, memory shard, session shard, journal entry, learnings, and commit in that coordinator's voice. Invoked via PreCompact hook or the /pre-compact-save skill.
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - Edit
---
```

Note the thinking budget is **6000** — above the standard Sonnet-medium 5000 (per §3.2 of `agent-pair-taxonomy.md`). Justification: the coordinator-voice extraction plus learning-vs-routine decision gate are both judgment-heavy and benefit from a bit more headroom. Still well below Sonnet-high's 10000.

### 2.2 Role slot registration

New role slot value: `memory-consolidator`. Paired? No — single-lane. Listed in the §1.1 single-lane table of `architecture/agent-pair-taxonomy.md` at row 18 (next row after Camille). See §5 below for the hook-matrix update.

### 2.3 Personality (Lissandra theme)

League voice: Lissandra is the ice-bound keeper of forgotten things. Quiet, patient, unsettling. Fits the role — she preserves what would otherwise melt away. Shares the "memory" thematic bucket with Skarner (the excavator who digs up crystals from deep earth). Skarner excavates; Lissandra entombs.

Keep the personality block short (3–5 lines in the agent def). The LoL voice is garnish; the mechanics are what matter.

### 2.4 Boundaries

- **Writes to the coordinator's directories only**, never her own. Specifically:
  - `agents/<coordinator>/transcripts/<YYYY-MM-DD>-<uuid>.md`
  - `agents/<coordinator>/journal/cli-<YYYY-MM-DD>.md`
  - `agents/<coordinator>/memory/last-sessions/<uuid>.md`
  - `agents/<coordinator>/memory/sessions/<uuid>.md`
  - `agents/<coordinator>/learnings/<YYYY-MM-DD>-<topic>.md` (if warranted)
  - `agents/<coordinator>/learnings/index.md` (append one line if a learning was written)
- **Never** writes to `agents/lissandra/` outside her own closing protocol (which is `/end-subagent-session` — she is a Sonnet subagent herself).
- Never calls `/end-session` on the coordinator's behalf. That skill is `disable-model-invocation: true` precisely to keep it human-triggered. Lissandra performs an *equivalent consolidation* without firing the skill.
- Never promotes plans, never opens PRs, never calls `scripts/plan-promote.sh`.
- Never modifies `.claude/settings.json`, `scripts/hooks/`, or other coordinator-global state. Her output is append-only artifacts.

### 2.5 What Lissandra is not

- Not a replacement for `/end-session`. The end-session skill still runs at actual session end. Lissandra runs at *compact boundaries*, which are more frequent and of lower stakes.
- Not a replacement for Evelynn's sharded-write memory discipline. Evelynn avoids concurrent memory writes for concurrency reasons (per `plans/proposed/2026-04-18-evelynn-memory-sharding.md` §D6); Lissandra follows the same discipline.
- Not a transcript archiver in the full `scripts/clean-jsonl.py` sense — she writes a compact-specific transcript excerpt, not the end-session archive (see §4.3).

## 3. Triggers

Two trigger paths. Both wired by default; either can be disabled independently.

### 3.1 PreCompact hook (automatic)

The Claude Code **PreCompact** hook event exists (verified 2026-04-20 via the Claude Code hooks reference — see Open Questions §7 for the exact URL reference to revalidate at implementation time). Key properties:

- Fires before `/compact` compresses the context.
- Receives JSON payload on stdin: `{ session_id, transcript_path, cwd, hook_event_name: "PreCompact", compaction_trigger: "manual" | "auto" }`.
- Supports a `matcher` field: `"manual"`, `"auto"`, `"*"`.
- Can block compaction by exiting with code 2 or returning `{"decision": "block", "reason": "..."}`.
- **Critical limitation:** PreCompact hooks **cannot spawn subagents directly**. Agent-type hooks at this event are limited to read-only tools (Read, Glob, Grep). This rules out the naive design of "the hook invokes Lissandra via the Agent tool."

#### 3.1.1 Chosen hook design — block-and-prompt

Because the hook cannot spawn Lissandra, the hook instead **blocks the first compact attempt** and injects a `systemMessage` asking the coordinator to run `/pre-compact-save` before retrying. Flow:

1. Duong types `/compact` in an Evelynn/Sona session.
2. PreCompact hook fires with `compaction_trigger: "manual"` (the manual matcher).
3. Hook checks for `.no-precompact-save` sentinel in repo root. If present → allow compact (exit 0) without prompting. This is Duong's opt-out.
4. Hook checks for a **completion sentinel** at `/tmp/claude-precompact-saved-<session_id>` (touched by Lissandra at the end of her run). If present → allow compact, remove the sentinel, exit 0.
5. Otherwise, hook emits:
   ```json
   {
     "decision": "block",
     "reason": "Lissandra has not consolidated this session yet. Run /pre-compact-save first, then re-run /compact. To opt out of this gate, create .no-precompact-save in the repo root."
   }
   ```
6. Duong (or the coordinator, on Duong's cue) runs `/pre-compact-save`. That skill spawns Lissandra. Lissandra writes her artifacts, commits, and touches the sentinel.
7. Duong re-runs `/compact`. Hook sees the sentinel, allows the compact, cleans up the sentinel.

Rationale: the block-and-prompt pattern treats compact as a gated transition (same shape as `/end-session`'s disable-model-invocation rule). It never silently skips consolidation; it never silently blocks without telling the user how to unblock.

#### 3.1.2 Auto-compact handling

When `compaction_trigger: "auto"` fires (context overflow), blocking would be hostile — the user didn't ask for it, and the session can't proceed until compaction happens. Two options:

- **Option A (chosen):** Allow auto-compact silently. The sentinel check still runs; if a recent consolidation happened (sentinel or recent commit touching `agents/<coordinator>/memory/last-sessions/`), log "consolidated at <timestamp>, allowing auto-compact" and exit 0. If not, log a warning to stderr but still exit 0.
- **Option B (rejected):** Block auto-compact and force the user to consolidate. Rejected: the user is often not watching when auto-compact fires (it happens mid-work on context overflow).

The hook's `matcher` registration will be `"manual"` — auto-compact falls through to default-allow.

#### 3.1.3 Hook registration

In `.claude/settings.json`, under the `hooks` block, add a new `PreCompact` entry:

```json
"PreCompact": [
  {
    "matcher": "manual",
    "hooks": [
      {
        "type": "command",
        "command": "bash scripts/hooks/pre-compact-gate.sh"
      }
    ]
  }
]
```

The script `scripts/hooks/pre-compact-gate.sh` is a small (< 50 LOC) POSIX bash script implementing the decision flow in §3.1.1. It reads the JSON payload from stdin via `jq`, checks sentinels, emits the `block` decision JSON when needed. No subagent invocation in the script itself.

### 3.2 Manual skill `/pre-compact-save`

A new skill under `.claude/skills/pre-compact-save/SKILL.md`. Mirrors the shape of `end-session` but:

- `disable-model-invocation: false` — the coordinator (or Duong) can invoke it directly. Unlike `/end-session`, there's no catastrophic failure mode if it fires by accident; worst case it produces a redundant consolidation.
- The skill body is thin: it prepares the context (pulls session_id, transcript_path, detects the active coordinator) and **spawns Lissandra via the Agent tool** with a fully-formed task prompt. Lissandra does the actual work.
- After Lissandra returns, the skill verifies the sentinel was created and the commit landed. On success, reports the artifact paths and exits.

The skill is the **primary** entry point. The PreCompact hook is really just a gatekeeper that nudges the user toward the skill.

#### 3.2.1 Skill argument

`$ARGUMENTS` optional — if empty, Lissandra auto-detects the coordinator from greeting/concern context in the live jsonl (see §4.1). If supplied (`evelynn` or `sona`), overrides detection. Detection failure with no argument → skill refuses with a diagnostic.

## 4. Coordinator impersonation protocol

Lissandra's job is to run a trimmed-down version of the coordinator's `/end-session` protocol while writing in the coordinator's voice. Not her own.

### 4.1 Detect active coordinator

1. Bash: read the latest ~200 user-role turns from the session jsonl at `transcript_path` (provided by the hook payload, or discovered via `~/.claude/projects/<slug>/<session-id>.jsonl` when invoked from the skill).
2. Look for greeting markers in the first few user messages:
   - `Hey Sona` (case-insensitive, anywhere in first 3 user messages) → coordinator = sona.
   - No greeting or `Hey Evelynn` → coordinator = evelynn (repo default per CLAUDE.md §Caller Routing).
3. Cross-check: look for `[concern: work]` or `[concern: personal]` tags on spawned subagent prompts. If the greeting says Sona but every subagent prompt is `[concern: personal]`, flag the inconsistency and refuse; Duong resolves.

### 4.2 Execute the coordinator's close protocol (selectively)

Run the Evelynn or Sona variant of the `/end-session` protocol, minus the full-transcript clean step (too expensive for a mid-session consolidation — we don't own the full session yet).

**For Evelynn (per end-session skill steps 6–8, Evelynn branch):**
- Step 6 (handoff shard): write `agents/evelynn/memory/last-sessions/<short-uuid>.md` with the 5–10 line structured handoff. UUID is a fresh one generated at consolidation time (not the session-id — sessions accumulate multiple compacts and each needs its own shard).
- Step 7 (session shard): write `agents/evelynn/memory/sessions/<short-uuid>.md` with the `## Session YYYY-MM-DD (SN, <mode>)` heading + one-line summary + delta notes.
- Step 8 (learnings): **conditional**. Apply the `/end-subagent-session` decision gate (is there a durable fact / generalizable lesson / resolved open question?). If yes, write `agents/evelynn/learnings/<YYYY-MM-DD>-<topic>.md` + append to `learnings/index.md`. If no, skip and note "no learnings this consolidation" in the report. **This is the key judgment call** — Lissandra must not flood the coordinator's learnings dir with routine-session noise.

**For Sona:** same, with `agents/sona/` paths. Sona does not use the same sharded-write bypass as Evelynn (that bypass is Evelynn-specific per the memory-sharding plan); Lissandra still writes session + last-session shards to Sona's sharded dirs. Verified 2026-04-20: `agents/sona/memory/last-sessions/` and `agents/sona/memory/sessions/` both exist — sharded layout is live. See §7 Q2 resolution.

### 4.3 Partial transcript excerpt

Lissandra does NOT run `scripts/clean-jsonl.py` (that's for full session close, and the session is still alive). Instead she writes a compact-scoped excerpt:

`agents/<coordinator>/transcripts/compact-<YYYY-MM-DD>-<short-uuid>.md`

Contents: the last N turns (default N=50) of the live jsonl, cleaned via the same cleaner in a new `--since-last-compact` mode. If that mode doesn't exist yet, the cleaner needs a small addition — tracked as a task in §6. Fallback for phase 1: skip the transcript excerpt, note "compact-excerpt deferred — requires cleaner --since-last-compact" in the handoff shard.

### 4.4 Journal entry

Append to `agents/<coordinator>/journal/cli-<YYYY-MM-DD>.md` a first-person reflection in the **coordinator's voice**. Header: `## Compact consolidation HH:MM` (so multiple compacts per day are distinguishable from the end-session entry). 10–20 lines typical. Lissandra signs off with a marker: `--- consolidated by Lissandra (pre-compact) ---`. This gives provenance without diluting the coordinator-voice prose.

### 4.5 Commit

Single commit, `chore:` prefix, mentioning both Lissandra and the coordinator:

```
chore: lissandra pre-compact consolidation for <coordinator> — YYYY-MM-DD session <short-uuid>

Consolidated mid-session artifacts before /compact:
- handoff shard: agents/<coordinator>/memory/last-sessions/<uuid>.md
- session shard: agents/<coordinator>/memory/sessions/<uuid>.md
- journal append: agents/<coordinator>/journal/cli-YYYY-MM-DD.md
- learnings: <path or "none this consolidation">
- transcript excerpt: <path or "deferred">

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Push. On pre-push hook rejection: same policy as `/end-session` — stop, do not retry, report verbatim.

### 4.6 Sentinel

Touch `/tmp/claude-precompact-saved-<session_id>` so the PreCompact hook can detect the completion on re-run.

### 4.7 Final report

Lissandra returns a one-paragraph report to her caller (the skill, which passes it back to the coordinator). Includes: coordinator detected, artifacts written, commit hash, push status, any skipped steps, any warnings.

## 5. Hook matrix update

`scripts/hooks/pre-commit-agent-shared-rules.sh` enforces the model-family convention for every paired and single-lane slot (§4.3 of `architecture/agent-pair-taxonomy.md`). A new role slot value `memory-consolidator:single_lane` must be added to the `is_sonnet_slot()` function:

```bash
is_sonnet_slot() {
  # ... existing cases ...
  # Single-lane Sonnet agents (must declare model: sonnet)
  "qa:single_lane")                      return 0 ;;  # Akali
  "memory:single_lane")                  return 0 ;;  # Skarner
  "memory-consolidator:single_lane")     return 0 ;;  # Lissandra — NEW
  "errand:single_lane")                  return 0 ;;  # Yuumi
  "devops-exec:single_lane")             return 0 ;;  # Ekko
  # ...
}
```

No other hook changes needed — the pair-mate symmetry check (§4.2 of the taxonomy doc) already skips single-lane agents (no `pair_mate:` frontmatter = no reverse check). The shared-rules drift check (§4.1) already skips agents without an include marker.

### 5.1 Taxonomy doc update

`architecture/agent-pair-taxonomy.md` §1.1 "Single-lane roles" table: add a new row between Skarner (row 15) and Yuumi (row 16), renumbering downstream:

```
| 16 | Memory consolidator | Lissandra (Sonnet medium) |
```

Shift row numbers for Yuumi (→ 17) and Camille (→ 18). Stable row numbers are not referenced anywhere else in the doc, so renumbering is safe.

## 6. Tasks (Kayn breakdown, 2026-04-20)

Eleven tasks, ordered logically. Owner column resolved; TDD pairings noted
per Rule 12. All tasks commit `chore:` per CLAUDE.md Rule 5.

| ID   | Task                                                                 | Owner                    | Depends on           | TDD  | estimate_minutes |
|------|----------------------------------------------------------------------|--------------------------|----------------------|------|------------------|
| T1   | Add `memory-consolidator:single_lane` to `is_sonnet_slot()` + test   | Ekko                     | —                    | yes  | 30               |
| T2   | Create `.claude/agents/lissandra.md` (top-level — harness blocked)   | Evelynn (dispatch only)  | T1                   | no   | 20               |
| T3   | Write `.claude/skills/pre-compact-save/SKILL.md`                     | Jayce                    | —                    | no   | 30               |
| T4   | Write `scripts/hooks/pre-compact-gate.sh`                            | Jayce                    | —                    | yes  | 45               |
| T5   | Wire PreCompact into `.claude/settings.json` + smoke-confirm         | Jayce                    | T3, T4               | no   | 15               |
| T6   | Create `agents/lissandra/` scaffold + index + profile + MEMORY       | Yuumi                    | —                    | no   | 20               |
| T7   | Update `architecture/agent-pair-taxonomy.md` §1.1 table (+1 row)     | Yuumi                    | —                    | no   | 10               |
| T8   | Update `agents/memory/agent-network.md` roster entry                 | Yuumi                    | —                    | no   | 10               |
| T9   | Documentation: `/compact` workflow blurb in `CLAUDE.md`              | Yuumi                    | T2, T3, T5           | no   | 15               |
| T10  | (Deferred to phase 2 per OQ-Q3) `clean-jsonl.py --since-last-compact`| —                        | —                    | —    | —                |
| T11  | Manual E2E verification (Evelynn + Sona) + report                    | Vi                       | T1–T9                | no   | 60               |

### 6.1 Task detail

- **T1 — hook slot registration (Ekko, TDD)**
  Add `"memory-consolidator:single_lane") return 0 ;;` to `is_sonnet_slot()`
  in `scripts/hooks/pre-commit-agent-shared-rules.sh` (after the
  `memory:single_lane` case at line 85). Land the xfail test first:
  create a test fixture agent file that would trip the slot check, wire
  into whatever ad-hoc test script already exercises the hook (grep the
  repo for existing `is_sonnet_slot` invocations before writing a new
  harness). Xfail commit precedes impl commit on the same branch.

- **T2 — Lissandra agent definition (Evelynn top-level dispatch)**
  Create `.claude/agents/lissandra.md` per §2.1 frontmatter plus 3–5 line
  personality block, startup sequence (read CLAUDE.md → this file →
  inbox → learnings → memory), and the inline consolidation protocol
  body (§4). Body < 250 lines. No `_shared/` include. **This write is
  blocked inside the subagent harness** — Evelynn executes it at top
  level (or delegates to a sub-session Evelynn spawns with
  `.claude/agents/*.md` write permissions). Depends on T1 so the
  pre-commit hook recognises the new slot.

- **T3 — `/pre-compact-save` skill (Jayce)**
  Write `.claude/skills/pre-compact-save/SKILL.md`. Mirror the
  `end-session` skill header but set `disable-model-invocation: false`.
  Body: ~30 lines. Takes optional `$ARGUMENTS` = `evelynn`|`sona`. Skill
  steps:
  a. detect coordinator
  b. spawn Lissandra via Agent tool with a fully-formed task prompt carrying `session_id`, `transcript_path`, `coordinator`
  c. verify sentinel + commit on return
  d. report artifacts

- **T4 — PreCompact gate script (Jayce, TDD)**
  Write `scripts/hooks/pre-compact-gate.sh` per §3.1.1. POSIX bash (Rule
  10), < 50 LOC. Reads JSON from stdin via `jq`, checks
  `.no-precompact-save` at repo root and `/tmp/claude-precompact-saved-<sid>`
  sentinel, emits `{"decision":"block",...}` JSON or exits 0. Xfail
  test first: shell-based fixture driver that pipes representative
  payloads in and asserts on stdout/exit-code. Park under
  `scripts/hooks/tests/pre-compact-gate.test.sh` (create the dir; no
  existing `scripts/tests/` — flagged).

- **T5 — settings.json hook registration (Jayce)**
  Add the `PreCompact` block per §3.1.3 to `.claude/settings.json`.
  Smoke-confirm the shape by dry-running `bash
  scripts/hooks/pre-compact-gate.sh < sample.json` locally. No automated
  test — settings files are not unit-testable; Rule 12 xfail-exempt per
  the T0 precedent (usage-dashboard attribution, 2026-04-19).

- **T6 — Lissandra agent directory scaffold (Yuumi)**
  Create `agents/lissandra/` with: `profile.md` (short bio + role +
  mechanics recap), `memory/MEMORY.md` (header + empty sections),
  `learnings/` (dir), `learnings/index.md` (header only),
  `transcripts/` (dir, keep empty via `.gitkeep`). Mirror the shape of
  `agents/skarner/` (single-lane sibling). Independent of T2.

- **T7 — taxonomy doc row (Yuumi)**
  Insert new row 16 "Memory consolidator | Lissandra (Sonnet medium)"
  between current row 15 (Skarner) and row 16 (Yuumi) in
  `architecture/agent-pair-taxonomy.md` §1.1. Renumber Yuumi → 17,
  Camille → 18. Verified against live file 2026-04-20: rows are
  currently 15/16/17 as the ADR asserts.

- **T8 — roster entry (Yuumi)**
  Add Lissandra to `agents/memory/agent-network.md` under single-lane
  specialists near Skarner: one-line description "pre-compact memory
  consolidator; mirrors coordinator /end-session protocol when /compact
  is imminent."

- **T9 — `/compact` workflow docs (Yuumi)**
  Add a short subsection to `architecture/compact-workflow.md` (create
  it) and add a pointer from the `CLAUDE.md` "File Structure" table. Content: "Run `/pre-compact-save` before
  `/compact`, or the PreCompact hook will block the first compact once.
  To opt out, `touch .no-precompact-save` at repo root." Depends on T2,
  T3, T5 so docs don't front-run the mechanism.

- **T10 — DEFERRED** to a phase-2 follow-up plan. Per OQ-Q3 resolution
  below, phase 1 ships without compact-transcript excerpts; Lissandra's
  handoff shard notes "transcript excerpt deferred — requires cleaner
  `--since-last-compact`." Kayn opens a follow-up stub after T11 passes.

- **T11 — manual E2E verification (Vi)**
  In a disposable session, greet Evelynn, do representative work,
  `/compact`, observe block, `/pre-compact-save`, observe consolidation
  artifacts (handoff + session + journal + optional learning + commit +
  sentinel), re-run `/compact`, observe allow. Repeat with Sona
  greeting. Report to
  `assessments/personal/2026-04-20-lissandra-verification.md`. Must pass
  before the plan promotes to `implemented/`.

### 6.2 Dependency graph

```
         T1 ─────► T2 ────────────┐
         (xfail, impl)            │
                                  │
  T3 ───┐                         ├──► T9 (docs)
  T4 ───┤                         │
  (xfail, impl)                   │
        ├──► T5 ──────────────────┤
  T6 (scaffold) ──────────────────┤
  T7 (taxonomy) ──────────────────┤
  T8 (network) ───────────────────┤
                                  │
                                  ▼
                                 T11 (Vi E2E)
```

Parallel waves:
- **Wave 1** (no prereqs): T1-xfail, T3, T4-xfail, T6, T7, T8.
- **Wave 2** (after Wave 1 impls land): T1-impl, T4-impl, T2 (needs T1).
- **Wave 3** (after T2, T3, T4): T5, T9.
- **Wave 4** (after everything): T11.

## 7. Open questions — RESOLVED (Kayn, 2026-04-20)

All eight open questions resolved inline during Kayn task breakdown, per
Duong's authorization to decide all of them. Resolutions are binding on
execution; any deviation requires a superseding amendment.

- **Q1 — Thinking budget: 5000 vs 6000?**
  **Resolved: 6000.** §2.1's 6000-token budget ships as-is for phase 1.
  Matches Azir's recommendation. Rationale: coordinator-voice
  extraction plus the learnings-vs-routine decision gate are both
  judgment-heavy; the 1000-token headroom above Sonnet-medium standard
  costs little and buys quality. Evelynn may drop to 5000 in a later
  amendment if outputs feel over-cooked after 5+ real compactions.

- **Q2 — Sona's close-protocol sharding parity.**
  **Resolved: assume sharded; write flat and fix-forward if absent.**
  Verified 2026-04-20: `agents/sona/memory/last-sessions/` and
  `agents/sona/memory/sessions/` both exist. Lissandra writes to those
  sharded paths uniformly for both coordinators. If at Lissandra's
  first real Sona invocation the dirs turn out to be stubs (no shard
  files yet), her write is still structurally valid — she populates the
  first shard. No branching logic needed. The concurrency bypass is
  Evelynn-specific; Lissandra uses sharded writes for both coordinators.

- **Q3 — Compact-transcript excerpt: phase 1 skip or T10 now?**
  **Resolved: skip phase 1 (T10 deferred).** Phase 1 ships six
  artifacts per consolidation (handoff, session, journal, learning-if-
  warranted, commit, sentinel) — no transcript excerpt. Lissandra's
  handoff shard includes the line "transcript excerpt deferred —
  phase 2 via `clean-jsonl.py --since-last-compact`." Follow-up plan
  stub opens after T11 passes.

- **Q4 — Opt-out sentinel location.**
  **Resolved: repo root `.no-precompact-save`.** Most discoverable; a
  visible-by-default dotfile that Duong can create or remove with one
  command. Not under `.claude/` (harder to find) and not an env var
  (doesn't travel with the repo, brittle under tmux / multiple shells).
  T4's gate script stat()s `$REPO_ROOT/.no-precompact-save`.

- **Q5 — Auto-compact behavior during long sessions.**
  **Resolved: Option A (allow silently).** Per §3.1.2. Auto-compact
  fires only on context overflow — blocking would be hostile and often
  unobserved. T4's script registers `"matcher": "manual"` only;
  auto-compact never touches the gate. SystemMessage variant explicitly
  deferred — revisit in a follow-up plan only if Duong reports
  information loss during auto-compact.

- **Q6 — Lissandra's own memory.**
  **Resolved: stateless.** Lissandra keeps a profile but her
  `memory/MEMORY.md` stays minimal (same shape as Skarner). Her
  `/end-subagent-session` closing protocol writes learnings only on
  genuinely generalizable findings (same decision gate she applies to
  the coordinator). Cross-invocation pattern detection ("coordinator X
  compacts 3x per session, advise") is a phase-2 concern.

- **Q7 — Fire at `/clear`?**
  **Resolved: out of scope for this ADR.** `/clear` behavior tracked as
  follow-up. If phase 1 works for `/compact`, Kayn opens a sibling ADR
  proposing a PreClear hook (if one exists in Claude Code's hook
  reference) or a systemMessage-based nudge. Until then, `/clear`
  remains Duong's responsibility.

- **Q8 — Hook blocking friction tax.**
  **Resolved: ship block-and-prompt as-is.** §3.1.1 flow lands
  unchanged. Revisit only if Duong reports concrete friction after
  real-world use (≥ 3 sessions). Alternative patterns (silent
  fire-and-forget, post-compact warning banner) filed as phase-2
  candidates only.

## 8. Acceptance criteria

The plan is implemented when:

1. `.claude/agents/lissandra.md` exists, passes the pre-commit hook (shared-rules + model-convention checks), and conforms to §2.1 frontmatter.
2. `scripts/hooks/pre-compact-gate.sh` exists, is POSIX-portable, and correctly emits `block` vs `allow` decisions based on sentinel state.
3. `.claude/skills/pre-compact-save/SKILL.md` exists with `disable-model-invocation: false` and spawns Lissandra.
4. `.claude/settings.json` registers the PreCompact hook under `"matcher": "manual"`.
5. `scripts/hooks/pre-commit-agent-shared-rules.sh` recognizes `memory-consolidator:single_lane` as a Sonnet slot.
6. `architecture/agent-pair-taxonomy.md` §1.1 lists Lissandra in the single-lane table.
7. Manual end-to-end verification passes for both Evelynn and Sona sessions (T11).
8. `.no-precompact-save` sentinel at repo root correctly bypasses the hook.

## Test plan

Three test tasks cover the plan's testable surface area.

**T1 — Hook slot registration (`scripts/hooks/test-hooks.sh`).**
An xfail test case is added before the implementation commit. The test creates a fixture agent file declaring `role_slot: memory-consolidator` and `tier: single_lane` and asserts the hook rejects an `opus` model declaration while accepting `sonnet`. The slot registration test is covered by the shared hook test suite at `scripts/hooks/test-hooks.sh`; run with `bash scripts/hooks/test-hooks.sh`; must be green before T1-impl merges. (Note: the xfail was wired into `test-hooks.sh` rather than a standalone `pre-commit-agent-shared-rules.test.sh` — naming corrected here from the original task breakdown.)

**T4 / T6 — PreCompact gate unit tests (`scripts/hooks/tests/pre-compact-gate.test.sh`).**
A shell-based fixture driver pipes representative JSON payloads (no sentinel, sentinel present, `.no-precompact-save` present) into `scripts/hooks/pre-compact-gate.sh` and asserts on stdout JSON and exit code. Three cases: block emitted when no sentinel, exit 0 when sentinel present, exit 0 when opt-out dotfile present. Run with `bash scripts/hooks/tests/pre-compact-gate.test.sh`. The xfail commit precedes the T4-impl commit on the same branch.

**T11 — Manual E2E verification (Vi).**
Vi runs a full `/compact` + `/pre-compact-save` flow in a disposable Evelynn session and a disposable Sona session. For each: greet coordinator, do representative work, type `/compact`, observe block message, run `/pre-compact-save`, verify handoff shard + session shard + journal entry + commit land in `agents/<coordinator>/`, re-run `/compact`, observe allow. Results written to `assessments/personal/2026-04-20-lissandra-verification.md`. T11 must pass before the plan moves to `implemented/`.

## Test results

All 8 acceptance checks PASS per Vi's verification assessment (`assessments/personal/2026-04-20-lissandra-verification.md`, commit `64f7e04`).

| Check | Result |
|---|---|
| Hook matrix drift (pre-commit-agent-shared-rules.sh registers `memory-consolidator:single_lane`) | PASS |
| Agent def validity (`.claude/agents/lissandra.md` passes pre-commit hook) | PASS |
| Skill manifest (`.claude/skills/pre-compact-save/SKILL.md` present, `disable-model-invocation: false`) | PASS |
| Hook unit tests — `scripts/hooks/tests/pre-compact-gate.test.sh` (5/5 cases) | PASS |
| settings.json wiring (`PreCompact` block, `matcher: manual`) | PASS |
| Four hook decision paths (no sentinel → block; sentinel → allow; opt-out dotfile → allow; auto-compact matcher absent → allow) | PASS |
| Coordinator detection (Evelynn and Sona sessions both correctly identified) | PASS |
| Taxonomy row (`architecture/agent-pair-taxonomy.md` §1.1 lists Lissandra at row 16) | PASS |

Non-blocking hygiene gap noted: `scripts/hooks/pre-compact-gate.sh` not `chmod +x` (bash invocation via settings.json does not require it; no gate block).

Deferred (not blocking): live `/compact` trigger end-to-end with real shard writes requires an interactive Duong session; tracked as phase-2 follow-up per Q3 resolution.

## 9. Rollback

If the block-and-prompt flow proves too friction-heavy:
1. Remove the `PreCompact` block from `.claude/settings.json` (hook disabled).
2. Keep `/pre-compact-save` as a manual-only skill — Duong invokes when he remembers. No code removal needed.
3. Filed as a follow-up plan to redesign trigger UX.

If Lissandra's consolidations produce bad artifacts (wrong coordinator voice, over-learning, etc.):
1. Remove the agent def (`.claude/agents/lissandra.md`) and the skill.
2. Revert the `is_sonnet_slot()` addition (not strictly necessary, but keeps the matrix clean).
3. Artifacts already written stay — they are committed, and manual cleanup is cheap.

---

**Handoff (updated 2026-04-20 by Kayn):** task breakdown inlined in §6
(no sibling `-tasks.md` — this plan is the single source of truth per
the Orianna-gated lifecycle's one-plan-one-file norm). All eight OQs
resolved in §7. Owner column assigned. Ready for Evelynn's executor
dispatch: T1 (Ekko) first; Waves 2–4 per §6.2.
