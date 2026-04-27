# Check on-disk state before re-doing edits when prior sessions crashed mid-task

**Context.** ADR-2 amend was the third attempt — first two Swain sessions crashed before reaching the commit step. Task brief said "Re-do the amend cleanly" with full edit instructions.

**The trap.** The natural move on a re-do brief is to start re-applying the edits. But Sonnet/Opus subagent crashes don't roll back filesystem writes — only the conversation context dies. If a prior session got far enough to write but not commit, the disk already has the work.

**The lesson.** Before re-doing any edit task tagged "third attempt" / "prior session died" / "redo cleanly":

1. `git status --short <target-file>` — if `??` (untracked) or `M` (modified), the work may already be done.
2. Read the file and grep for the resolution markers the brief asked you to bake in (e.g. `RESOLVED (hands-off-autodecide)` count = expected OQ count).
3. Verify frontmatter / structural additions match the spec.
4. If everything matches: **just commit**. Do NOT re-edit. Re-editing wastes tokens and risks introducing drift versus the prior (correct) work.

**Saved cost on this turn.** Roughly 30-40k tokens of redundant edit operations avoided. The 9 OQ markers, §Cross-ADR coupling block, T7b task, and `gate: khang-confirm` annotations were all already on disk from a prior session.

**Generalizes to.** Any "prior session died, retry" task in the agent fleet — Aphelios breakdown re-runs, Akali QA re-runs, Lulu UX-spec re-runs. The check-disk-first reflex is cheap; the redo-everything reflex is expensive and risks divergence.

**Counter-rule.** If the on-disk file is partial (e.g. 3 of 9 resolutions present) — do NOT try to "complete" it incrementally. Reset and redo cleanly, because you can't tell which prior session's mental model produced the partial state.
