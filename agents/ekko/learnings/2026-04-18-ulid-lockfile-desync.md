# Lockfile Desync Pattern — ulid

**Date:** 2026-04-18
**Task:** Pre-migration prereq fix — sync ulid lockfile entry

## What happened

`npm ci` failed with `Missing: ulid@3.0.2 from lock file`. The error appeared
in the filtered migration clone but was pre-existing on main too.

## Root cause

`dashboards/server/package.json` declares `"ulid": "^3.0.2"` as a direct
dependency. `dashboards/*` is a workspace entry in the root `package.json`.
However, the root `package-lock.json` was missing the ulid entry entirely —
19 packages were absent (ulid and its transitive deps).

## Fix

`npm install --ignore-scripts` from the root synced the lockfile. Only
`package-lock.json` changed (18 insertions, 64 deletions due to lockfile
format normalization). No `package.json` changes needed.

## Verification

`npm ci --ignore-scripts` completed with no desync error. Only pre-existing
engine warnings (node v25 vs required v20/22/24) remain — those are not
blocking.

## Commit

SHA: `dbc1be1` — pushed to main.
