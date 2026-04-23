#!/bin/bash
# test-orianna-bypass-audit.sh
# xfail: orianna-bypass-audit.sh does not exist yet.
# Rule 12 — xfail test committed before T7 implementation.
#
# Tests INV-7: given a plan file committed into plans/approved/ by a non-Orianna
# identity, orianna-bypass-audit.sh reports that file as a bypass orphan (stdout
# line containing commit SHA, author email, and plan path) and exits 0.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel)"
AUDIT="$REPO_ROOT/scripts/orianna-bypass-audit.sh"

if [ ! -f "$AUDIT" ]; then
  printf 'XFAIL: %s not found — T7 not yet implemented (expected per Rule 12)\n' "$AUDIT"
  exit 1
fi

PASS=0
FAIL=0

echo "=== orianna-bypass-audit.sh tests ==="

# Create a temporary git repo to simulate a bypass commit
_tmp_repo="$(mktemp -d)"
git -C "$_tmp_repo" init -q

# Create necessary directory structure
mkdir -p "$_tmp_repo/plans/approved/personal"
mkdir -p "$_tmp_repo/agents/orianna/memory"

# Create a fake git-identity.sh pointing at orianna identity
cat > "$_tmp_repo/agents/orianna/memory/git-identity.sh" <<'SH'
git config user.email "orianna@strawberry.local"
git config user.name "Orianna"
SH

# Commit a plan file as non-Orianna (simulating a bypass)
printf '# Test plan\nstatus: approved\n' > "$_tmp_repo/plans/approved/personal/bypass-test.md"
git -C "$_tmp_repo" add plans/approved/personal/bypass-test.md
git -C "$_tmp_repo" -c user.email="duongntd99@gmail.com" -c user.name="Duong" \
  commit -q -m "chore: test bypass commit"

_bypass_sha="$(git -C "$_tmp_repo" log --format='%H' -1)"
_bypass_email="duongntd99@gmail.com"

# Run the audit against the temp repo
_output="$(GIT_DIR="$_tmp_repo/.git" GIT_WORK_TREE="$_tmp_repo" \
  bash "$AUDIT" --repo-root "$_tmp_repo" 2>/dev/null)"
_exit_code=$?

# INV-7a: audit must exit 0 (non-blocking)
if [ "$_exit_code" = "0" ]; then
  printf '  PASS: INV-7a: audit exits 0 (non-blocking)\n'
  PASS=$((PASS+1))
else
  printf '  FAIL: INV-7a: audit exited %s (expected 0)\n' "$_exit_code"
  FAIL=$((FAIL+1))
fi

# INV-7b: output contains the bypass SHA
if echo "$_output" | grep -q "$_bypass_sha"; then
  printf '  PASS: INV-7b: output contains bypass commit SHA\n'
  PASS=$((PASS+1))
else
  printf '  FAIL: INV-7b: output does not contain SHA %s\n' "$_bypass_sha"
  printf '  output was: %s\n' "$_output"
  FAIL=$((FAIL+1))
fi

# INV-7c: output contains the author email
if echo "$_output" | grep -q "$_bypass_email"; then
  printf '  PASS: INV-7c: output contains author email\n'
  PASS=$((PASS+1))
else
  printf '  FAIL: INV-7c: output does not contain author email %s\n' "$_bypass_email"
  FAIL=$((FAIL+1))
fi

# INV-7d: output contains the plan path
if echo "$_output" | grep -q "plans/approved/personal/bypass-test.md"; then
  printf '  PASS: INV-7d: output contains plan path\n'
  PASS=$((PASS+1))
else
  printf '  FAIL: INV-7d: output does not contain plan path\n'
  FAIL=$((FAIL+1))
fi

rm -rf "$_tmp_repo"

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
