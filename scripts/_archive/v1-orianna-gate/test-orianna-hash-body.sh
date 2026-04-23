#!/bin/sh
# T5.1 — xfail tests for scripts/orianna-hash-body.sh
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T5.1
# Run: bash scripts/test-orianna-hash-body.sh
# All 4 cases are expected to FAIL until T1.1 (orianna-hash-body.sh) is implemented.
# Exit code: 0 when all cases behave as expected (xfail = expected failure).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HASH_BODY="$SCRIPT_DIR/orianna-hash-body.sh"

PASS=0
FAIL=0

assert_eq() {
  label="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'PASS  %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf 'FAIL  %s\n' "$label"
    printf '      expected: %s\n' "$expected"
    printf '      actual:   %s\n' "$actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_ne() {
  label="$1"; a="$2"; b="$3"
  if [ "$a" != "$b" ]; then
    printf 'PASS  %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf 'FAIL  %s  (hashes unexpectedly equal: %s)\n' "$label" "$a"
    FAIL=$((FAIL + 1))
  fi
}

# --- XFAIL guard: if the script does not exist yet, all tests must "fail" ---
# In xfail mode we still report each case so CI sees meaningful output.
if [ ! -f "$HASH_BODY" ]; then
  printf 'XFAIL  orianna-hash-body.sh not present — all 4 cases expected to fail (T1.1 not yet implemented)\n'
  printf 'XFAIL  CRLF_LF_PARITY\n'
  printf 'XFAIL  TRAILING_WS_PARITY\n'
  printf 'XFAIL  FRONTMATTER_ONLY_SAME_HASH\n'
  printf 'XFAIL  BODY_CHANGE_DIFFERENT_HASH\n'
  printf '\nResults: 0 passed, 4 xfail (expected — implementation not present)\n'
  exit 0
fi

# --- FIXTURE helpers ---
make_plan_lf() {
  # Returns a temp-file path for a plan with LF line endings
  f="$(mktemp)"
  cat > "$f" << 'EOF'
---
title: test
status: proposed
---

# Body

Some content here.
EOF
  printf '%s' "$f"
}

make_plan_crlf() {
  # Same body as make_plan_lf but CRLF line endings
  f="$(mktemp)"
  # Build CRLF content: each line ends with \r\n
  printf '%b' '---\r\ntitle: test\r\nstatus: proposed\r\n---\r\n\r\n# Body\r\n\r\nSome content here.\r\n' > "$f"
  printf '%s' "$f"
}

make_plan_trailing_ws() {
  # Body lines have trailing spaces — use printf %b to preserve them
  f="$(mktemp)"
  printf '%b' '---\ntitle: test\nstatus: proposed\n---\n\n# Body   \n\nSome content here.   \n' > "$f"
  printf '%s' "$f"
}

make_plan_frontmatter_only_change() {
  # Frontmatter differs from base but body is identical
  f="$(mktemp)"
  cat > "$f" << 'EOF'
---
title: CHANGED TITLE
status: approved
extra_field: added
---

# Body

Some content here.
EOF
  printf '%s' "$f"
}

make_plan_body_changed() {
  # Body text differs from base
  f="$(mktemp)"
  cat > "$f" << 'EOF'
---
title: test
status: proposed
---

# Body

DIFFERENT content here.
EOF
  printf '%s' "$f"
}

# --- CASE 1: CRLF and LF produce the same hash ---
LF_FILE="$(make_plan_lf)"
CRLF_FILE="$(make_plan_crlf)"
HASH_LF="$(bash "$HASH_BODY" "$LF_FILE")"
HASH_CRLF="$(bash "$HASH_BODY" "$CRLF_FILE")"
assert_eq "CRLF_LF_PARITY" "$HASH_LF" "$HASH_CRLF"
rm -f "$LF_FILE" "$CRLF_FILE"

# --- CASE 2: Trailing whitespace and no trailing whitespace produce the same hash ---
BASE_FILE="$(make_plan_lf)"
TRAILING_FILE="$(make_plan_trailing_ws)"
HASH_BASE="$(bash "$HASH_BODY" "$BASE_FILE")"
HASH_TRAILING="$(bash "$HASH_BODY" "$TRAILING_FILE")"
assert_eq "TRAILING_WS_PARITY" "$HASH_BASE" "$HASH_TRAILING"
rm -f "$BASE_FILE" "$TRAILING_FILE"

# --- CASE 3: Frontmatter-only change → same body hash ---
BASE_FILE="$(make_plan_lf)"
FM_CHANGE_FILE="$(make_plan_frontmatter_only_change)"
HASH_BASE="$(bash "$HASH_BODY" "$BASE_FILE")"
HASH_FM="$(bash "$HASH_BODY" "$FM_CHANGE_FILE")"
assert_eq "FRONTMATTER_ONLY_SAME_HASH" "$HASH_BASE" "$HASH_FM"
rm -f "$BASE_FILE" "$FM_CHANGE_FILE"

# --- CASE 4: Body change → different hash ---
BASE_FILE="$(make_plan_lf)"
BODY_CHANGED_FILE="$(make_plan_body_changed)"
HASH_BASE="$(bash "$HASH_BODY" "$BASE_FILE")"
HASH_CHANGED="$(bash "$HASH_BODY" "$BODY_CHANGED_FILE")"
assert_ne "BODY_CHANGE_DIFFERENT_HASH" "$HASH_BASE" "$HASH_CHANGED"
rm -f "$BASE_FILE" "$BODY_CHANGED_FILE"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
