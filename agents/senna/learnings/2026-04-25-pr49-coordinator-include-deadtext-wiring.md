# PR #49 — coordinator deliberation primitive: include marker added without inlined content (dead text at runtime)

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/49
**Verdict:** REQUEST CHANGES
**Files reviewed:** `.claude/agents/_shared/coordinator-intent-check.md` (new), `.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `scripts/tests/test-coordinator-intent-include.sh`

## Top finding

The repo's `<!-- include: _shared/<role>.md -->` mechanism is **not runtime-evaluated** by Claude's agent framework. It is a marker for `scripts/sync-shared-rules.sh`, which **inlines** the canonical shared content directly beneath the marker into the agent .md file. The inlined bytes are what the runtime actually loads. The pre-commit hook `pre-commit-agent-shared-rules.sh` validates inline-vs-canonical drift.

PR #49 added the marker to `evelynn.md` and `sona.md` but did NOT inline the body content. So:
- The runtime sees an inert HTML comment + no payload → deliberation primitive never reaches model context.
- The structural test passes because it only greps for the marker line, not for inlined content.
- The drift hook does NOT catch the missing payload because it explicitly skips coordinators (line 181: `[ -n "$concern" ] && continue`).

Net result: the PR ships a no-op that *looks* shipped. The plan author (Karma) and Talon both treated the include mechanism as runtime-resolved when in fact it is a build-time inline.

## Pattern to remember (for future shared-include reviews)

When reviewing any PR that adds a `<!-- include: _shared/X.md -->` marker, ALWAYS check:

1. Does the agent file have the canonical content **inlined** beneath the marker (compare to a known-wired sibling like jayce.md or karma.md)?
2. Was `scripts/sync-shared-rules.sh` run as part of the change?
3. Does the drift hook (`pre-commit-agent-shared-rules.sh`) actually fire for this file? Coordinators have `concern:` frontmatter and are explicitly skipped.
4. Does the structural test validate inlined-content presence, or only marker presence? If only the latter, it's a no-op-passing test.

## Secondary findings

- **Closed-enumeration trap text** — listing exact cross-process-semantics categories (env vars, hooks, identity, secrets, agent-def routing) lets a future coordinator rationalize past a novel category by saying "this isn't on the list."
- **Trap names failure but not action** — "diff feels too small to need a gate = signal you're about to bypass one" describes the smell but doesn't say "route through chain anyway." Recognizing without prescribing leaves the rationalization door open.
- **Restating duong.md in compressed form** — listing "PM-altitude / 3-7 bullets / outcome-risk-decision" copies three normative claims from duong.md briefing-verbosity rule without a validator to catch drift if duong.md changes.
- **Test redundant guard** — `if [ "$PASS" -eq 0 ] || [ -f "$INCLUDE_FILE" ]` is dead logic: the inner block re-checks the file exists, so the outer guard has no effect.

## Reviewer-auth note

Used `scripts/reviewer-auth.sh --lane senna` for personal-concern PR. Preflight identity check returned `strawberry-reviewers-2` correctly. No issues.

## Fidelity gap with Lucian

Lucian approved on plan fidelity. Plan §1 explicitly described "the existing `<!-- include: _shared/<file>.md -->` mechanism" — and the PR did exactly what the plan said syntactically. So plan-vs-PR fidelity is intact. The defect is upstream: the PLAN itself made the same wiring assumption. This is the kind of bug only a code-quality lane catches — fidelity review can't catch it because the PR matches the plan's words exactly. Worth noting that for future plan reviews, when a plan invokes "existing mechanism X", a fidelity reviewer should verify the mechanism actually does what the plan claims it does.
