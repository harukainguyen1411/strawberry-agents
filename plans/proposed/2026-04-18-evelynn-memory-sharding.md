---
title: Evelynn memory sharding — per-session shards, consolidate-on-boot, SessionStart read-N
owner: lux
status: proposed
date: 2026-04-18
scope:
  - .claude/skills/end-session/SKILL.md
  - agents/evelynn/memory/evelynn.md
  - agents/evelynn/memory/last-session.md
  - agents/evelynn/memory/sessions/
  - agents/evelynn/memory/last-sessions/
  - agents/evelynn/memory/sessions/archive/
  - .claude/settings.json (SessionStart hook)
  - .remember/remember.md (remember:remember plugin audit)
why: >
  Evelynn's memory is currently a single `evelynn.md` + single `last-session.md`. Any two
  sessions ending in the same window race on the same files, and a manual merge loses the
  session row silently. Sharding by session UUID eliminates the race without requiring a
  lock; a single-writer consolidation pass at boot folds shards into a roll-up so the file
  doesn't grow unbounded. This plan operationalizes the advisory Duong already greenlit.
---

# Evelynn Memory Sharding

## Open questions for Duong

1. **Retention window for `sessions/archive/`.** Plan proposes "never delete during consolidation." Duong — keep forever, or prune at N days? Default in plan is keep forever; a later prune plan can be drafted separately.
2. **`last-sessions/` read depth.** Plan proposes "last ~5 by mtime." Duong — confirm 5 or a different number? If Evelynn runs multiple sessions per day this affects startup context size.
3. **Remember plugin treatment.** Plan proposes "explicitly bypass `remember:remember` for Evelynn and document why" (Option B below). Duong — confirm bypass vs. shard the plugin output too (Option A)?

---

## Problem

Evelynn's persistent memory today lives in two single files:

- `agents/evelynn/memory/evelynn.md` — operational roll-up, appended to by every `/end-session` run (Step 7 of the skill).
- `agents/evelynn/memory/last-session.md` — single-slot handoff, overwritten by every `/end-session` run when the `remember:remember` plugin is unavailable (Step 6 fallback).

Two concurrent `/end-session` invocations (Mac session + Windows Vex session closing near-simultaneously; or Evelynn closing while another branch of herself is resumed) race on the same files. Git merges will resolve textually but silently drop rows — the `## Sessions` list is line-level, no conflict markers get produced when both sides add a new bullet at the end.

Additionally, `.claude/skills/end-session/SKILL.md` has a frontmatter / docstring inconsistency: line 4 declares `disable-model-invocation: false`, but the "Refusal posture" section at the bottom says "You are `disable-model-invocation: true`." CLAUDE.md Rule 8 also asserts disable-model-invocation: true for top-level `/end-session`. The frontmatter is the lie.

The `remember:remember` plugin (`.remember/remember.md`) has the same single-file shape and the same race surface if it is ever re-enabled or runs at the same time as our manual fallback.

## Decisions

**D1. Shard-on-close, UUID-keyed.** Every `/end-session` run writes a new shard at `agents/evelynn/memory/sessions/<short-uuid>.md`. The `<short-uuid>` is the exact same short UUID the cleaner already assigns to the transcript filename in Step 2 — reuse it, do not generate a second one. No write contention because every session's UUID is unique.

**D2. Handoff shards, UUID-keyed.** The last-session handoff (current `last-session.md` fallback) becomes `agents/evelynn/memory/last-sessions/<short-uuid>.md`. SessionStart reads the **last 5** by mtime (Duong to confirm in Open Questions).

**D3. Consolidate-on-boot, never-delete.** At the start of a fresh (non-resumed) Evelynn session, a consolidation step runs **before** the startup reads. It is the only writer to the roll-up because no other session is starting at the exact same moment — the consolidation window is the narrow "booting" moment. It:
  a. Finds shards in `agents/evelynn/memory/sessions/` with mtime older than 24h.
  b. Appends their content (as Markdown sections, in mtime order) to a fresh roll-up file `agents/evelynn/memory/evelynn-rollup.md`.
  c. `git mv` (not delete) each consolidated shard into `agents/evelynn/memory/sessions/archive/<short-uuid>.md`.
  d. Stages and commits the consolidation with message `chore: evelynn memory consolidation <YYYY-MM-DD>` — a background, agent-authored commit, separate from session close.
  e. Never deletes. The archive is append-only from the consolidation's point of view.

**D4. `evelynn.md` becomes a thin view, not a bulk store. Chosen: consolidation writes a fresh roll-up (Option B).** Rejected alternative: glob-last-N-shards at each startup (Option A). Option B wins because: (1) SessionStart is hot path — globbing + concatenating 5–20 shards adds IO on every boot vs. one read of a pre-computed file; (2) roll-ups can be hand-edited (Evelynn may refine a section), which is impossible with glob-on-read; (3) the cost of consolidation is paid once per boot-after-24h, not every boot; (4) the `Key Context` / `Working patterns` / `Feedback` sections in `evelynn.md` today are curated, not mechanically appended — they need a file that can be edited, not regenerated. The roll-up layout keeps those curated sections intact and only the `## Sessions` tail is auto-extended from shards.

  `evelynn.md` is renamed conceptually: the top (curated sections: Identity, Role, Key Context, Infrastructure, Protocols, Billing, Open Threads, Feedback) stays hand-maintained. The `## Sessions` section becomes an auto-managed tail whose source of truth is the shard directory. Consolidation rewrites only the `## Sessions` block, preserving everything above it via a sentinel marker (`<!-- sessions:auto-below -->`).

**D5. SessionStart hook reads last N.** The current hook (`.claude/settings.json`) tells Evelynn to read `agents/evelynn/memory/last-session.md (if exists)`. Replace with `agents/evelynn/memory/last-sessions/` — read the 5 newest by mtime. The `evelynn.md` read is unchanged (already covers the roll-up).

**D6. `remember:remember` plugin — bypass for Evelynn (Option B).** Audit of `.remember/remember.md` shows it is a single-file plugin output (1 line in current state, but schema is single-file). Two options:
  - **Option A (shard the plugin):** fork the plugin to write `.remember/sessions/<uuid>.md`. High cost, plugin is third-party.
  - **Option B (bypass for Evelynn, use our shards):** `/end-session` skill Step 6 already has a fallback path — make that the **primary** path for Evelynn and skip `remember:remember` invocation entirely. Document in CLAUDE.md that Evelynn does not use the remember plugin because its single-file shape is unsafe under concurrent close. Other agents (Sonnet subagents) are one-shot and don't race, so they can keep using the plugin via `/end-subagent-session`.
  - **Chosen: Option B.** Rationale: the plugin is optional, Evelynn is the only concurrent-close risk, and our shard directory is already the right shape for her.

**D7. Fix `/end-session` frontmatter.** Flip `disable-model-invocation: false` → `true` on line 4 of `.claude/skills/end-session/SKILL.md`. This matches the Refusal-posture docstring and CLAUDE.md Rule 8. Already-closed sessions are unaffected; next `/end-session` invocation will respect the corrected gate.

## File changes

```
agents/evelynn/memory/
├── evelynn.md                              (EDIT — insert <!-- sessions:auto-below --> sentinel; curated sections above untouched)
├── last-session.md                         (MIGRATE + DELETE — move current content into last-sessions/<uuid>.md, then delete the file)
├── sessions/                               (NEW DIR)
│   ├── <short-uuid>.md                     (NEW — written by /end-session Step 7)
│   └── archive/                            (NEW DIR — consolidated shards land here, never deleted)
└── last-sessions/                          (NEW DIR)
    └── <short-uuid>.md                     (NEW — written by /end-session Step 6)

.claude/skills/end-session/SKILL.md         (EDIT — Step 6 writes last-sessions/<uuid>.md; Step 7 writes sessions/<uuid>.md; frontmatter fix D7)
.claude/settings.json                       (EDIT — SessionStart hook reads last-sessions/ last-5 instead of last-session.md)
agents/evelynn/CLAUDE.md                    (EDIT — document remember plugin bypass for Evelynn; update Startup Sequence step 3 reference)
CLAUDE.md (repo root)                       (EDIT — optional one-liner in Critical Rules reinforcing shard invariant, or skip)
scripts/evelynn-memory-consolidate.sh       (NEW — consolidation script invoked by SessionStart hook on fresh boot)
```

No file is deleted by automation. `last-session.md` is removed by hand in the migration task below.

## Task list

Numbered for a Sonnet executor. Each task is mechanical — no design required.

### T1. Create new directory scaffolding
1. `mkdir -p agents/evelynn/memory/sessions/archive`
2. `mkdir -p agents/evelynn/memory/last-sessions`
3. Add `.gitkeep` to each of the three new dirs (`sessions/`, `sessions/archive/`, `last-sessions/`) so empty dirs are trackable.
4. Stage: `git add agents/evelynn/memory/sessions/.gitkeep agents/evelynn/memory/sessions/archive/.gitkeep agents/evelynn/memory/last-sessions/.gitkeep`.

### T2. Migrate existing `last-session.md` into a shard
1. Read `agents/evelynn/memory/last-session.md`.
2. Generate a short UUID (`python -c "import uuid; print(uuid.uuid4().hex[:8])"`) — call it `MIGRATE_UUID`.
3. Copy content to `agents/evelynn/memory/last-sessions/<MIGRATE_UUID>.md` verbatim.
4. `git rm agents/evelynn/memory/last-session.md`.
5. Stage the new shard: `git add agents/evelynn/memory/last-sessions/<MIGRATE_UUID>.md`.

### T3. Insert sentinel into `evelynn.md`
1. Open `agents/evelynn/memory/evelynn.md`.
2. Locate the `## Sessions` heading.
3. Insert a new line immediately after the heading: `<!-- sessions:auto-below — managed by scripts/evelynn-memory-consolidate.sh. Do not hand-edit below this line. -->`
4. Save. Stage.

### T4. Write consolidation script
1. Create `scripts/evelynn-memory-consolidate.sh`. POSIX bash per Rule 10. Header: `#!/usr/bin/env bash` and `set -euo pipefail`.
2. Script responsibilities:
   - Find shards in `agents/evelynn/memory/sessions/*.md` with mtime older than 24 hours (use `find ... -mtime +0 -type f`, NOT `stat` — portability).
   - For each such shard, extract its `## Session <date>` block (entire file content) and append to a temp buffer, in mtime-ascending order (`find ... -printf` is GNU-only; use `ls -tr` or `find | xargs stat` portably — use `perl -e 'print((stat)[9]," ",$_)' <<<"$f"` or simpler: iterate `find -print0 | while read -d ''` then sort by `date -r`).
   - Read `agents/evelynn/memory/evelynn.md`, split at the `<!-- sessions:auto-below -->` sentinel.
   - Rewrite `evelynn.md` as: `<everything above sentinel + sentinel line>` + `\n` + `<sorted session entries>` + `\n` + `<everything below sentinel that was NOT an auto-generated session block — preserve manually curated footers if any>`. Simplest approach: replace everything strictly below the sentinel line with the regenerated session block.
   - For each consolidated shard, `git mv <shard> agents/evelynn/memory/sessions/archive/<same-uuid>.md`.
   - `git add -A agents/evelynn/memory/`
   - `git commit -m "chore: evelynn memory consolidation $(date -u +%Y-%m-%d)"`
   - `git push` (single retry on `main moved`, merge-not-rebase per Rule 11).
3. Exit codes: 0 on success, 0 (no-op) if no shards older than 24h, non-zero only on commit/push failure. Do NOT fail-loud on "nothing to do."
4. Make executable: `chmod +x scripts/evelynn-memory-consolidate.sh`.
5. Stage.

### T5. Edit `.claude/skills/end-session/SKILL.md`
1. **Fix frontmatter (D7).** Change line 4 from `disable-model-invocation: false` to `disable-model-invocation: true`.
2. **Step 6 rewrite.** Current Step 6 invokes the `remember:remember` skill and falls back to `last-session.md`. New Step 6 for Evelynn (agent==evelynn): skip the plugin entirely, write `agents/evelynn/memory/last-sessions/<short-uuid>.md` where `<short-uuid>` is the UUID already captured in Step 2 from the cleaner's output path. Content is the same structured 5–10 line handoff. Stage with `git add agents/evelynn/memory/last-sessions/<short-uuid>.md`.
3. **Step 7 rewrite.** Current Step 7 edits `agents/<agent>/memory/<agent>.md` in place. New Step 7 for Evelynn: write a NEW file `agents/evelynn/memory/sessions/<short-uuid>.md` (same UUID) containing the session row that would have been appended to `evelynn.md`'s `## Sessions` list, plus any delta notes to Key Context / Working Patterns. Do NOT touch `evelynn.md` — consolidation will fold this in later. For non-Evelynn agents, Step 7 is unchanged.
4. Both Step 6 and Step 7 branches must wrap with `if [ "<agent>" = "evelynn" ]; then ...shard path... else ...legacy path... fi`. Legacy path is preserved for other agents.
5. Stage.

### T6. Edit SessionStart hook in `.claude/settings.json`
1. In the fresh-session branch of the hook (the else branch in the current jq one-liner), change the `additionalContext` string:
   - Remove: `agents/evelynn/memory/last-session.md (if exists)`.
   - Insert: `agents/evelynn/memory/last-sessions/ (read the 5 newest by mtime)`.
2. Add a new instruction at the **start** of the fresh-session additionalContext (BEFORE "Read in order"): `First run: bash scripts/evelynn-memory-consolidate.sh (fold session shards older than 24h into evelynn.md; commit+push).`
3. Validate JSON: `python -c "import json,sys; json.load(open('.claude/settings.json'))"`.
4. Stage.

### T7. Edit `agents/evelynn/CLAUDE.md`
1. In the Startup Sequence section, change step 3 from `agents/evelynn/memory/last-session.md` to `agents/evelynn/memory/last-sessions/ (5 newest)`.
2. In the Coordinator-Specific Critical Rules section, add a new rule: **Remember plugin bypass** — "Evelynn does not invoke `remember:remember`. Handoffs go to `agents/evelynn/memory/last-sessions/<uuid>.md`. Rationale: the plugin's single-file shape races under concurrent close."
3. Stage.

### T8. Smoke test (dry-run; no PR required, this is infra)
1. Run `bash scripts/evelynn-memory-consolidate.sh` manually after T1–T7 are staged but before commit. With zero shards older than 24h, expected behavior: script exits 0, no files changed, no commit produced.
2. Fabricate a test shard: `cp agents/evelynn/memory/last-sessions/<MIGRATE_UUID>.md agents/evelynn/memory/sessions/testshard.md`, then `touch -d '2 days ago' agents/evelynn/memory/sessions/testshard.md`, then re-run script. Expected: shard archived, `evelynn.md` updated below sentinel, separate commit pushed.
3. If step 2 leaves the repo in a good state, delete the test artifacts in the next commit. If it breaks, revert and report to Duong.

### T9. Commit the migration
1. All T1–T7 changes in one commit (the migration commit):
   ```
   chore: evelynn memory sharding — per-session shards, consolidate-on-boot, SessionStart read-N
   ```
2. Push. Merge-not-rebase on collision per Rule 11.
3. Do NOT include test-shard artifacts from T8 in this commit.

### T10. Verify
1. Run `/end-session evelynn` at the next real Evelynn session close. Confirm a new shard lands at `agents/evelynn/memory/sessions/<uuid>.md` and a handoff at `agents/evelynn/memory/last-sessions/<uuid>.md`.
2. Confirm `evelynn.md` above-sentinel is untouched by the skill.
3. Start the next Evelynn session; confirm the SessionStart hook (a) invokes the consolidate script, (b) reads the last 5 from `last-sessions/`, (c) no errors in `.claude/logs/`.

## Non-goals

- Not redesigning `remember:remember` internals. Bypass only.
- Not touching `/end-subagent-session` — Sonnet subagents are one-shot, no race.
- Not migrating other agents' memory files. This plan is Evelynn-scoped. Vex (Windows head) races on her own files; a sibling plan can mirror this layout for her if needed.
- Not pruning `sessions/archive/`. Separate plan if archive grows unbounded.

## Risks

- **R1. Sentinel collision.** If `evelynn.md` ever ends up with two `<!-- sessions:auto-below -->` markers (accidental hand-edit), the consolidation script will lose content below the first one. Mitigation: script asserts exactly-one-sentinel and exits non-zero otherwise.
- **R2. Consolidation during concurrent boot.** Two fresh Evelynn sessions booting within milliseconds both run the consolidate script. Mitigation: script uses `flock agents/evelynn/memory/.consolidate.lock` (advisory) and second-to-start exits 0 as no-op.
- **R3. Frontmatter flip affects in-flight sessions.** D7's `disable-model-invocation: true` flip takes effect at next Claude Code restart. Already-open sessions keep the cached definition (per memory: "Subagent definition caching" — same applies to skills). Not a blocker; just a note.
- **R4. Short-UUID collision.** Cleaner uses 8-hex short UUID. Birthday collision ~one-in-65k. Mitigation: consolidation script checks `archive/<uuid>.md` existence before mv; if collision, appends `-2`.
