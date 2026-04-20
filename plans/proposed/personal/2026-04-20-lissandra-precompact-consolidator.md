---
status: proposed
orianna_gate_version: 2
concern: personal
complexity: normal
author: azir
date: 2026-04-20
tags: [agent-addition, memory, session-lifecycle, hooks]
supersedes: []
related:
  - plans/implemented/2026-04-20-agent-pair-taxonomy.md
  - architecture/agent-pair-taxonomy.md
  - .claude/skills/end-session/SKILL.md
  - .claude/skills/end-subagent-session/SKILL.md
  - plans/approved/2026-04-18-evelynn-memory-sharding.md
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
- Never modifies `.claude/settings.json`, `.claude/hooks/`, or other coordinator-global state. Her output is append-only artifacts.

### 2.5 What Lissandra is not

- Not a replacement for `/end-session`. The end-session skill still runs at actual session end. Lissandra runs at *compact boundaries*, which are more frequent and of lower stakes.
- Not a replacement for the `remember:remember` plugin. Evelynn bypasses that plugin for concurrency reasons (per `plans/approved/2026-04-18-evelynn-memory-sharding.md` §D6); Lissandra follows the same sharded-write discipline.
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

**For Sona:** same, with `agents/sona/` paths. Sona does **not** bypass `remember:remember` for concurrency (that bypass is Evelynn-specific per the memory-sharding plan); Lissandra still writes session + last-session shards to Sona's sharded dirs, matching Sona's own close protocol. [Open question — see §7 Q2: does Sona's close protocol match Evelynn's sharding exactly, or does Sona use the `remember:remember` plugin? Verify at implementation time.]

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

## 6. Inline tasks (for Kayn breakdown)

Ready for Kayn to expand into a tasks file. Tasks are in logical order; Kayn may split/merge as needed.

- **T1** Add `memory-consolidator:single_lane` case to `is_sonnet_slot()` in `scripts/hooks/pre-commit-agent-shared-rules.sh`. Add a test fixture for a fake `memory-consolidator` agent in the existing hook test suite (if one exists; otherwise add a minimal fixture). Commit `chore:`. xfail-first per Rule 12 — the test for the new case must land in a separate prior commit.

- **T2** Update `architecture/agent-pair-taxonomy.md` §1.1 single-lane table with Lissandra row; renumber downstream rows. Commit `chore:`.

- **T3** Create `.claude/agents/lissandra.md` with the frontmatter shape from §2.1, personality block (3–5 lines), startup sequence, and the inline consolidation protocol body. Keep the body < 250 lines. No `_shared/` file — single-lane. Verify the pre-commit hook passes (should require T1 first). Commit `chore:`.

- **T4** Create `agents/lissandra/` directory scaffold: `profile.md`, `memory/MEMORY.md` (empty), `learnings/` (empty), `learnings/index.md` (empty). Follow the pattern of `agents/skarner/` if it exists, else `agents/yuumi/`. Commit `chore:`.

- **T5** Write `.claude/skills/pre-compact-save/SKILL.md`. Mirror `end-session` skill structure but thinner — the skill prepares context and spawns Lissandra. `disable-model-invocation: false`. Takes optional coordinator argument. See §3.2 for the full flow. Commit `chore:`.

- **T6** Write `scripts/hooks/pre-compact-gate.sh` per §3.1.1. POSIX-portable bash (Rule 10). < 50 LOC. Unit-testable: given a JSON payload on stdin and presence/absence of the sentinel file, emits the right decision. Add a small test harness in `scripts/tests/` if the repo has one; otherwise defer to manual verification. Commit `chore:`. xfail-first per Rule 12.

- **T7** Wire the PreCompact hook registration into `.claude/settings.json` — `"PreCompact": [{"matcher": "manual", "hooks": [{"type": "command", "command": "bash scripts/hooks/pre-compact-gate.sh"}]}]`. Commit `chore:`. Smoke-test manually by running `/compact` in a test session and verifying the block-and-prompt flow.

- **T8** Update `agents/memory/agent-network.md` to include Lissandra in the roster (under single-lane specialists, near Skarner). Describe her as "pre-compact memory consolidator, mirrors coordinator /end-session protocol when /compact is imminent." Commit `chore:`.

- **T9** (Optional, defer if bandwidth tight) Add `--since-last-compact` mode to `scripts/clean-jsonl.py`. Looks up the last PreCompact event in the jsonl (or the last Lissandra commit touching this session's transcripts dir) and outputs only the delta. If this task is deferred, T5's skill falls back to the "transcript excerpt deferred" message per §4.3. Commit `chore:`. xfail-first.

- **T10** Documentation — add a short section to `CLAUDE.md` (or the appropriate coordinator-specific doc) explaining the `/compact` workflow: "run `/pre-compact-save` before `/compact`, or the hook will block you once. To opt out, `touch .no-precompact-save`." Commit `chore:`.

- **T11** Manual end-to-end verification in a disposable session: Evelynn greeting, do some work, run `/compact`, observe block, run `/pre-compact-save`, observe consolidation, re-run `/compact`, observe success. Repeat for Sona. Document results in `assessments/personal/2026-04-20-lissandra-verification.md` (new file).

**Task ordering note:** T1 → T2 → T3 → T4 can run in parallel after T1 lands. T5 depends on T3 and T4. T6 and T7 can run in parallel with T5. T8 can run anytime after T3. T9 is optional. T10 and T11 are last.

## 7. Open questions

All marked "Evelynn decides during execution" unless otherwise noted.

- **Q1 — Thinking budget: 5000 vs 6000?** §2.1 proposes 6000 (above the standard Sonnet-medium 5000). Rationale: judgment-heavy summarization + coordinator-voice extraction. Could also argue 5000 is enough if we keep the decision-gate narrow. **Evelynn decides during execution** — try 6000, drop to 5000 if Lissandra's outputs feel over-cooked.

- **Q2 — Sona's close-protocol sharding parity.** §4.2 notes Sona may or may not use the same `last-sessions/` + `sessions/` sharding that Evelynn uses (memory-sharding plan explicitly scoped to Evelynn). Verify at T5 implementation time: does `agents/sona/memory/last-sessions/` exist? Does Sona's `/end-session` invocation use `remember:remember` or a sharded fallback? **Evelynn decides during execution** after inspection — Lissandra's protocol branches accordingly.

- **Q3 — Compact-transcript excerpt: phase 1 skip or T9 now?** §4.3 and T9. If T9 is too much scope for the first cut, skip and leave a marker. **Evelynn decides during execution** — default to skip if Kayn's breakdown would push this plan past 10 tasks.

- **Q4 — Opt-out sentinel location: repo root vs `.claude/` vs env var?** §3.1.1 proposes `.no-precompact-save` in the repo root. Alternatives: `.claude/.no-precompact-save` (less visible but co-located with hook config), or `STRAWBERRY_PRECOMPACT_DISABLE=1` env var. **Evelynn decides during execution** — repo root is the most discoverable option, leaning there.

- **Q5 — Auto-compact behavior during long sessions.** §3.1.2 chose Option A (allow silently). Alternative: emit a `systemMessage` additionalContext that tells the post-compact context "the pre-compact consolidation was skipped due to auto-trigger — run `/pre-compact-save` now if you want to preserve pre-compact state." **Evelynn decides during execution** — Option A is safer; the systemMessage variant can be layered on later.

- **Q6 — Granularity of Lissandra's own memory.** Does Lissandra herself accumulate memory across invocations (e.g., "coordinator X frequently compacts 3x per session, consider advising")? Or is she stateless like Skarner? Lean stateless for now — she has a profile but empty memory, and her own close protocol (via `/end-subagent-session`) writes only when she genuinely learns something generalizable. **Evelynn decides during execution.**

- **Q7 — Should Lissandra also fire at `/clear`?** `/clear` is more destructive than `/compact` (dumps context entirely). Arguably needs *more* consolidation, not less. Out of scope for this ADR — propose a follow-up plan if the pattern works for `/compact`. **Evelynn decides during execution** — for this ADR, PreCompact only.

- **Q8 — Hook blocking on first compact: friction tax vs. safety.** §3.1.1 always blocks the first compact per session without a sentinel. This adds one round-trip per session. Alternative: silent consolidation (fire-and-forget — the coordinator runs Lissandra automatically via a stdout systemMessage nudge, no block). Rejected for this ADR because silent fire-and-forget would mean the hook *does* need to spawn a subagent, which it can't. **Evelynn decides during execution** — if the block is annoying in practice, revisit with a post-compact "warning banner" pattern instead.

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

**Handoff:** this plan is ready for Kayn to break into tasks. The T-numbered list in §6 is the starting point; Kayn will refine ordering, add xfail test scaffolds per Rule 12, and produce the `*-tasks.md` sibling plan.
