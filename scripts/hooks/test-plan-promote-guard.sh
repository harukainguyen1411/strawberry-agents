#!/bin/sh
# test-plan-promote-guard.sh — Unit tests for pre-commit-plan-promote-guard.sh (v2)
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T4
# Run: bash scripts/hooks/test-plan-promote-guard.sh
# Exits 0 if all tests pass.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/pre-commit-plan-promote-guard.sh"
IDENTITY_FILE="$SCRIPT_DIR/_orianna_identity.txt"

ORIANNA_EMAIL="orianna@strawberry.local"
ADMIN_EMAIL="harukainguyen1411@gmail.com"
GENERIC_EMAIL="agent@example.com"

PASS=0
FAIL=0

make_repo() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed/personal" "$r/plans/approved/personal" "$r/scripts/hooks"
  printf -- '---\nstatus: proposed\ntitle: test\nowner: tester\nconcern: personal\ncreated: 2026-04-22\ntests_required: false\n---\n\n# Test\n' \
    > "$r/plans/proposed/personal/2026-04-22-test-plan.md"
  git -C "$r" add plans/
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit -q -m "add proposed plan"
  # Install identity file into the test repo
  cp "$IDENTITY_FILE" "$r/scripts/hooks/_orianna_identity.txt"
  printf '%s' "$r"
}

run_hook() {
  repo="$1"
  msg="${2:-}"
  author_email="${3:-$GENERIC_EMAIL}"
  if [ -n "$msg" ]; then
    printf '%s\n' "$msg" > "$repo/.git/COMMIT_EDITMSG"
  fi
  GIT_DIR="$repo/.git" \
  GIT_WORK_TREE="$repo" \
  GIT_AUTHOR_EMAIL="$author_email" \
    bash "$HOOK" 2>&1
}

# --- TEST 1: generic author + no trailer → BLOCKED ---------------------------
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
rc=0; output="$(run_hook "$REPO" "chore: promote" "$GENERIC_EMAIL")" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'PASS  TEST 1 (generic author, no trailer → blocked): hook exited %d\n' "$rc"
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 1: expected non-zero exit, got 0\n'
  printf '      %s\n' "$output"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 2: Orianna identity + Promoted-By: Orianna trailer → ALLOWED ------
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
VALID_MSG="chore: promote plan to approved

Promoted-By: Orianna"
rc=0; output="$(run_hook "$REPO" "$VALID_MSG" "$ORIANNA_EMAIL")" || rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'PASS  TEST 2 (Orianna + trailer → allowed): hook exited 0\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 2: expected exit 0, got %d\n' "$rc"
  printf '      %s\n' "$output"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 3: generic author + Promoted-By: Orianna → FORGED, BLOCKED --------
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
FORGED_MSG="chore: promote plan

Promoted-By: Orianna"
rc=0; output="$(run_hook "$REPO" "$FORGED_MSG" "$GENERIC_EMAIL")" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'PASS  TEST 3 (forged trailer → blocked): hook exited %d\n' "$rc"
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 3: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 4: admin identity + no trailer → ALLOWED --------------------------
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
rc=0; output="$(run_hook "$REPO" "chore: promote" "$ADMIN_EMAIL")" || rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'PASS  TEST 4 (admin, no trailer → allowed): hook exited 0\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 4: expected exit 0, got %d\n' "$rc"
  printf '      %s\n' "$output"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 5: generic author creates directly in plans/approved/ → BLOCKED ---
REPO="$(make_repo)"
mkdir -p "$REPO/plans/approved/personal"
printf -- '---\nstatus: approved\n---\n\n# Bypass\n' \
  > "$REPO/plans/approved/personal/2026-04-22-bypass.md"
git -C "$REPO" add plans/approved/
rc=0; output="$(run_hook "$REPO" "chore: sneaky" "$GENERIC_EMAIL")" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'PASS  TEST 5 (direct create in approved/ by generic → blocked): hook exited %d\n' "$rc"
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 5: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 6: non-admin author modifying .claude/agents/orianna.md → BLOCKED -
REPO="$(make_repo)"
mkdir -p "$REPO/.claude/agents"
printf 'model: opus\n---\n# Orianna\n' > "$REPO/.claude/agents/orianna.md"
git -C "$REPO" add .claude/
rc=0; output="$(run_hook "$REPO" "chore: edit orianna" "$GENERIC_EMAIL")" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'PASS  TEST 6 (non-admin modifying orianna.md → blocked): hook exited %d\n' "$rc"
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 6: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
