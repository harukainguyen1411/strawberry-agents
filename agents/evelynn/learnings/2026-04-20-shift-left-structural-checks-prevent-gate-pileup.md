# Shift-left structural checks prevent sequential gate-failure loops

**Date:** 2026-04-20
**Source:** Lissandra plan hitting 3 sequential Orianna gate failures on missing frontmatter fields → Karma authored Plan-Structure Pre-Lint to close the loop

## Observation

Before the pre-commit plan-structure lint existed, a plan with missing YAML frontmatter fields would pass authoring, pass commit, and only fail when Orianna ran the fact-check gate. The failure surfaced late, required a human loop to fix and re-run, and happened repeatedly (3 times in the same plan authoring cycle) because the fix window was after the gate, not before.

## Lesson

When a gate repeatedly catches the same class of error that could be verified at the point of authoring (or commit), the fix is to shift the check left — add a lint at author-time or commit-time that catches it before it reaches the gate. The gate remains but stops accumulating noise.

## Generalization

Any time the same error class appears 2+ times at a late gate, ask: can this be caught earlier? If yes, build the earlier check. The cost of a false negative (missing lint) is another gate cycle; the cost of adding the lint is bounded and one-time.

| last_used: 2026-04-20 |
