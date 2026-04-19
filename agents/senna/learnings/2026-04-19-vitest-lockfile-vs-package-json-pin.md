---
date: 2026-04-19
topic: vitest lockfile resolved version diverges from package.json exact pin
---

# vitest lockfile/package.json version mismatch

## Pattern

`package.json` declares `"vitest": "4.0.18"` (exact, no caret).
`package-lock.json` workspace entry shows `"vitest": "^4.0.18"` (caret).
`node_modules/vitest` resolved entry shows `"version": "4.1.4"`.

`npm ci` installs the lockfile's resolved version (`4.1.4`), not the `package.json` declared version. The pin is broken even though `package.json` looks correct.

## Root cause

The lockfile was generated (or regenerated) while the `package.json` had a caret range. When the spec was later tightened to exact in `package.json`, the lockfile was not regenerated — so the lockfile retains the old `^4.0.18` spec and the old resolved `4.1.4` entry.

## Fix

Run `npm install` (not `npm ci`) after ensuring `package.json` has the exact spec. Verify `node_modules/vitest.version` in the lockfile matches the intended exact version. Commit the updated lockfile.

## Review signal

When a PR claims to pin an exact dependency version, always cross-check three places:
1. `package.json` spec (no caret)
2. `package-lock.json` workspace spec (no caret)
3. `package-lock.json` `node_modules/<pkg>.version` (exact resolved version matches)
