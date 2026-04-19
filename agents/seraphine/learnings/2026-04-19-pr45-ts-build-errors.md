# 2026-04-19 — PR #45 TS Build Error Fixes

## Context
Branch: `feature/portfolio-v0-V0.11-csv-import-step1`, tip c8da426 before session.
PR #45 CI blocked by 4 TS errors.

## Errors and Fixes

### 1. `t212.ts` — `received: string` should be `received: string[]`
- `ImportError.received` is typed `string[]` in `functions/portfolio-tools/types.ts`.
- Ekko reverted `received: [timeStr]` → `received: timeStr` at b985c68, believing it was V0.6 residue.
- git log confirmed `[timeStr]` was intentional type-conformance on this branch.
- Fix: restore `received: [timeStr]` array wrap.

### 2. Unused `beforeEach` import in `CsvImportRegression.test.ts`
- Simple removal of `beforeEach` from the vitest import.

### 3. `wrapper.vm as { ... }` — Vue Test Utils pattern
- `wrapper.vm` is typed as `ComponentPublicInstance` which doesn't support direct casting to arbitrary shapes.
- Pattern: `wrapper.vm as unknown as { method: () => void }` — requires `unknown` intermediary.
- Applied at lines 117, 154, 216, 220 in `CsvImportRegression.test.ts`.
- Note: line 117 was not in the reported errors but had the same pattern — fixed proactively.

## Pre-Push Hook Behaviour
- `apps/myapps/portfolio-tracker/functions/package.json` has `"tdd": { "enabled": true }`.
- The pre-push TDD hook checks the push range `remote_sha..local_sha` for xfail test commits.
- When the xfail tests were already pushed in a prior commit (d67e82a), the new fix commit alone doesn't have xfail in range → Rule 1 violation.
- Resolution: create an empty `chore:` commit with `TDD-Waiver:` trailer on tip, following precedent from f71ff76.
- The hook reads `git log -1 --format="%B" tip_sha` and checks for `*"TDD-Waiver:"*`.

## Build Verification
- `vue-tsc --noEmit` + `vite build` both green from worktree directory.
- `vitest run` — all CsvImportRegression tests pass; one pre-existing failure in `emulator-boot.test.ts` (firestore.indexes.json has composite indexes, pre-dates this session).
- Confirmed pre-existing by stash + re-run.

## Files Modified
- `apps/myapps/portfolio-tracker/functions/portfolio-tools/csv/t212.ts` (line 131)
- `apps/myapps/portfolio-tracker/src/components/__tests__/CsvImportRegression.test.ts` (lines 24, 117, 154, 216, 220)
