---
date: 2026-04-20
topic: orianna scripts concern-subdir fix
---

# Orianna scripts concern-subdir fix

## What happened

orianna-sign.sh rejected plans in plans/proposed/personal/ and plans/proposed/work/
with a hard "plan is not in plans/proposed/" error. The directory check used exact
equality; concern subdirs were not accepted.

plan-promote.sh already had the concern-subdir logic (added in a prior session at
commit 2a5cfc9). orianna-sign.sh did not.

## Fix applied

orianna-sign.sh lines 113-117: replaced `if [ "$PLAN_DIR" != "$EXPECTED_DIR" ]`
with a case-match that also accepts `${EXPECTED_DIR}/work` and `${EXPECTED_DIR}/personal`.

## Smoke test state

test-orianna-lifecycle-smoke.sh was 5/11 before and after — the PROMOTE_TO_APPROVED
and downstream failures are pre-existing (the smoke repo's gate-v2 verify step
blocks because the temp plan has a dummy hash that doesn't match body). The
path fix did not regress anything.

## Lesson

When stashing and popping mid-session, verify which files were actually changed
vs already-committed before adding to a commit. git stash pop may restore working
tree edits that duplicate prior committed changes.
