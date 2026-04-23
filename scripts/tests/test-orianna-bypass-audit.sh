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

# --- T7 inversion xfail test ---
# Senna finding: git log --follow --diff-filter=AR | tail -1 returns the original
# propose commit (authored by Orianna), not the promotion commit (authored by
# non-Orianna). The fixed audit must use --diff-filter=R and filter on new-path
# so that a rename into a protected dir by a non-Orianna identity is flagged.
#
# Scenario:
#   commit A — Orianna adds plans/proposed/personal/senna-t7.md
#   commit B — non-Orianna renames it to plans/approved/personal/senna-t7.md
# Expected: audit flags commit B as orphan (non-Orianna promoted into protected dir)
# Current (buggy): tail -1 returns commit A (Orianna authored) → no orphan reported

_tmp2="$(mktemp -d)"
git -C "$_tmp2" init -q

mkdir -p "$_tmp2/plans/proposed/personal"
mkdir -p "$_tmp2/plans/approved/personal"
mkdir -p "$_tmp2/agents/orianna/memory"

cat > "$_tmp2/agents/orianna/memory/git-identity.sh" <<'SH'
git config user.email "orianna@strawberry.local"
git config user.name "Orianna"
SH

# Commit A: Orianna proposes the plan
printf '# Senna T7 test plan\nstatus: proposed\n' > "$_tmp2/plans/proposed/personal/senna-t7.md"
git -C "$_tmp2" add plans/proposed/personal/senna-t7.md
git -C "$_tmp2" -c user.email="orianna@strawberry.local" -c user.name="Orianna" \
  commit -q -m "chore: propose senna-t7 plan"

# Commit B: non-Orianna promotes (renames) to approved
git -C "$_tmp2" mv plans/proposed/personal/senna-t7.md plans/approved/personal/senna-t7.md
git -C "$_tmp2" -c user.email="ekko@strawberry.local" -c user.name="Ekko" \
  commit -q -m "chore: promote senna-t7 plan (unauthorized)"

_promo_sha="$(git -C "$_tmp2" log --format='%H' -1)"
_promo_email="ekko@strawberry.local"

_output2="$(bash "$AUDIT" --repo-root "$_tmp2" 2>/dev/null)"
_exit2=$?

# INV-7e: audit exits 0
if [ "$_exit2" = "0" ]; then
  printf '  PASS: INV-7e: rename-scenario audit exits 0\n'
  PASS=$((PASS+1))
else
  printf '  FAIL: INV-7e: audit exited %s (expected 0)\n' "$_exit2"
  FAIL=$((FAIL+1))
fi

# INV-7f: audit must flag the PROMOTION commit (non-Orianna rename), not pass silently
# The buggy tail-1 logic returns commit A (Orianna), reports no orphan → this test FAILs
# until the fix (--diff-filter=R new-path matching) is applied.
if echo "$_output2" | grep -q "$_promo_sha"; then
  printf '  PASS: INV-7f: rename-scenario output contains promotion SHA (T7 inversion fixed)\n'
  PASS=$((PASS+1))
else
  printf '  FAIL: INV-7f: rename-scenario output does not contain promotion SHA %s\n' "$_promo_sha"
  printf '         (T7 inversion: tail -1 returned original propose commit, not promotion)\n'
  printf '  output was: %s\n' "$_output2"
  FAIL=$((FAIL+1))
fi

# INV-7g: output contains the non-Orianna promoter email
if echo "$_output2" | grep -q "$_promo_email"; then
  printf '  PASS: INV-7g: rename-scenario output contains promoter email\n'
  PASS=$((PASS+1))
else
  printf '  FAIL: INV-7g: rename-scenario output does not contain promoter email %s\n' "$_promo_email"
  FAIL=$((FAIL+1))
fi

rm -rf "$_tmp2"

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
