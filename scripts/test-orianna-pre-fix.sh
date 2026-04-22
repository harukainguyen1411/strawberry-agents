#!/bin/sh
# xfail: T8 of plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md
#
# Test: orianna-pre-fix script — four fixture cases
# Plan task: T8 (kind: test) — precedes T9 (implementation) per Rule 12.
#
# Cases:
#   CASE_1_WORKSPACE_REWRITE    — bare legacy workspace-prefixed token in a work-concern
#                                 plan is rewritten to the requalified form
#   CASE_2_URL_SUPPRESSOR       — backticked prose-host URL token gains a
#                                 <!-- orianna: ok -- ... --> suppressor on the same line
#   CASE_3_QMARK_WARN_NO_CHANGE — question-mark marker inside §10 or §11 produces a
#                                 stderr warning with exit 0 and zero file change
#   CASE_4_IDEMPOTENT           — a plan with none of the patterns is unchanged by pre-fix;
#                                 personal-concern fixture must NOT receive the workspace rewrite
#
# xfail guard: all four cases report xfail and exit 0 when orianna-pre-fix.sh
# does not yet exist (T9 not implemented).
#
# Run: bash scripts/test-orianna-pre-fix.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRE_FIX="$SCRIPT_DIR/orianna-pre-fix.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
if [ ! -f "$PRE_FIX" ]; then
  printf 'XFAIL  orianna-pre-fix.sh not present — all 4 cases xfail (T9 not yet implemented)\n'
  printf 'XFAIL  CASE_1_WORKSPACE_REWRITE\n'
  printf 'XFAIL  CASE_2_URL_SUPPRESSOR\n'
  printf 'XFAIL  CASE_3_QMARK_WARN_NO_CHANGE\n'
  printf 'XFAIL  CASE_4_IDEMPOTENT\n'
  printf '\nResults: 0 passed, 4 xfail (expected — implementation not present)\n'
  exit 0
fi

# Helper: create a temp plan file with given content; return path on stdout
make_plan() {
  f="$(mktemp /tmp/pre-fix-test-XXXXXX.md)"
  printf '%s' "$1" > "$f"
  printf '%s' "$f"
}

# --- CASE 1: Work-concern plan with bare legacy workspace-prefixed token ---
# The plan references a path without the full workspace prefix.
# After pre-fix the path should be requalified to the workspace-prefixed form.
WORK_PLAN_CONTENT='---
title: work-plan-legacy-ref
status: proposed
concern: work
---

# Section

See the file at `tools/demo-studio-v3/config.yaml` for configuration details.
'
PLAN="$(make_plan "$WORK_PLAN_CONTENT")"
output_before="$(cat "$PLAN")"
rc=0
stderr_out="$(mktemp)"
stdout_out="$(mktemp)"
bash "$PRE_FIX" "$PLAN" --concern work >"$stdout_out" 2>"$stderr_out" || rc=$?
output_after="$(cat "$PLAN")"
# The requalified form should include the workspace prefix (path to mmp workspace)
# Accept any workspace-style prefix that disambiguates the bare tools/ reference
if [ "$output_after" != "$output_before" ] && \
   printf '%s\n' "$output_after" | grep -q "tools/demo-studio-v3"; then
  # Confirm the rewrite added a prefix (the path is now longer / prefixed)
  if ! printf '%s\n' "$output_after" | grep -q "^See the file at \`tools/demo-studio-v3"; then
    pass "CASE_1_WORKSPACE_REWRITE"
  else
    fail "CASE_1_WORKSPACE_REWRITE" "expected bare token to be requalified; content still shows bare path"
  fi
else
  fail "CASE_1_WORKSPACE_REWRITE" "pre-fix did not rewrite bare workspace token in work-concern plan"
fi
rm -f "$PLAN" "$stdout_out" "$stderr_out"

# --- CASE 2: Plan line with backticked prose-host URL — suppressor inserted ---
# The claude.ai / claude.com docs host is in the T9 allowlist.
URL_PLAN_CONTENT='---
title: url-token-plan
status: proposed
concern: personal
---

# References

See the docs at `https://docs.anthropic.com/claude/reference` for details.
'
PLAN="$(make_plan "$URL_PLAN_CONTENT")"
rc=0
stdout_out="$(mktemp)"
bash "$PRE_FIX" "$PLAN" >"$stdout_out" 2>/dev/null || rc=$?
output_after="$(cat "$PLAN")"
# Line should now carry <!-- orianna: ok -- ... --> suppressor
if printf '%s\n' "$output_after" | grep -q "orianna: ok"; then
  pass "CASE_2_URL_SUPPRESSOR"
else
  fail "CASE_2_URL_SUPPRESSOR" "expected orianna: ok suppressor on backticked URL line; not found in output"
fi
rm -f "$PLAN" "$stdout_out"

# --- CASE 3: Question-mark marker in §10 or §11 → stderr warning, exit 0, zero file change ---
QMARK_PLAN_CONTENT='---
title: qmark-plan
status: proposed
concern: personal
---

# Body

Some content here.

## 10. Open questions

1. Does this approach work? — ?

## 11. References

- Some reference?
'
PLAN="$(make_plan "$QMARK_PLAN_CONTENT")"
content_before="$(cat "$PLAN")"
rc=0
stderr_out="$(mktemp)"
stdout_out="$(mktemp)"
bash "$PRE_FIX" "$PLAN" >"$stdout_out" 2>"$stderr_out" || rc=$?
content_after="$(cat "$PLAN")"
# Must exit 0 and emit a stderr warning
if [ "$rc" -eq 0 ] && grep -qi "question\|marker\|\?\|warning\|section 1[01]" "$stderr_out" && \
   [ "$content_before" = "$content_after" ]; then
  pass "CASE_3_QMARK_WARN_NO_CHANGE"
else
  if [ "$rc" -ne 0 ]; then
    fail "CASE_3_QMARK_WARN_NO_CHANGE" "expected exit 0 for qmark detection; got exit $rc"
  elif [ "$content_before" != "$content_after" ]; then
    fail "CASE_3_QMARK_WARN_NO_CHANGE" "expected zero file change for qmark detection; file was mutated"
  else
    fail "CASE_3_QMARK_WARN_NO_CHANGE" "expected stderr warning for qmark markers in §10/§11; none found"
  fi
fi
rm -f "$PLAN" "$stdout_out" "$stderr_out"

# --- CASE 4: Idempotent — no patterns → file unchanged; personal plan no workspace rewrite ---
CLEAN_PLAN_CONTENT='---
title: clean-plan
status: proposed
concern: personal
---

# Body

A clean plan with no legacy tokens, no URL tokens, no question-mark markers.

## 10. Open questions

None.

## 11. References

None.
'
PLAN="$(make_plan "$CLEAN_PLAN_CONTENT")"
content_before="$(cat "$PLAN")"
rc=0
stdout_out="$(mktemp)"
bash "$PRE_FIX" "$PLAN" --concern personal >"$stdout_out" 2>/dev/null || rc=$?
content_after="$(cat "$PLAN")"
if [ "$rc" -eq 0 ] && [ "$content_before" = "$content_after" ]; then
  # Run a second time to verify true idempotence
  bash "$PRE_FIX" "$PLAN" --concern personal >"$stdout_out" 2>/dev/null || true
  content_second="$(cat "$PLAN")"
  if [ "$content_after" = "$content_second" ]; then
    pass "CASE_4_IDEMPOTENT"
  else
    fail "CASE_4_IDEMPOTENT" "pre-fix is not idempotent — second run mutated the file"
  fi
else
  if [ "$rc" -ne 0 ]; then
    fail "CASE_4_IDEMPOTENT" "expected exit 0 for clean personal-concern plan; got exit $rc"
  else
    fail "CASE_4_IDEMPOTENT" "clean personal-concern plan was mutated (should be no-op)"
  fi
fi
rm -f "$PLAN" "$stdout_out"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
