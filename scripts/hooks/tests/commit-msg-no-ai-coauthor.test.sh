#!/usr/bin/env bash
# scripts/hooks/tests/commit-msg-no-ai-coauthor.test.sh
# kind: test
# xfail regression test for scripts/hooks/commit-msg-no-ai-coauthor.sh
#
# Plan: plans/in-progress/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md Task 1
#
# xfail guard: if the hook does not yet exist, print xfail and exit 0.
# Per Rule 12, this test commit MUST land BEFORE the hook implementation commit.
#
# Cases (per plan §3 and §Test plan):
#   1 — exact 663c274 trailer → exit 1, stderr contains the offending line       (I1)
#   2 — same message + Human-Verified: yes → exit 0                              (I2a)
#   3 — clean message, no trailer → exit 0                                       (I3)
#   4 — non-AI co-author (Jane Doe) → exit 0                                     (I3)
#   5 — word-boundary: Kai Nguyen → exit 0                                       (I4)
#   6 — lowercase human-verified: yes does NOT suppress (case-sensitive) → exit 1 (I2b)
#   7 — @anthropic.com domain → exit 1                                           (I1)

set -uo pipefail

HOOK="scripts/hooks/commit-msg-no-ai-coauthor.sh"
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_ABS="$REPO_ROOT/$HOOK"

# xfail guard — hook not yet implemented
if [ ! -x "$HOOK_ABS" ]; then
  printf 'xfail — hook not yet implemented: %s\n' "$HOOK_ABS" >&2
  exit 0
fi

pass=0
fail=0

# ---------- helpers ----------

# make_msg: write lines to a temp file, return path via stdout
make_msg() {
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$@" > "$tmp"
  printf '%s' "$tmp"
}

assert_exit() {
  local label="$1"
  local expected="$2"
  local tmpfile="$3"
  local actual=0
  bash "$HOOK_ABS" "$tmpfile" 2>/dev/null || actual=$?
  if [ "$actual" = "$expected" ]; then
    printf 'PASS %s\n' "$label"
    pass=$((pass + 1))
  else
    printf 'FAIL %s (expected exit %s, got %s)\n' "$label" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

assert_stderr_contains() {
  local label="$1"
  local pattern="$2"
  local tmpfile="$3"
  local stderr_out
  stderr_out="$(bash "$HOOK_ABS" "$tmpfile" 2>&1 >/dev/null || true)"
  if printf '%s\n' "$stderr_out" | grep -qF "$pattern"; then
    printf 'PASS %s\n' "$label"
    pass=$((pass + 1))
  else
    printf 'FAIL %s (pattern not found in stderr: %s)\n' "$label" "$pattern"
    fail=$((fail + 1))
  fi
}

# ---------- fixtures ----------

# Exact trailer from commit 663c274
AI_TRAILER='Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>'

CLEAN_MSG="chore: update swain memory"
AI_MSG="$(printf 'chore: update swain memory\n\n%s' "$AI_TRAILER")"
AI_MSG_WITH_OVERRIDE="$(printf 'chore: update swain memory\n\n%s\nHuman-Verified: yes' "$AI_TRAILER")"
AI_MSG_LC_OVERRIDE="$(printf 'chore: update swain memory\n\n%s\nhuman-verified: yes' "$AI_TRAILER")"
HUMAN_MSG="$(printf 'chore: pair session notes\n\nCo-Authored-By: Jane Doe <jane@example.com>')"
KAI_MSG="$(printf 'chore: notes\n\nCo-Authored-By: Kai Nguyen <kai@example.com>')"
DOMAIN_MSG="$(printf 'chore: fix\n\nCo-Authored-By: SomeBot <bot@anthropic.com>')"

# ---------- case 1: 663c274 trailer → exit 1 ----------
echo "=== Case 1: exact 663c274 trailer rejected ==="
tmp1="$(make_msg "chore: update swain memory" "" "$AI_TRAILER")"
assert_exit "exit 1 on AI trailer" 1 "$tmp1"
assert_stderr_contains "stderr contains offending line" "Co-Authored-By:" "$tmp1"
rm -f "$tmp1"

# ---------- case 2: Human-Verified: yes → exit 0 ----------
echo "=== Case 2: Human-Verified: yes suppresses check ==="
tmp2="$(make_msg "chore: update swain memory" "" "$AI_TRAILER" "Human-Verified: yes")"
assert_exit "exit 0 with Human-Verified: yes" 0 "$tmp2"
rm -f "$tmp2"

# ---------- case 3: clean message → exit 0 ----------
echo "=== Case 3: clean message passes ==="
tmp3="$(make_msg "chore: update swain memory")"
assert_exit "exit 0 on clean message" 0 "$tmp3"
rm -f "$tmp3"

# ---------- case 4: non-AI co-author → exit 0 ----------
echo "=== Case 4: human co-author passes ==="
tmp4="$(make_msg "chore: pair session notes" "" "Co-Authored-By: Jane Doe <jane@example.com>")"
assert_exit "exit 0 for Jane Doe" 0 "$tmp4"
rm -f "$tmp4"

# ---------- case 5: word-boundary — Kai Nguyen → exit 0 ----------
echo "=== Case 5: Kai Nguyen word-boundary passes ==="
tmp5="$(make_msg "chore: notes" "" "Co-Authored-By: Kai Nguyen <kai@example.com>")"
assert_exit "exit 0 for Kai Nguyen (word-boundary AI false-positive guard)" 0 "$tmp5"
rm -f "$tmp5"

# ---------- case 6: lowercase human-verified: yes does NOT suppress → exit 1 ----------
echo "=== Case 6: lowercase human-verified: yes does NOT suppress ==="
tmp6="$(make_msg "chore: update swain memory" "" "$AI_TRAILER" "human-verified: yes")"
assert_exit "exit 1 even with lowercase human-verified" 1 "$tmp6"
rm -f "$tmp6"

# ---------- case 7: @anthropic.com domain → exit 1 ----------
echo "=== Case 7: anthropic.com email domain rejected ==="
tmp7="$(make_msg "chore: fix" "" "Co-Authored-By: SomeBot <bot@anthropic.com>")"
assert_exit "exit 1 on anthropic.com domain" 1 "$tmp7"
rm -f "$tmp7"

# ---------- results ----------
echo ""
printf 'Results: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
