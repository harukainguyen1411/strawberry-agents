---
date: 2026-04-26
agent: senna
pr: 84
verdict: APPROVE
topic: T7a xfail tests for depth-2 nested-include resolution
---

# PR #84 — T7a xfail-first scaffold

## Outcome

APPROVE. Posted as `strawberry-reviewers-2` via `scripts/reviewer-auth.sh --lane senna`.

## What was reviewed

5 new `@test` blocks added to `scripts/__tests__/sync-shared-rules.xfail.bats`:
- T7a-a / a2: depth-2 idempotency + no-bare-marker post-sync
- T7a-b: feedback-trigger edit propagation through 3 role/agent pairs
- T7a-c: depth-3 chain emits error referencing OQ2/depth/nested/limit
- T7a-d: duplicate marker trips lint (already green — pre-existing)
- T7a-d2: single marker passes lint

## Verification steps

1. Ran `bats scripts/__tests__/sync-shared-rules.xfail.bats` locally — confirmed 10-13 + 15 RED, 14 GREEN. Matches PR description exactly.
2. Grep'd for forbidden bats helpers (`refute_match`, `\b`, bats `fail` helper). Only hit was a local int variable `fail=0` in T7a-b — not the helper.
3. Verified portability: `md5sum || md5 -q` covers Linux + macOS. `printf -- '---\n...'` correctly avoids `--` flag-parse bug for frontmatter delimiter.

## Reusable insight

**The "no bare marker post-sync" invariant is what makes depth-2 tests load-bearing.** A naive single-pass implementation that inlines the role file would still pass content-presence checks (because the role file's text is now in the agent def) — but the unresolved nested marker would leak through verbatim. Asserting `! grep -q '<!-- include: _shared/feedback-trigger.md -->'` on the agent def post-sync forces a real two-pass resolution. Pattern worth reusing for any nested-template system.

## Process note

`bash -n` fails on `.bats` files because `@test` is bats syntax — for bats files, run `bats <file>` to validate; do not run `bash -n`. Test #2 in the file (`passes bash -n syntax check`) only checks the target script (`$SYNC_SCRIPT`), not the bats file itself.
