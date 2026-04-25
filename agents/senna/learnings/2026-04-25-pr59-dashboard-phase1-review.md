# PR 59 — Dashboard Phase 1 review (cornerstone)

Date: 2026-04-25
Verdict: CHANGES_REQUESTED
PR: https://github.com/harukainguyen1411/strawberry-agents/pull/59

## Top finding — git-log multi-paragraph body parsing (BLOCKER)

Real `git log --format="%H%x00%s%x00%b%x00%aI"` output separates commits with single `\n`, but commit bodies routinely contain `\n\n` (paragraph breaks). The impl in `lib/sources.mjs:325` splits on `'\n\n'` to delimit commits — every multi-paragraph body becomes a false block boundary, dropping `Promoted-By: Orianna` trailers in production. Mock path bypasses the bug entirely so all 53 tests pass.

Lesson: **when a code path is unreachable in tests because tests use a mock, the real path needs its own dedicated unit test.** Here, no test feeds a synthetic real-git-log-shaped string into `parseRealGitLog`. I caught it only by manually invoking `git log` against the live repo and noticing paragraph breaks. Whenever I see `RETRO_*_MOCK` or similar test-only injection, audit whether the production fallback has any independent coverage.

## Mock-bypass blindspots (general pattern)

The fixture/test harness for this PR is rigorous about using `RETRO_GIT_LOG_MOCK` everywhere, which is great for determinism. But the consequence is that `loadGitLogPlanData` has TWO branches and tests only exercise the mock branch. `parseRealGitLog` is reachable only via the real-git-log fallback path. Always trace which branches are coverage-isolated by mocks; review them with extra suspicion.

## Architectural-invariant partial-implementations

Two cases where the impl met the test-as-written but not the architectural spec:

1. **OQ-R3 rank-tie**: impl handles same-commit trailer+frontmatter conflict, fixture/realistic case is two separate commits 30s apart. The xfail test never gets un-skipped, so the gap is invisible until someone tries to flip the xfail.
2. **Turn-level `stage` attribution**: impl uses dispatch-prompt-slug match for every turn's stage. The trailer-canonical priority (invariant 5) is realized only at the plan-stage-event level, never used to override per-turn stage. The plan-rollup SQL groups by `e.stage` from turn records — silently bypasses canonical signal.

Lesson: when an impl claims to honor an architectural invariant via a hierarchy/priority, **trace the data through the rollup**, not just the input pipeline. Did the higher-priority signal actually win at the consumer? Here it's emitted but unused.

## Fixture-vs-test-comment drift

The `idle-gap-session.jsonl` fixture has T2→T3 = 135s and T4→T5 = 105s, but the test header and assertion messages reference 125s and 91s. The strip behavior is identical (both >90), so the test passes. But future debuggers reading the comments will be confused. **Even passing tests benefit from comment audits.**

## Path-traversal via plan slug

`html-generator.mjs:186` interpolates `slug` into output filename. Slug is regex-extracted (`[^/\s'"]+`), so `..` is not excluded. Low realistic surface, but defensive sanitization is cheap and removes the class entirely. Pattern: any user-derived value flowing into a filesystem path needs explicit `..` and `/` rejection, not just regex character-class restrictions.

## Determinism-guard scope

The R2 source-scan checks `render.mjs` for non-deterministic calls but doesn't check `lib/sources.mjs` (used by ingest, contains a `new Date().toISOString()` fallback). Determinism contracts must apply to all code that produces persisted output, not just the script the test happens to scan.

## Workflow notes

- Branch checked out at `/private/tmp/strawberry-dashboard-phase-1` via existing worktree.
- `node --test` ran all 44 tests successfully; bats e2e ran all 9 tests successfully.
- Used `gh pr view` and `git log` for context; `gh pr review --request-changes --body-file` to submit.
- Review submitted under `strawberry-reviewers-2` (Senna lane) — verified via `gh api user --jq .login` preflight.
