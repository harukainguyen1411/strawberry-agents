# Learning — PR #111 review: real transcript shape exposes fixture-only fix

**Date:** 2026-04-27
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/111
**Verdict:** COMMENT (4 IMPORTANT, 1 NIT) — see review URL above

## What happened

PR #111 addressed two IMPORTANT findings from PR #110 — the whole-transcript walk
correctness bug (`task_done` masking) and the zero-real-path coverage gap. Tests
green, xfail-then-impl ordering correct.

I sampled real Claude Code transcripts at `~/.claude/projects/*.jsonl` rather than
trusting the synthesized fixtures. Two empirical findings invalidated the parser's
delineator choice:

1. `type:"user"` entries in real transcripts are dominantly tool-result loopbacks
   (226 of 336 in a 2000-line sample), not real user prompts. Tool-result entries
   appear after every assistant tool_use.
2. `hook_event_name='UserPromptSubmit'` does not appear in transcript JSONL at
   all (0 of 2000 lines). Hook events are runtime payloads, not transcript entries.

The parser walking backward stops at the first tool-result, scoping to
"last assistant message only" — works by accident for the synthesized fixture
shape but fails when any non-marker tool runs after the SendMessage(task_done).

The fixture committed as `teammate-idle-real-transcript.jsonl` is byte-identical
to the synthesized conformant fixture — `Captured-from:` header missing, real
production shape never represented in the test suite.

## Pattern to repeat

**For hook reviews that parse runtime artifacts (transcripts, event payloads,
JSONL files): always sample the actual production artifact before trusting a
fixture.** The plan's §Failure-modes section had named exactly this risk
("Transcript JSONL shape drift... fixture must mirror real production shape")
and the implementation triggered the named failure mode. Without the empirical
sample I would have approved on green tests + xfail discipline + plan
compliance.

**Specific technique:** `find ~/.claude/projects -name "*.jsonl" -size +500k`
finds long Claude Code transcripts; pipe through python with json.loads-per-line
to count entry types and infer shape. Took <2 minutes and surfaced the dead
delineator branch.

## Cross-lane observation

The fixture shape mismatch is technically a plan-fidelity issue too — the plan
called for a captured-shape fixture and the file delivered is a synthesized copy.
Flagged for Lucian via Cross-lane note in the review body.

## Files referenced

- `scripts/hooks/posttooluse-teammate-idle-marker.sh:78-83` (delineator branches)
- `tests/hooks/fixtures/teammate-idle-real-transcript.jsonl` (duplicate of conformant)
- `plans/approved/personal/2026-04-27-team-mode-t9-followups.md` §Failure modes
