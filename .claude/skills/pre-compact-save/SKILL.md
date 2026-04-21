---
name: pre-compact-save
description: Run Lissandra on the current coordinator session — consolidate memory shards, handoff note, journal, and learnings BEFORE /compact compresses the context. Use this when you want to preserve session state across a compact without running the full /end-session. Invoked manually by the coordinator (or Duong) when /compact is imminent. The PreCompact hook will nudge you to run this skill first.
disable-model-invocation: false
---

# /pre-compact-save — Pre-Compact Memory Consolidation

## When to use

- Before running `/compact` on an Evelynn or Sona coordinator session
- When the PreCompact hook blocks `/compact` and asks you to consolidate first
- When you want a mid-session snapshot without ending the session

## When NOT to use

- Subagent sessions (out of scope — Lissandra only handles coordinator sessions)
- Actual session end (use `/end-session` instead — it produces the full transcript archive)
- Immediately after a recent consolidation (redundant; worst case it produces a duplicate)

## Arguments

`$ARGUMENTS` (optional): `evelynn` or `sona` to override auto-detection. Empty → auto-detect from session greeting.

## Protocol

1. **Preflight.**
   - Read the session jsonl path: `~/.claude/projects/<project-slug>/<session-id>.jsonl`. Derive `session_id` and `transcript_path` from the current environment.
   - If `$ARGUMENTS` is non-empty, use it as the coordinator. Otherwise detect:
     - Scan the first 3 user messages for `Hey Sona` (case-insensitive) → coordinator = `sona`
     - Otherwise coordinator = `evelynn` (repo default per CLAUDE.md Caller Routing)
   - Cross-check `[concern: work]` vs `[concern: personal]` tags on subagent prompts. Contradiction → refuse with a diagnostic.

2. **Spawn Lissandra** via the Agent tool with `subagent_type: "Lissandra"`. Note: Lissandra updates `open-threads.md` and regenerates `INDEX.md` as part of the coordinator shard write, same as `/end-session` Step 6b. Prompt shape:

   ```
   [concern: <personal|work>]

   Consolidate this coordinator session before /compact. You are impersonating <coordinator>.

   - session_id: <uuid>
   - transcript_path: <absolute path to jsonl>
   - coordinator: <evelynn|sona>

   Run the full protocol in your agent definition (handoff shard, session shard, conditional learnings, journal entry, optional transcript excerpt, commit, sentinel). Write to `agents/<coordinator>/...` directories only. Use the coordinator's first-person voice.

   Report back with: artifact paths, commit SHA, push status, skipped steps (if any), warnings.
   ```

3. **On Lissandra return:**
   - Verify the sentinel file exists at `/tmp/claude-precompact-saved-<session_id>`. If not, report failure and exit — the PreCompact hook will still block on next `/compact`.
   - Verify the commit landed on main. `git log -1 --format='%H %s'` should show Lissandra's consolidation commit.
   - Report the artifact paths + commit SHA back to the coordinator.

4. **Done.** Coordinator can now safely run `/compact`; the PreCompact hook will see the sentinel and allow compaction.

## Failure modes

- **Coordinator detection contradiction** — refuse, surface the inconsistency. Duong resolves manually by supplying `$ARGUMENTS`.
- **Lissandra commit rejected by pre-push hook** — Lissandra reports verbatim. Do not retry; let Duong diagnose.
- **No sentinel after Lissandra return** — indicates Lissandra's final step didn't fire. Report and exit without touching the sentinel ourselves (the sentinel is Lissandra's signature that she completed).

## What this skill does NOT do

- Does not run `/end-session`. That skill is `disable-model-invocation: true` for a reason.
- Does not compact. You still run `/compact` yourself after this skill succeeds.
- Does not archive the full session transcript. That is end-session's job.
