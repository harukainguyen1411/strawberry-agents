# 2026-04-19 — PR #45 V0.11 round-3 re-approve (tip 2c1c2fe)

## Context
Third review pass on harukainguyen1411/strawberry-app PR #45 (V0.11 CSV Import Step 1).
Round 2 had CHANGES_REQUESTED for 4 TS build errors. Seraphine fixed at 700bbc5 / 2b83acd,
Ekko merged main (#42 + #58) into the branch at 2c1c2fe with no conflicts.

## Verified as real fixes (not suppressions)

1. **`received: [timeStr]` in t212.ts:131** — matches `ImportError.received: string[]` in
   `functions/portfolio-tools/types.ts`. This was the V0.6 original shape; Ekko's b985c68
   had mis-reverted it to a bare string. Restoration, not suppression.

2. **Unused `beforeEach` import removal** — dead code, no behavioral change.

3. **3x `as unknown as {...}` casts on `wrapper.vm`** — idiomatic TS double-cast-through-
   unknown. ComponentPublicInstance doesn't structurally match the ad-hoc method shape,
   so direct cast fails. `as unknown as T` is strictly safer than `any` / `@ts-expect-error`
   because it preserves the target shape for downstream typechecking of the `.handleFile()`,
   `.onDrop()`, etc. calls. Not a suppression.

## Senna heuristic — "suppression vs fix" check

When reviewing TS-build-error fixes, always answer three questions:
- **Does the fix match the declared type?** (check the interface/type source of truth)
- **Does the runtime behavior still occur?** (grep the test for the actual expect() on
  real values, not just presence-of-key assertions)
- **Is the cast the narrowest possible?** (`as unknown as T` ≫ `as any` ≫ `@ts-expect-error`)

If all three pass, it's a real fix. Here all three passed.

## Outcome
APPROVED by strawberry-reviewers at 2026-04-19T12:48:30Z. All 15 required checks green.
mergeStateStatus: BLOCKED was from missing approval — now unblocks.
