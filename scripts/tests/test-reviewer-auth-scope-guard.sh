#!/usr/bin/env bash
# test-reviewer-auth-scope-guard.sh
# xfail: reviewer-auth.sh work-scope refusal guard not yet implemented.
# Rule 12 — xfail test committed before T4 implementation.
# Plan: plans/in-progress/personal/2026-04-24-reviewer-auth-concern-split.md T4
#
# Tests:
#   (a) ANONYMITY_MOCK_REPO_URL=missmp/company-os → exits non-zero with message
#       citing post-reviewer-comment.sh (work-scope refusal guard)
#   (b) ANONYMITY_MOCK_REPO_URL=Duongntd/strawberry-app → exits 0 (personal scope
#       passes through, exercised with ANONYMITY_DRY_RUN=1)

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/reviewer-auth.sh"

PASS=0
FAIL=0

_pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
_fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== reviewer-auth scope-guard tests ==="

# -----------------------------------------------------------------------
# Case (a): work-scope MOCK → must exit non-zero + cite post-reviewer-comment.sh
# -----------------------------------------------------------------------
work_output="$(
  ANONYMITY_MOCK_REPO_URL="missmp/company-os" \
  ANONYMITY_DRY_RUN=1 \
    "$SCRIPT" gh pr review 1 --approve --body "-- reviewer" 2>&1
)" || work_exit=$?
work_exit="${work_exit:-0}"

if [[ "$work_exit" -eq 0 ]]; then
  _fail "(a) work-scope: expected non-zero exit, got 0"
else
  _pass "(a) work-scope: exited non-zero ($work_exit)"
fi

if printf '%s' "$work_output" | grep -q 'post-reviewer-comment.sh'; then
  _pass "(a) work-scope: output references post-reviewer-comment.sh"
else
  _fail "(a) work-scope: output did not reference post-reviewer-comment.sh"
  printf '    output was: %s\n' "$work_output"
fi

# Guard runs before decryption — env file must NOT be touched for refused calls.
# (reviewer-auth.env would only appear if decrypt.sh was invoked)
if [[ -f "$REPO_ROOT/secrets/reviewer-auth.env" ]]; then
  _ts_before="$(stat -f '%m' "$REPO_ROOT/secrets/reviewer-auth.env" 2>/dev/null || stat -c '%Y' "$REPO_ROOT/secrets/reviewer-auth.env" 2>/dev/null)"
else
  _ts_before="absent"
fi
# Re-run to verify timestamp does not change
ANONYMITY_MOCK_REPO_URL="missmp/company-os" ANONYMITY_DRY_RUN=1 \
  "$SCRIPT" gh pr review 1 --approve --body "-- reviewer" >/dev/null 2>&1 || true
if [[ -f "$REPO_ROOT/secrets/reviewer-auth.env" ]]; then
  _ts_after="$(stat -f '%m' "$REPO_ROOT/secrets/reviewer-auth.env" 2>/dev/null || stat -c '%Y' "$REPO_ROOT/secrets/reviewer-auth.env" 2>/dev/null)"
  if [[ "$_ts_before" == "$_ts_after" ]]; then
    _pass "(a) work-scope: reviewer-auth.env not touched (guard ran before decrypt)"
  else
    _fail "(a) work-scope: reviewer-auth.env was modified — guard did not run before decrypt"
  fi
else
  _pass "(a) work-scope: reviewer-auth.env absent (guard ran before decrypt)"
fi

# -----------------------------------------------------------------------
# Case (b): personal-scope MOCK → must exit 0 (passes through dry-run)
# -----------------------------------------------------------------------
personal_exit=0
ANONYMITY_MOCK_REPO_URL="Duongntd/strawberry-app" \
ANONYMITY_DRY_RUN=1 \
  "$SCRIPT" gh pr review 1 --approve --body "-- Lucian" >/dev/null 2>&1 || personal_exit=$?

if [[ "$personal_exit" -eq 0 ]]; then
  _pass "(b) personal-scope: exited 0 (no false-positive refusal)"
else
  _fail "(b) personal-scope: expected exit 0, got $personal_exit"
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
