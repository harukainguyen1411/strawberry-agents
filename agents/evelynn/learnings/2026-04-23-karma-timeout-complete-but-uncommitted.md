# Karma timeout: complete-but-uncommitted plan file

**Date:** 2026-04-23
**Context:** Dispatched Karma to write `plans/proposed/personal/2026-04-22-orianna-gate-simplification.md`. Karma returned `API Error: Stream idle timeout - partial response received` with `tool_uses: 28`. Expected next move: re-dispatch from scratch.

## The surprise

Checked `plans/proposed/personal/` — the plan file was on disk, 105 lines, well-formed, with frontmatter + Context + Risks + 7 tasks + Test plan + References. It just wasn't committed (file unstaged, no Karma commit on main).

Karma got all the work done; she died before the `git commit` step.

## The lesson

When an Opus planner times out, **check disk state before re-dispatching**. Specifically:
1. `ls plans/proposed/personal/ | grep <slug>` — did the file land?
2. If yes, `wc -l` and `head -40` — does it look complete?
3. If complete: have Yuumi commit it, skip the re-dispatch. Token savings: a full Karma re-run.

A timeout at `tool_uses: 28` is mid-to-late in a plan-drafting session. Don't assume nothing survived.

## Anti-pattern to avoid

Reflex re-dispatch on timeout. Re-running Karma would have produced a second plan file (probably similar but not identical), duplicated the work, and confused the commit history.

## Related

Also applies to Swain / Azir / Aphelios / Kayn / Xayah / Caitlyn — any planner that writes a final artifact as its last step. Executors (Viktor, Jayce, Talon, Ekko) are less susceptible because they produce multi-file diffs throughout and partial state is easier to detect.
