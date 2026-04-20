#!/bin/sh
# pre-commit-orianna-signature-guard.sh — Enforce Orianna signing commit shape.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D1.2, §D7.3, T2.3
#
# When the commit author is Orianna's identity (orianna@agents.strawberry.local),
# enforce that the commit matches the expected signing shape:
#   1. Diff touches exactly one file under plans/.
#   2. Diff adds exactly one orianna_signature_<phase> line (no other content change).
#   3. All three trailers present in COMMIT_EDITMSG: Signed-by: Orianna,
#      Signed-phase: <phase>, Signed-hash: sha256:<hash>.
#   4. The phase in Signed-phase and the added signature line name are consistent.
#
# Commits by other authors pass through unconditionally.
#
# Reads COMMIT_EDITMSG via GIT_DIR (set by git), or falls back to
# .git/COMMIT_EDITMSG relative to GIT_WORK_TREE.

set -eu

ORIANNA_EMAIL="orianna@agents.strawberry.local"

# Determine git context
GIT_DIR="${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}"
GIT_WORK_TREE="${GIT_WORK_TREE:-$(git rev-parse --show-toplevel 2>/dev/null)}"

# --- Check author identity ---
# GIT_AUTHOR_EMAIL may be set by git as an env var during commit.
# If not set, read from git config.
AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$(git -C "$GIT_WORK_TREE" config user.email 2>/dev/null || echo '')}"

# Only enforce for Orianna commits
if [ "$AUTHOR_EMAIL" != "$ORIANNA_EMAIL" ]; then
  exit 0
fi

# --- CHECK 1: diff touches exactly one file under plans/ ---
STAGED_FILES="$(git diff --cached --name-status 2>/dev/null)"
NUM_STAGED="$(printf '%s\n' "$STAGED_FILES" | grep -c '^[AMDRC]' || echo 0)"

if [ "$NUM_STAGED" -ne 1 ]; then
  printf '[orianna-sig-guard] ERROR: Orianna signing commit must touch exactly 1 file; %d files staged\n' "$NUM_STAGED" >&2
  printf '  Staged files:\n' >&2
  printf '%s\n' "$STAGED_FILES" | head -10 >&2
  printf '  See §D1.2 of plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md\n' >&2
  exit 1
fi

STAGED_FILE="$(printf '%s\n' "$STAGED_FILES" | awk 'NR==1 {print $2}')"
case "$STAGED_FILE" in
  plans/*)
    ;;
  *)
    printf '[orianna-sig-guard] ERROR: Orianna signing commit must touch a file under plans/; got: %s\n' "$STAGED_FILE" >&2
    exit 1
    ;;
esac

# --- CHECK 2: diff adds exactly one orianna_signature_<phase> line (no other content change) ---
DIFF_OUTPUT="$(git diff --cached -- "$STAGED_FILE" 2>/dev/null)"

# Count added lines (starting with +, not ++)
ADDED_SIG_LINES="$(printf '%s\n' "$DIFF_OUTPUT" | grep -c '^+orianna_signature_' || echo 0)"
# Count any other added lines (not the +++ header, not blank +, not signature lines)
OTHER_ADDED="$(printf '%s\n' "$DIFF_OUTPUT" | grep '^+' | grep -v '^+++' | grep -v '^+orianna_signature_' | grep -v '^+[[:space:]]*$' || true)"

if [ "$ADDED_SIG_LINES" -ne 1 ]; then
  printf '[orianna-sig-guard] ERROR: Orianna signing commit must add exactly 1 orianna_signature_<phase> line; found %d\n' "$ADDED_SIG_LINES" >&2
  exit 1
fi

if [ -n "$OTHER_ADDED" ]; then
  printf '[orianna-sig-guard] ERROR: Orianna signing commit may only add the signature line; found other added content:\n' >&2
  printf '%s\n' "$OTHER_ADDED" | head -5 >&2
  exit 1
fi

# --- CHECK 3 & 4: trailers in COMMIT_EDITMSG ---
EDITMSG="$GIT_DIR/COMMIT_EDITMSG"
if [ ! -f "$EDITMSG" ]; then
  printf '[orianna-sig-guard] ERROR: COMMIT_EDITMSG not found at %s\n' "$EDITMSG" >&2
  exit 1
fi

COMMIT_MSG="$(cat "$EDITMSG")"

# Check Signed-by: Orianna
printf '%s\n' "$COMMIT_MSG" | grep -q "^Signed-by: Orianna" || {
  printf '[orianna-sig-guard] ERROR: missing "Signed-by: Orianna" trailer in commit message\n' >&2
  exit 1
}

# Check Signed-phase: <phase>
SIGNED_PHASE="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-phase:/{sub(/^Signed-phase:[[:space:]]*/, ""); print; exit}')"
[ -n "$SIGNED_PHASE" ] || {
  printf '[orianna-sig-guard] ERROR: missing "Signed-phase: <phase>" trailer in commit message\n' >&2
  exit 1
}

# Check Signed-hash:
SIGNED_HASH="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-hash:/{sub(/^Signed-hash:[[:space:]]*/, ""); print; exit}')"
[ -n "$SIGNED_HASH" ] || {
  printf '[orianna-sig-guard] ERROR: missing "Signed-hash: sha256:<hash>" trailer in commit message\n' >&2
  exit 1
}

# CHECK 4: phase in Signed-phase trailer matches the signature line added
SIG_LINE_PHASE="$(printf '%s\n' "$DIFF_OUTPUT" | grep '^+orianna_signature_' | head -1 | awk '{sub(/^\+orianna_signature_/, ""); sub(/:.*/, ""); print}')"
if [ "$SIG_LINE_PHASE" != "$SIGNED_PHASE" ]; then
  printf '[orianna-sig-guard] ERROR: Signed-phase trailer "%s" does not match signature line phase "%s"\n' "$SIGNED_PHASE" "$SIG_LINE_PHASE" >&2
  exit 1
fi

exit 0
