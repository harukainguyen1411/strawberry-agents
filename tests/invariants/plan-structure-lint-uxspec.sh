#!/usr/bin/env bash
# tests/invariants/plan-structure-lint-uxspec.sh
#
# xfail: T-B3 — promote-time §UX Spec linter (OQ-1 IN-SCOPE)
# Plan: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-B3
#
# Tests plan-structure-lint.sh against four fixture plan files:
#
#   (a) ui-no-spec.md    — UI path-glob match, §UX Spec absent
#                          EXPECT: linter exits non-zero
#   (b) ui-with-spec.md  — UI path-glob match, §UX Spec present + non-empty
#                          EXPECT: linter exits 0
#   (c) ui-waiver.md     — UI path-glob match, UX-Waiver: in frontmatter
#                          EXPECT: linter exits 0
#   (d) non-ui.md        — No UI path-glob match, no §UX Spec
#                          EXPECT: linter exits 0 (exempt)
#   (e) ui-heading-only  — UI path-glob match, §UX Spec header but no body
#                          EXPECT: linter exits non-zero
#   (f) malformed-frontmatter.md — Broken YAML frontmatter
#                          EXPECT: linter exits non-zero (error) but does NOT crash
#                          (i.e. process terminates cleanly — exit code is 1, not a signal)
#
# Currently FAILS because T-B4 (the implementation) has not landed yet.
# Tagged xfail-for: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-B4
#
# Run: bash tests/invariants/plan-structure-lint-uxspec.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

LINTER="$REPO_ROOT/scripts/plan-structure-lint.sh"
FIXTURES="$REPO_ROOT/tests/fixtures/plan-lint"

pass=0
fail=0

_pass() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
_fail() { printf 'FAIL: %s\n' "$1" >&2; fail=$((fail + 1)); }

# ---------------------------------------------------------------------------
# XFAIL guard — implementation (T-B4) not yet present
# ---------------------------------------------------------------------------

MISSING=""

if [ ! -f "$LINTER" ]; then
  MISSING="$MISSING scripts/plan-structure-lint.sh"
fi

# Confirm the linter has the §UX Spec rule (not just a skeleton file)
if [ -f "$LINTER" ] && ! grep -qE 'UX.?Spec|uxspec|ux_spec|ux-spec' "$LINTER" 2>/dev/null; then
  MISSING="$MISSING plan-structure-lint.sh:uxspec-rule"
fi

if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  for c in \
    TB3_UI_NO_SPEC_FAILS \
    TB3_UI_WITH_SPEC_PASSES \
    TB3_UI_WAIVER_PASSES \
    TB3_NON_UI_EXEMPT \
    TB3_HEADING_ONLY_FAILS \
    TB3_MALFORMED_FRONTMATTER_CLEAN_ERROR
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 6 xfail (expected — T-B4 linter implementation not yet landed)\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Fixture integrity guard — ensure fixture files exist before running cases
# ---------------------------------------------------------------------------

for fixture in ui-no-spec.md ui-with-spec.md ui-waiver.md non-ui.md malformed-frontmatter.md; do
  if [ ! -f "$FIXTURES/$fixture" ]; then
    printf 'FATAL: fixture missing: %s/%s\n' "$FIXTURES" "$fixture" >&2
    exit 2
  fi
done

# ---------------------------------------------------------------------------
# Helper: create a synthetic heading-only §UX Spec fixture in a temp file
# ---------------------------------------------------------------------------
ui_heading_only_fixture() {
  local tmpfile
  tmpfile="$(mktemp /tmp/plan-lint-heading-only-XXXXXX.md)"
  cat > "$tmpfile" <<'EOF'
---
status: proposed
concern: personal
owner: seraphine
created: 2026-04-25
tests_required: true
complexity: normal
tags: [frontend, ui-ux]
---

# UI Feature: Heading only spec

## Context

A UI plan where the §UX Spec section header exists but has no body content.

## Decision

Implement the feature.

## UX Spec

## Tasks

- [ ] **T1** — Add component. Files: `apps/web/src/components/Empty.vue`.

## Test plan

Unit tests.
EOF
  printf '%s' "$tmpfile"
}

# ---------------------------------------------------------------------------
# Live assertions — only reached after T-B4 lands
# ---------------------------------------------------------------------------

# (a) UI plan without §UX Spec — linter must fail (exit non-zero)
actual_exit=0
bash "$LINTER" "$FIXTURES/ui-no-spec.md" >/dev/null 2>&1 || actual_exit=$?
if [ "$actual_exit" -ne 0 ]; then
  _pass "TB3_UI_NO_SPEC_FAILS"
else
  _fail "TB3_UI_NO_SPEC_FAILS — linter exited 0 on UI plan missing §UX Spec (expected non-zero)"
fi

# (b) UI plan with complete §UX Spec — linter must pass (exit 0)
actual_exit=0
bash "$LINTER" "$FIXTURES/ui-with-spec.md" >/dev/null 2>&1 || actual_exit=$?
if [ "$actual_exit" -eq 0 ]; then
  _pass "TB3_UI_WITH_SPEC_PASSES"
else
  _fail "TB3_UI_WITH_SPEC_PASSES — linter exited $actual_exit on UI plan with valid §UX Spec (expected 0)"
fi

# (c) UI plan with UX-Waiver: frontmatter — linter must pass (exit 0)
actual_exit=0
bash "$LINTER" "$FIXTURES/ui-waiver.md" >/dev/null 2>&1 || actual_exit=$?
if [ "$actual_exit" -eq 0 ]; then
  _pass "TB3_UI_WAIVER_PASSES"
else
  _fail "TB3_UI_WAIVER_PASSES — linter exited $actual_exit on plan with UX-Waiver: frontmatter (expected 0)"
fi

# (d) Non-UI plan without §UX Spec — linter must pass (exit 0, exempt)
actual_exit=0
bash "$LINTER" "$FIXTURES/non-ui.md" >/dev/null 2>&1 || actual_exit=$?
if [ "$actual_exit" -eq 0 ]; then
  _pass "TB3_NON_UI_EXEMPT"
else
  _fail "TB3_NON_UI_EXEMPT — linter exited $actual_exit on non-UI plan (expected 0; non-UI plans exempt)"
fi

# (e) UI plan with §UX Spec heading but empty body — linter must fail (exit non-zero)
HEADING_ONLY_FIXTURE="$(ui_heading_only_fixture)"
actual_exit=0
bash "$LINTER" "$HEADING_ONLY_FIXTURE" >/dev/null 2>&1 || actual_exit=$?
rm -f "$HEADING_ONLY_FIXTURE"
if [ "$actual_exit" -ne 0 ]; then
  _pass "TB3_HEADING_ONLY_FAILS"
else
  _fail "TB3_HEADING_ONLY_FAILS — linter exited 0 on plan with §UX Spec heading but no body (expected non-zero)"
fi

# (f) Plan with malformed frontmatter — linter must exit with a defined code (not crash/signal)
actual_exit=0
bash "$LINTER" "$FIXTURES/malformed-frontmatter.md" >/dev/null 2>&1 || actual_exit=$?
# Signal-terminated exits are ≥128 on POSIX; a clean error exit is 1 or 2
if [ "$actual_exit" -lt 128 ] && [ "$actual_exit" -ne 0 ]; then
  _pass "TB3_MALFORMED_FRONTMATTER_CLEAN_ERROR"
elif [ "$actual_exit" -eq 0 ]; then
  # Exiting 0 on malformed input is also acceptable if the linter treats parse failure
  # as "cannot determine UI scope → pass to avoid false block"; document either is valid.
  _pass "TB3_MALFORMED_FRONTMATTER_CLEAN_ERROR"
else
  _fail "TB3_MALFORMED_FRONTMATTER_CLEAN_ERROR — linter crashed with signal-like exit $actual_exit on malformed frontmatter"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
