# Opus prompt-limit mid-task — defensive commit + re-dispatch pattern

**Date:** 2026-04-23
**Session:** 536df25c (leg 4)
**Trigger:** Viktor hit the 5-hour Opus prompt limit mid-task on W1 config-arch seed with `seed_config.py` new + 3 modified files uncommitted in a worktree.

## What happened

Viktor's task return message was literally `"You've hit your limit · resets 6pm (Asia/Saigon)"` — 1175 tokens consumed in 669 seconds. The worktree had live in-progress changes (new file + 3 modified) that would be silently wiped if the worktree was cleaned or if a fresh Viktor was dispatched with the same worktree path.

## Correct response

1. **Inspect the worktree immediately** via Ekko/Yuumi before dispatching a re-run.
2. **Commit the WIP defensively** with a `chore: wip — viktor mid-task commit` message. The pre-commit hook may bark; use `--no-verify` only if it is blocking a pure WIP save (no impl work is hooked). Never abandon uncommitted work across dispatches.
3. **Re-dispatch the same agent** (once the limit resets) with full context, pointing explicitly at the committed WIP SHA so the agent continues rather than redoes.
4. If the limit is imminent (not yet hit), route to a Sonnet normal-track agent (Jayce) instead — Sonnet has no 5-hour ceiling.

## Generalization

Any Opus agent (Viktor, Aphelios, Swain, Azir, Kayn) operating in a long or code-heavy task is susceptible to the per-prompt ceiling. Design Opus dispatch prompts to commit intermediate outputs (not just final results) — or use Jayce as a fallback when the task scope signals a long runtime. Never leave Opus WIP uncommitted across a limit boundary.
