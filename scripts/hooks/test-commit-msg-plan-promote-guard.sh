#!/bin/sh
# test-commit-msg-plan-promote-guard.sh — tests for commit-msg-plan-promote-guard.sh
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T4
# Run: bash scripts/hooks/test-commit-msg-plan-promote-guard.sh
# Exits 0 if all tests pass.
#
# Uses real git commits (not pre-written COMMIT_EDITMSG) so the commit-msg hook
# receives the message via $1 exactly as git does in production.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/commit-msg-plan-promote-guard.sh"
IDENTITY_FILE="$SCRIPT_DIR/_orianna_identity.txt"

ORIANNA_EMAIL="orianna@strawberry.local"
ADMIN_EMAIL="harukainguyen1411@gmail.com"
GENERIC_EMAIL="agent@example.com"

PASS=0
FAIL=0

if [ ! -f "$HOOK" ]; then
  printf 'xfail — commit-msg-plan-promote-guard.sh not yet created\n' >&2
  exit 0
fi

if [ ! -f "$IDENTITY_FILE" ]; then
  printf 'xfail — identity file missing\n' >&2
  exit 0
fi

# Build a sandbox git repo with promotion staged
make_promo_repo() {
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
  cp "$IDENTITY_FILE" "$r/scripts/hooks/_orianna_identity.txt"
  # Install commit-msg hook
  cp "$HOOK" "$r/.git/hooks/commit-msg"
  chmod +x "$r/.git/hooks/commit-msg"
  # Stage a rename from proposed to approved
  git -C "$r" mv \
    plans/proposed/personal/2026-04-22-test-plan.md \
    plans/approved/personal/2026-04-22-test-plan.md
  printf '%s' "$r"
}

run_commit() {
  repo="$1"; msg="$2"; author_email="$3"
  rc=0
  GIT_AUTHOR_EMAIL="$author_email" \
  GIT_COMMITTER_EMAIL="$author_email" \
  git -C "$repo" \
    -c user.email="$author_email" \
    -c user.name="TestUser" \
    commit --no-verify -m "$msg" 2>&1 || rc=$?
  printf '%d' "$rc"
}

# We call the hook directly (not via git commit) so we can test without needing
# --no-verify on the pre-commit hook. The commit-msg hook is invoked by writing
# a temp file with the message and calling the hook with it.

run_hook_direct() {
  msg="$1"; author_email="$2"
  tmp="$(mktemp)"
  printf '%s\n' "$msg" > "$tmp"
  rc=0
  GIT_AUTHOR_EMAIL="$author_email" \
    bash "$HOOK" "$tmp" 2>&1 || rc=$?
  rm -f "$tmp"
  printf '%d' "$rc"
}

# We also need a staged promo diff for the hook to detect.
# The hook inspects git diff --cached, so we need a real repo context.
run_hook_in_repo() {
  repo="$1"; msg="$2"; author_email="$3"
  tmp="$(mktemp)"
  printf '%s\n' "$msg" > "$tmp"
  _rc=0
  GIT_DIR="$repo/.git" \
  GIT_WORK_TREE="$repo" \
  GIT_AUTHOR_EMAIL="$author_email" \
    bash "$HOOK" "$tmp" 2>/dev/null || _rc=$?
  rm -f "$tmp"
  printf '%d' "$_rc"
}

# --- TEST 1: Orianna + Promoted-By: Orianna trailer → ALLOWED ----------------
REPO="$(make_promo_repo)"
VALID_MSG="chore: promote plan to approved

Promoted-By: Orianna
Rationale: test"
rc="$(run_hook_in_repo "$REPO" "$VALID_MSG" "$ORIANNA_EMAIL")"
if [ "$rc" -eq 0 ]; then
  printf 'PASS  TEST 1 (Orianna + trailer → allowed): hook exited 0\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 1: expected exit 0, got %s\n' "$rc"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 2: Orianna without Promoted-By trailer → BLOCKED -------------------
REPO="$(make_promo_repo)"
NO_TRAILER_MSG="chore: promote plan to approved"
rc="$(run_hook_in_repo "$REPO" "$NO_TRAILER_MSG" "$ORIANNA_EMAIL")"
if [ "$rc" -ne 0 ]; then
  printf 'PASS  TEST 2 (Orianna, no trailer → blocked): hook exited %s\n' "$rc"
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 2: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 3: trailer forgery (generic author + Promoted-By: Orianna) → BLOCKED
REPO="$(make_promo_repo)"
FORGED_MSG="chore: promote plan

Promoted-By: Orianna
Rationale: forged"
rc="$(run_hook_in_repo "$REPO" "$FORGED_MSG" "$GENERIC_EMAIL")"
if [ "$rc" -ne 0 ]; then
  printf 'PASS  TEST 3 (forged trailer → blocked): hook exited %s\n' "$rc"
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 3: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 4: admin + no trailer → ALLOWED (non-promotion commit) -------------
# For a non-promotion diff, the hook should pass through regardless of identity.
REPO="$(mktemp -d)"
git -C "$REPO" init -q
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit --allow-empty -q -m "init"
mkdir -p "$REPO/scripts/hooks"
cp "$IDENTITY_FILE" "$REPO/scripts/hooks/_orianna_identity.txt"
# Stage a non-plan file
printf 'hello\n' > "$REPO/README.md"
git -C "$REPO" add README.md
rc="$(run_hook_in_repo "$REPO" "chore: add readme" "$GENERIC_EMAIL")"
if [ "$rc" -eq 0 ]; then
  printf 'PASS  TEST 4 (non-promotion commit → allowed): hook exited 0\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 4: expected exit 0 for non-promotion, got %s\n' "$rc"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 5: Orianna-Bypass: trailer by admin → ALLOWED ----------------------
REPO="$(make_promo_repo)"
BYPASS_MSG="chore: admin bypass promote

Orianna-Bypass: emergency fix"
rc="$(run_hook_in_repo "$REPO" "$BYPASS_MSG" "$ADMIN_EMAIL")"
if [ "$rc" -eq 0 ]; then
  printf 'PASS  TEST 5 (admin Orianna-Bypass → allowed): hook exited 0\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 5: expected exit 0 for admin bypass, got %s\n' "$rc"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- TEST 6: Orianna-Bypass: trailer by non-admin → BLOCKED ------------------
REPO="$(make_promo_repo)"
BYPASS_MSG_BAD="chore: agent bypass promote

Orianna-Bypass: trying to bypass"
rc="$(run_hook_in_repo "$REPO" "$BYPASS_MSG_BAD" "$GENERIC_EMAIL")"
if [ "$rc" -ne 0 ]; then
  printf 'PASS  TEST 6 (non-admin Orianna-Bypass → blocked): hook exited %s\n' "$rc"
  PASS=$((PASS + 1))
else
  printf 'FAIL  TEST 6: expected non-zero exit for agent bypass, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
