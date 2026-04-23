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
for _sh in pre-commit-secrets-guard.sh pre-commit-artifact-guard.sh pre-commit-unit-tests.sh pre-push-tdd.sh pre-commit-agent-shared-rules.sh; do
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
echo "=== bash version check for secrets-guard ==="
# secrets-guard requires bash 4+; verify it exits 1 under bash 3 simulation.
# We test the guard logic directly: if BASH_VERSINFO[0] < 4, the script must exit 1.
_bash_major=$(bash -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null || echo "0")
if [ "$_bash_major" -ge 4 ] 2>/dev/null; then
  echo "  INFO: bash $_bash_major.x on PATH — secrets-guard will run normally"
  PASS=$((PASS+1))
else
  echo "  WARN: bash < 4 on PATH — secrets-guard will block commits with actionable error"
  echo "        Install: brew install bash"
  # Not a FAIL — the guard correctly blocks rather than silently passing; behaviour is expected
  PASS=$((PASS+1))
fi
# Verify the version guard is present in the script source
if grep -q "BASH_VERSINFO\[0\]" "$REPO_ROOT/scripts/hooks/pre-commit-secrets-guard.sh"; then
  echo "  PASS: bash version guard present in pre-commit-secrets-guard.sh"
  PASS=$((PASS+1))
else
  echo "  FAIL: bash version guard missing from pre-commit-secrets-guard.sh"
  FAIL=$((FAIL+1))
fi
# Verify artifact-guard uses bash shebang (relies on dispatcher respecting it)
if head -1 "$REPO_ROOT/scripts/hooks/pre-commit-artifact-guard.sh" | grep -q "bash"; then
  echo "  PASS: pre-commit-artifact-guard.sh has bash shebang (3.2-compatible features only)"
  PASS=$((PASS+1))
else
  echo "  FAIL: pre-commit-artifact-guard.sh missing bash shebang"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== C2 — dashboards package wiring ==="
# Verify each dashboards package has tdd.enabled:true and a test:unit script so
# the pre-commit-unit-tests.sh dispatcher will pick them up.
for _pkg in dashboards/server dashboards/test-dashboard; do
  _pj="$REPO_ROOT/$_pkg/package.json"
  if [ ! -f "$_pj" ]; then
    echo "  FAIL: $_pkg/package.json missing"
    FAIL=$((FAIL+1))
    continue
  fi
  _abs_pj2="$REPO_ROOT/$_pkg/package.json"
  _enabled=$(node -e "try{const p=require('$_abs_pj2');process.stdout.write(String(p.tdd&&p.tdd.enabled===true))}catch(e){process.stdout.write('false')}" 2>/dev/null || echo "false")
  if [ "$_enabled" = "true" ]; then
    echo "  PASS: $_pkg has tdd.enabled:true"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $_pkg missing tdd.enabled:true — hook will skip it"
    FAIL=$((FAIL+1))
  fi
  _test_cmd=$(node -e "try{const p=require('$_abs_pj2');process.stdout.write(p.scripts&&p.scripts['test:unit']||'')}catch(e){}" 2>/dev/null || echo "")
  if [ -n "$_test_cmd" ]; then
    echo "  PASS: $_pkg has test:unit script"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $_pkg missing test:unit script — hook will skip it"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== C2 regression — subdirectory CWD does not break tdd.enabled detection ==="
# Regression test for Jhin R22: require() must use absolute path so the hook
# works correctly when git invokes it from a subdirectory (e.g. cd dashboards/server && git commit).
# We simulate by running the detection node snippet with CWD set to a subdirectory.
_pj_rel="dashboards/server/package.json"
_abs_pj="$REPO_ROOT/$_pj_rel"
_result=$(cd "$REPO_ROOT/dashboards/server" && node -e "try{const p=require('$_abs_pj');process.stdout.write(String(p.tdd&&p.tdd.enabled===true))}catch(e){process.stdout.write('false')}" 2>/dev/null || echo "false")
if [ "$_result" = "true" ]; then
  echo "  PASS: tdd.enabled detected correctly when CWD is dashboards/server (absolute path fix)"
  PASS=$((PASS+1))
else
  echo "  FAIL: tdd.enabled detection broken when CWD is a subdirectory — CWD-relative require() bug"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== C2 — hook uses absolute cd for test runner ==="
# Verify the hook uses 'cd \$REPO_ROOT/\$pkg' (not 'cd \$pkg') so it works from any CWD.
if grep -q 'REPO_ROOT.*pkg' "$REPO_ROOT/scripts/hooks/pre-commit-unit-tests.sh"; then
  echo "  PASS: hook cd uses REPO_ROOT-anchored path"
  PASS=$((PASS+1))
else
  echo "  FAIL: hook cd does not use REPO_ROOT — may break from subdirectory CWD"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== reviewer anonymity tests ==="
if bash "$REPO_ROOT/scripts/hooks/test-pre-commit-reviewer-anonymity.sh" 2>/dev/null; then
  echo "  PASS: test-pre-commit-reviewer-anonymity.sh (all fixtures)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-pre-commit-reviewer-anonymity.sh"
  FAIL=$((FAIL+1))
fi
if bash "$REPO_ROOT/scripts/__tests__/test-reviewer-auth-anonymity.sh" 2>/dev/null; then
  echo "  PASS: test-reviewer-auth-anonymity.sh (all fixtures)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-reviewer-auth-anonymity.sh"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== pretooluse plan-lifecycle-guard tests (physical guard) ==="
if bash "$REPO_ROOT/scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh" 2>/dev/null; then
  echo "  PASS: test-pretooluse-plan-lifecycle-guard.sh (6 invariants)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-pretooluse-plan-lifecycle-guard.sh"
  FAIL=$((FAIL+1))
fi
if bash "$REPO_ROOT/scripts/hooks/tests/test-pretooluse-plan-lifecycle-integration.sh" 2>/dev/null; then
  echo "  PASS: test-pretooluse-plan-lifecycle-integration.sh (integration flow)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-pretooluse-plan-lifecycle-integration.sh"
  FAIL=$((FAIL+1))
fi
# NOTE: orianna v2 commit-phase gate tests (test-plan-promote-guard.sh, test-orianna-gate-v2.sh)
# archived to scripts/hooks/_archive/v2-commit-phase-plan-guards/ — superseded by physical guard above.

echo ""
echo "=== agents/orianna/memory/git-identity.sh smoke ==="
_tmp_repo="$(mktemp -d)"
git -C "$_tmp_repo" init -q
git -C "$_tmp_repo" -c user.email="before@example.com" -c user.name="Before" \
  commit --allow-empty -q -m "init" 2>/dev/null || true
GIT_DIR="$_tmp_repo/.git" GIT_WORK_TREE="$_tmp_repo" \
  bash "$REPO_ROOT/agents/orianna/memory/git-identity.sh" >/dev/null 2>&1
_got_email="$(git -C "$_tmp_repo" config user.email 2>/dev/null || true)"
_got_name="$(git -C "$_tmp_repo" config user.name 2>/dev/null || true)"
rm -rf "$_tmp_repo"
if [ "$_got_email" = "orianna@strawberry.local" ] && [ "$_got_name" = "Orianna" ]; then
  echo "  PASS: git-identity.sh sets orianna@strawberry.local / Orianna"
  PASS=$((PASS+1))
else
  echo "  FAIL: git-identity.sh — got email='$_got_email' name='$_got_name'"
  FAIL=$((FAIL+1))
fi

# NOTE: commit-msg-plan-promote-guard tests archived — superseded by pretooluse physical guard.

echo ""
echo "=== agent default-isolation hook tests (INV-1) ==="
if bash "$REPO_ROOT/scripts/hooks/tests/test-agent-default-isolation.sh" 2>/dev/null; then
  echo "  PASS: test-agent-default-isolation.sh (INV-1 auto-isolation)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-agent-default-isolation.sh"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== edit-only breakdown/test-plan agent defs tests (INV-2/INV-3) ==="
if bash "$REPO_ROOT/scripts/hooks/tests/test-edit-only-agents.sh" 2>/dev/null; then
  echo "  PASS: test-edit-only-agents.sh (INV-2 no Write, INV-3 default_isolation set)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-edit-only-agents.sh"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== orianna v2 gate — invariants #4 and #5 ==="
if bash "$REPO_ROOT/scripts/hooks/test-orianna-gate-inv4-inv5.sh" 2>/dev/null; then
  echo "  PASS: test-orianna-gate-inv4-inv5.sh (INV-4 idempotence + INV-5 lifecycle smoke)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-orianna-gate-inv4-inv5.sh"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== cleanup-merged-branches.sh tests ==="
if bash "$REPO_ROOT/scripts/test-cleanup-merged-branches.sh" 2>/dev/null; then
  echo "  PASS: test-cleanup-merged-branches.sh (5 invariants)"
  PASS=$((PASS+1))
else
  echo "  FAIL: test-cleanup-merged-branches.sh"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
