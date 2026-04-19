# 2026-04-19 — tdd-gate push-event range fix

## What

Fixed `tdd-gate.yml` to use `git merge-base HEAD origin/main` instead of
`github.event.before` for the push-event BASE calculation.

## Why it matters

`github.event.before` is only the SHA before the most recent push force-push
delta. Earlier commits on the same branch (e.g. an xfail commit pushed in a
prior push event) fall outside the scan range, producing a false Rule 1
violation and blocking the branch.

## Pattern

Always use merge-base for full-branch coverage on push events. Precede with
`git fetch origin main --depth=0` so the ref is resolvable.

## PR

harukainguyen1411/strawberry-app#55
