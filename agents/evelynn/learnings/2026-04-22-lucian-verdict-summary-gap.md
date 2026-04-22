# Lucian verdict-summary gap

**Date:** 2026-04-22
**Session:** cea94956
**Agent:** Lucian

## Observation

Lucian twice completed GitHub review actions (posted review via `gh pr review`) but skipped writing a verdict synthesis paragraph as his final message to the calling coordinator. The parent session only sees the subagent's final text output — if Lucian exits without a verdict summary, the coordinator has no in-context confirmation of the review outcome beyond the GH event itself.

## Lesson

When delegating a PR review to Lucian, add an explicit instruction: "Write a one-paragraph verdict summary (LGTM / CHANGES_REQUESTED + key findings) as your final message." Without this instruction, Lucian may treat the GH review post as sufficient and exit cleanly — which it technically is from a plan-fidelity standpoint, but leaves the coordinator blind in-context.

This is the same shape as Lucian's reviewer-failure fallback (verdict to `/tmp/<reviewer>-pr-N-verdict.md`) — the pattern of explicit output instruction is load-bearing for coordinator visibility.

## Action

Add to every Lucian delegation prompt: explicit final-message verdict requirement.
