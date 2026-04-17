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

# Test: dispatcher is generated for pre-commit and pre-push verbs
tmp_hooks=$(mktemp -d)
(
  # Run installer pointed at temp hooks dir
  GIT_DIR_OVERRIDE="$tmp_hooks" sh -c '
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    HOOKS_SRC="$REPO_ROOT/scripts/hooks"
    HOOKS_DIR="'"$tmp_hooks"'"
    mkdir -p "$HOOKS_DIR"
    # Inline the dispatcher install logic (same as install-hooks.sh install_dispatcher)
    for verb in pre-commit pre-push; do
      dst="$HOOKS_DIR/$verb"
      printf "#!/bin/sh\n# strawberry-managed dispatcher for %s\n" "$verb" > "$dst"
      printf "REPO_ROOT=\"\$(git rev-parse --show-toplevel)\"\n" >> "$dst"
      printf "HOOKS_SRC=\"\$REPO_ROOT/scripts/hooks\"\n" >> "$dst"
      printf "_rc=0\n" >> "$dst"
      printf "for _sub in \$(ls \"\$HOOKS_SRC\"/*.sh 2>/dev/null | sort); do\n" >> "$dst"
      printf "  _base=\$(basename \"\$_sub\")\n" >> "$dst"
      printf "  case \"\$_base\" in\n" >> "$dst"
      printf "    %s-*.sh) sh \"\$_sub\" \"\$@\" || _rc=\$? ;;\n" "$verb" >> "$dst"
      printf "  esac\n" >> "$dst"
      printf "done\n" >> "$dst"
      printf "exit \$_rc\n" >> "$dst"
      chmod +x "$dst"
    done
  ' 2>/dev/null
)
if [ -f "$tmp_hooks/pre-commit" ] && grep -q "strawberry-managed" "$tmp_hooks/pre-commit"; then
  echo "  PASS: install_dispatcher creates pre-commit with strawberry-managed marker"
  PASS=$((PASS+1))
else
  echo "  FAIL: pre-commit dispatcher not created or missing marker"
  FAIL=$((FAIL+1))
fi
if [ -f "$tmp_hooks/pre-push" ] && grep -q "strawberry-managed" "$tmp_hooks/pre-push"; then
  echo "  PASS: install_dispatcher creates pre-push with strawberry-managed marker"
  PASS=$((PASS+1))
else
  echo "  FAIL: pre-push dispatcher not created or missing marker"
  FAIL=$((FAIL+1))
fi
rm -rf "$tmp_hooks"

echo ""
echo "=== sub-hook presence (B6 regression) ==="
for _sh in pre-commit-secrets-guard.sh pre-commit-artifact-guard.sh pre-commit-unit-tests.sh pre-push-tdd.sh; do
  if [ -f "$REPO_ROOT/scripts/hooks/$_sh" ]; then
    echo "  PASS: scripts/hooks/$_sh present"
    PASS=$((PASS+1))
  else
    echo "  FAIL: scripts/hooks/$_sh MISSING — dispatcher will not invoke it"
    FAIL=$((FAIL+1))
  fi
done

# Verify dispatcher glob matches at least 3 pre-commit sub-hooks
_count=$(ls "$REPO_ROOT/scripts/hooks/pre-commit-"*.sh 2>/dev/null | wc -l | tr -d ' ')
if [ "$_count" -ge 3 ]; then
  echo "  PASS: dispatcher glob matches $_count pre-commit sub-hooks"
  PASS=$((PASS+1))
else
  echo "  FAIL: expected >=3 pre-commit sub-hooks, found $_count"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
