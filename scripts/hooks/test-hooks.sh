#!/bin/sh
# Plain bash test harness for TDD hook scripts.
# Bootstrap exemption: xfail-first hook doesn't exist yet when this runs.
# Run with: sh scripts/hooks/test-hooks.sh
set -e

PASS=0
FAIL=0
REPO_ROOT="$(git rev-parse --show-toplevel)"

assert_exit() {
  label="$1"
  expected="$2"
  shift 2
  actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $label (expected exit $expected, got $actual)"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  label="$1"
  pattern="$2"
  input="$3"
  if echo "$input" | grep -q "$pattern"; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $label (pattern '$pattern' not found)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== pre-commit-unit-tests.sh ==="

# Test: script is executable
assert_exit "pre-commit-unit-tests.sh exists and is readable" 0 sh -n "$REPO_ROOT/scripts/hooks/pre-commit-unit-tests.sh"

# Test: no staged files => exits 0 (we simulate by setting GIT_INDEX_FILE to empty)
tmp_index=$(mktemp)
result=0
GIT_INDEX_FILE="$tmp_index" sh "$REPO_ROOT/scripts/hooks/pre-commit-unit-tests.sh" 2>/dev/null || result=$?
rm -f "$tmp_index"
if [ "$result" = "0" ]; then
  echo "  PASS: exits 0 when no staged files"
  PASS=$((PASS+1))
else
  echo "  FAIL: exits $result when no staged files (expected 0)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== pre-push-tdd.sh ==="

assert_exit "pre-push-tdd.sh syntax is valid" 0 sh -n "$REPO_ROOT/scripts/hooks/pre-push-tdd.sh"

# Test: empty stdin (no refs) => exits 0
result=0
echo "" | sh "$REPO_ROOT/scripts/hooks/pre-push-tdd.sh" origin fake-url 2>/dev/null || result=$?
if [ "$result" = "0" ]; then
  echo "  PASS: exits 0 with empty ref list"
  PASS=$((PASS+1))
else
  echo "  FAIL: exits $result with empty ref list (expected 0)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== install-hooks.sh ==="
assert_exit "install-hooks.sh syntax is valid" 0 sh -n "$REPO_ROOT/scripts/install-hooks.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
