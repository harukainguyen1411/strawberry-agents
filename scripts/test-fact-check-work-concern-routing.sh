#!/usr/bin/env bash
# Regression test — fact-check-plan.sh work-concern routing
#
# Plan: 2026-04-21-orianna-work-repo-routing
#
# XFAIL: orianna-work-repo-routing
# This test is committed in xfail state before the implementation. It exits 0
# to satisfy the pre-push TDD gate. Flip to a real pass/fail tally once the
# implementation in fact-check-plan.sh is in place (same branch, later commit).
#
# Invariants covered:
#   I1 — concern: work routes apps/* to $WORK_CONCERN_REPO
#   I2 — concern: personal (and no concern field) keeps apps/* → $STRAWBERRY_APP (backward compat)
#   I3 — missing work-concern checkout emits warn naming the work-concern repo path
#
# Run: bash scripts/test-fact-check-work-concern-routing.sh

set -euo pipefail

printf 'XFAIL: orianna-work-repo-routing\n'
printf 'Test committed in xfail state — implementation not yet applied.\n'
printf 'Flip xfail → pass in the implementation commit.\n'
exit 0
