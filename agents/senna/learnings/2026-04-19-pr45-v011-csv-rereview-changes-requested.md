# PR #45 V0.11 CSV Import Step 1 — re-review (CHANGES_REQUESTED)

**Date:** 2026-04-19
**Repo:** harukainguyen1411/strawberry-app
**PR:** #45 — feat: V0.11 CSV Import Step 1
**Tip:** c8da4264ae43a6d3200678b6f45352e676abc584
**Verdict:** CHANGES_REQUESTED

## Prior review (by me) flagged

Critical parseResult double-instance bug, errorId Math.random, missing
FileReader.onerror, no paste 10 MB hard cap, silent multi-file drop, MIME comment,
and a non-blocking `@/../functions/...` path.

## What the fix commit (c8da426) got right

All five review items addressed with substance, not xfail flips:
- R1: single `useCsvParser()` destructure in CsvImport.vue L119; `parseResult.value = result.value` L172. Confirmed no second call in the file.
- R2: module-scoped counter in DropZone.vue L121/L142 — stable per instance.
- R3: explicit `files.length > 1` branch emits error (L201–207), `onDrop` exposed for jsdom tests.
- R4: `HARD_MAX_BYTES = 10 MB` in CsvPasteArea.vue; `onInput` does not propagate on overflow, emits `too-large`. CsvImport wires the handler.
- R5: `reader.onerror` clears fileText, sets dropError.

Seraphine's A.17.R1–R5 xfail suite (d67e82a) converted to passing tests in c8da426 — the tests are genuine (e.g. R1 uses a controlled `vi.mock` that populates `result.value` on `parse()`, then asserts `wrapper.vm.parseResult` equals it — would fail if the code re-instantiated useCsvParser).

## Why I still requested changes

CI `Lint + Test + Build (affected)` is failing on c8da426 with four TS errors:

1. `functions/portfolio-tools/csv/t212.ts:148` — `received: string` vs typed `string[]`. Commit b985c68 reverted the array wrap as "V0.11 residue" but ImportError's contract in V0.6 actually requires `string[]`. Real type regression introduced by this PR's merge-conflict resolution.
2. `CsvImportRegression.test.ts:24` — unused `beforeEach` import.
3. `CsvImportRegression.test.ts:154,216,220` — direct `wrapper.vm as { ... }` casts; TS requires `as unknown as ...` intermediary.

Rules 15/18 forbid merging red / admin-bypassing, so even though the logic is sound the PR cannot ship.

## Lessons

- **Verify CI state before approving re-reviews.** I almost re-approved on code logic alone; the red build was the actual blocker. The "code is fine, tests pass locally" narrative can hide a vue-tsc failure in CI because `test` and `build` are different scripts in this repo.
- **Watch for merge-conflict resolutions that revert upstream contract changes.** b985c68's commit message ("remove V0.6 residue") was misleading — the `[timeStr]` wrap was a legitimate V0.11-era fix aligning with V0.6's type, not residue. When someone declares a revert restores "origin/main" state, double-check that origin/main's types agree.
- **`@/../functions/...` is still technical debt.** Worth pushing harder on a path alias or workspace package before V0.12 lands more cross-imports. Called out as important (non-blocking).
- **Destructured composable + module-scoped counter is a clean pattern** — worth remembering for the "each `useX()` call makes a new instance" class of bugs. The fix is essentially "compose once at setup, assign refs, reuse."

## Review posted

`strawberry-reviewers` via `scripts/reviewer-auth.sh`. State: CHANGES_REQUESTED.
