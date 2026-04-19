# PR #35 and #37 Re-reviews — S12

## PR #35 (refresh-server.mjs CORS fix)
- Blocker resolved: `isLocalOrigin()` applied to GET /health and POST /refresh.
- Regression test (Test 5) is non-vacuous: spawns real server, sends real request with non-local Origin, asserts 403 and empty body.
- Non-blocking suggestions (409, SIGTERM child kill) folded in correctly.

## PR #37 (sbu.sh cross-platform open)
- Blocker resolved: `open_url()` helper tries open → xdg-open → start, errors loudly on miss.
- POSIX sh (`#!/bin/sh`, `set -eu`, `command -v`) — rule 10 compliant.
- Branch integrity after force-push merge: coherent. Merge commit `0a5cd856` parents are `f4614dc4` (fix) and `f56040e2` (remote impl). No commits lost or duplicated.
- README "How it works" still says "open command (macOS)" — stale prose. Non-blocking but worth noting.

## Pattern logged
- When a force-push conflict is resolved via merge commit, verify: (1) both parents exist in history, (2) no duplicated xfail/impl commits, (3) content of merge matches expected "keep" side.
