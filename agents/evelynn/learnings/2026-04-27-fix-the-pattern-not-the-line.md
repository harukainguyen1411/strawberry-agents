# Fix the pattern, not the line

**Date:** 2026-04-27
**Context:** PR #93 r2 → r3 cycle. Senna r1 reported B1 at `tools/retro/lib/sources.mjs:9`. Viktor r2 fixed line 9 (and 585) but missed the same `*/`-in-JSDoc-glob anti-pattern at `tools/retro/ingest.mjs:11/35/173`. Senna r2 caught it and corrected Viktor's wrong baseline-failure claim — C1/C2/I4 in regression-pr88-fixes were NEW regressions from the unfixed B1 propagating through `execSync('node tools/retro/ingest.mjs')`, not pre-existing failures.

## The pattern

When a reviewer reports a syntactic anti-pattern at a specific line, the fix is to **sweep all files for that anti-pattern**, not patch only the reported line. Examples of anti-patterns that recur across files:

- `*/` inside JSDoc block comments (today's case — path globs in JSDoc descriptions)
- `eval()` / `exec()` with unsanitized input
- `setTimeout(fn, 0)` for "next tick" (use queueMicrotask instead)
- Hard-coded paths to `~/.claude` that ignore `HOME` override

When briefing a fixer, the brief should say "sweep for this pattern across <directory>" not "fix line N."

## What I should have caught

Viktor's r2 brief said "Fix B1 at sources.mjs:9 (replace `*/` with `*\/` or rephrase the glob)." That's a single-site brief. Better would have been: "Fix B1 — sweep `tools/retro/**/*.mjs` for `*/` inside JSDoc blocks. Senna spotted one at sources.mjs:9; expect more. Verify by running `node -e "import('./<file>')"` on each module."

I had the second-instance smell available (the same anti-pattern shape often recurs because devs copy comment headers between files in the same module) but didn't surface it in the brief. That's one round-trip of waste — Senna r2, Viktor r3 — that could have been collapsed.

## Cross-cutting

- **Builder briefs should specify the search radius**, not just the symptom site.
- **When a fix-brief asks for a one-line edit and the reviewer is Opus-tier**, expect them to look for siblings of the same pattern. Pre-empt that.
- **Verification command in the brief**: include the exact one-liner the fixer should run to confirm the fix is complete (`node -e "import(...)"` was the right probe; I included it for r3 but not r2).

## Trigger phrase next session

When briefing a fixer for a syntactic-pattern bug: "Sweep for the pattern, not the line. Include a one-liner verification command in the brief."
