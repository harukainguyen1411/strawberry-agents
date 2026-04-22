#!/bin/sh
# pre-commit-orianna-signature-guard.sh — Enforce Orianna signing commit shape.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D1.2, §D7.3, T2.3
# Plan: plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md T4 (shape B)
#
# When the commit author is Orianna's identity (orianna@agents.strawberry.local),
# enforce that the commit matches one of two signing shapes:
#
# Shape A (signature-only commit — original):
#   1. Diff touches exactly one file under plans/.
#   2. Diff adds exactly one orianna_signature_<phase> line (no other content change).
#   3. All three trailers present in COMMIT_EDITMSG: Signed-by: Orianna,
#      Signed-phase: <phase>, Signed-hash: sha256:<hash>.
#   4. The phase in Signed-phase and the added signature line name are consistent.
#
# Shape B (atomic body + signature commit — Signed-Fix):
#   Activated when COMMIT_EDITMSG carries a "Signed-Fix: <phase>" trailer.
#   1. Diff touches exactly one file under plans/ (same one-file scope).
#   2. The staged blob body hash equals the hash embedded in the new
#      orianna_signature_<phase> line. (Body edits from pre-fix must be
#      included in the same commit — post-rewrite hash, not pre-rewrite.)
#   3. All three trailers present: Signed-by: Orianna, Signed-phase: <phase>,
#      Signed-hash: sha256:<hash>.
#   4. Signed-Fix phase must match Signed-phase.
#   NOTE: shape B does NOT enforce the "no other content added" rule — the
#   body edits from the pre-fix pass are the reason shape B exists.
#
# Commits by other authors pass through unconditionally.
#
# Reads COMMIT_EDITMSG via GIT_DIR (set by git), or falls back to
# .git/COMMIT_EDITMSG relative to GIT_WORK_TREE.
#
# Error output: written to $GIT_DIR/orianna-sig-guard.log (not to stderr).
# This ensures test harnesses running the hook in a command substitution with
# 2>&1 see only the clean exit-code digit from printf. Callers should inspect
# the log on non-zero exit. The log is truncated at each invocation.

set -eu

ORIANNA_EMAIL="orianna@agents.strawberry.local"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HASH_BODY="$REPO_ROOT/scripts/orianna-hash-body.sh"

# Determine git context
GIT_DIR="${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}"
GIT_WORK_TREE="${GIT_WORK_TREE:-$(git rev-parse --show-toplevel 2>/dev/null)}"

# Log sink for guard errors. In interactive sessions (TTY stderr) we tee to
# both the log and the terminal so errors are visible. In non-interactive
# harnesses (no TTY, e.g. command substitution) we capture to the log only.
# Plan: plans/in-progress/personal/2026-04-22-orianna-speedups-pr19-fast-follow.md T3 (F1)
_GUARD_LOG="$GIT_DIR/orianna-sig-guard.log"
: > "$_GUARD_LOG" 2>/dev/null || _GUARD_LOG="${TMPDIR:-/tmp}/orianna-sig-guard-$$.log"
if [ ! -t 2 ]; then
  exec 2>>"$_GUARD_LOG"
fi

# err: write a message to stderr (interactive: visible on terminal) AND to the
# log file (always, for post-mortem inspection).
err() {
  printf '[orianna-sig-guard] %s\n' "$*" >&2
  printf '[orianna-sig-guard] %s\n' "$*" >> "$_GUARD_LOG" 2>/dev/null || true
}

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
NUM_STAGED="$(printf '%s\n' "$STAGED_FILES" | grep -c '^[AMDRC]' || true)"
NUM_STAGED="${NUM_STAGED:-0}"

if [ "$NUM_STAGED" -ne 1 ]; then
  err "ERROR: Orianna signing commit must touch exactly 1 file; $NUM_STAGED files staged"
  err "  Staged files:"
  printf '%s\n' "$STAGED_FILES" | head -10 >&2
  err "  See §D1.2 of plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md"
  exit 1
fi

STAGED_FILE="$(printf '%s\n' "$STAGED_FILES" | awk 'NR==1 {print $2}')"
case "$STAGED_FILE" in
  plans/*)
    ;;
  *)
    err "ERROR: Orianna signing commit must touch a file under plans/; got: $STAGED_FILE"
    exit 1
    ;;
esac

DIFF_OUTPUT="$(git diff --cached -- "$STAGED_FILE" 2>/dev/null)"

# --- CHECK 3: trailers in COMMIT_EDITMSG (read early — needed for shape detection) ---
EDITMSG="$GIT_DIR/COMMIT_EDITMSG"
if [ ! -f "$EDITMSG" ]; then
  err "ERROR: COMMIT_EDITMSG not found at $EDITMSG"
  exit 1
fi

COMMIT_MSG="$(cat "$EDITMSG")"

# Detect shape B: Signed-Fix: <phase> trailer present
SIGNED_FIX_PHASE="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-Fix:/{sub(/^Signed-Fix:[[:space:]]*/, ""); print; exit}')"

if [ -n "$SIGNED_FIX_PHASE" ]; then
  # ===== SHAPE B — atomic body + signature commit =====

  # Check Signed-by: Orianna
  if ! printf '%s\n' "$COMMIT_MSG" | grep -q "^Signed-by: Orianna"; then
    err 'ERROR: missing "Signed-by: Orianna" trailer in shape B commit'
    exit 1
  fi

  # Check Signed-phase: <phase>
  SIGNED_PHASE="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-phase:/{sub(/^Signed-phase:[[:space:]]*/, ""); print; exit}')"
  if [ -z "$SIGNED_PHASE" ]; then
    err 'ERROR: missing "Signed-phase: <phase>" trailer in shape B commit'
    exit 1
  fi

  # Check Signed-hash:
  SIGNED_HASH="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-hash:/{sub(/^Signed-hash:[[:space:]]*/, ""); print; exit}')"
  if [ -z "$SIGNED_HASH" ]; then
    err 'ERROR: missing "Signed-hash: sha256:<hash>" trailer in shape B commit'
    exit 1
  fi

  # Signed-Fix phase must match Signed-phase
  if [ "$SIGNED_FIX_PHASE" != "$SIGNED_PHASE" ]; then
    err "ERROR: Signed-Fix phase \"$SIGNED_FIX_PHASE\" does not match Signed-phase \"$SIGNED_PHASE\""
    exit 1
  fi

  # Verify exactly one signature line added
  ADDED_SIG_LINES="$(printf '%s\n' "$DIFF_OUTPUT" | grep -c '^+orianna_signature_' || true)"
  ADDED_SIG_LINES="${ADDED_SIG_LINES:-0}"
  if [ "$ADDED_SIG_LINES" -ne 1 ]; then
    err "ERROR: shape B commit must add exactly 1 orianna_signature_<phase> line; found $ADDED_SIG_LINES"
    exit 1
  fi

  # Extract the hash embedded in the new signature line from the diff
  NEW_SIG_LINE="$(printf '%s\n' "$DIFF_OUTPUT" | grep '^+orianna_signature_' | head -1 | sed 's/^+//')"
  EMBEDDED_HASH="$(printf '%s\n' "$NEW_SIG_LINE" | sed 's/.*"sha256:\([^:]*\):.*/\1/')"

  if [ -z "$EMBEDDED_HASH" ]; then
    err "ERROR: could not parse hash from new signature line in diff"
    exit 1
  fi

  # Compute the body hash of the staged blob (post-rewrite state per T3/T4 contract)
  if [ ! -f "$HASH_BODY" ]; then
    err "ERROR: orianna-hash-body.sh not found at $HASH_BODY"
    exit 1
  fi

  STAGED_TMP="$(mktemp /tmp/sig-guard-staged-XXXXXX.md)"
  if ! git show ":$STAGED_FILE" > "$STAGED_TMP" 2>/dev/null; then
    rm -f "$STAGED_TMP"
    err "ERROR: could not read staged blob for $STAGED_FILE"
    exit 1
  fi

  ACTUAL_HASH="$(bash "$HASH_BODY" "$STAGED_TMP" 2>/dev/null || echo "")"
  rm -f "$STAGED_TMP"

  if [ -z "$ACTUAL_HASH" ]; then
    err "ERROR: could not compute hash of staged blob"
    exit 1
  fi

  if [ "$EMBEDDED_HASH" != "$ACTUAL_HASH" ]; then
    err "ERROR: shape B body-hash mismatch"
    err "  Embedded hash in signature: $EMBEDDED_HASH"
    err "  Actual staged blob hash:    $ACTUAL_HASH"
    err "  The signature hash must match the staged blob body hash (post-rewrite state)."
    exit 1
  fi

  # Check that the signature line phase matches Signed-Fix/Signed-phase
  SIG_LINE_PHASE="$(printf '%s\n' "$DIFF_OUTPUT" | grep '^+orianna_signature_' | head -1 | awk '{sub(/^\+orianna_signature_/, ""); sub(/:.*/, ""); print}')"
  if [ "$SIG_LINE_PHASE" != "$SIGNED_PHASE" ]; then
    err "ERROR: Signed-phase trailer \"$SIGNED_PHASE\" does not match signature line phase \"$SIG_LINE_PHASE\""
    exit 1
  fi

  exit 0
fi

# ===== SHAPE A — signature-only commit (original shape) =====

# --- CHECK 2: diff adds exactly one orianna_signature_<phase> line (no other content change) ---

# Count added lines (starting with +, not ++)
ADDED_SIG_LINES="$(printf '%s\n' "$DIFF_OUTPUT" | grep -c '^+orianna_signature_' || true)"
ADDED_SIG_LINES="${ADDED_SIG_LINES:-0}"
# Count any other added lines (not the +++ header, not blank +, not signature lines)
OTHER_ADDED="$(printf '%s\n' "$DIFF_OUTPUT" | grep '^+' | grep -v '^+++' | grep -v '^+orianna_signature_' | grep -v '^+[[:space:]]*$' || true)"

if [ "$ADDED_SIG_LINES" -ne 1 ]; then
  err "ERROR: Orianna signing commit must add exactly 1 orianna_signature_<phase> line; found $ADDED_SIG_LINES"
  exit 1
fi

if [ -n "$OTHER_ADDED" ]; then
  err "ERROR: Orianna signing commit may only add the signature line; found other added content:"
  printf '%s\n' "$OTHER_ADDED" | head -5 >&2
  exit 1
fi

# --- CHECK 3 & 4: trailers in COMMIT_EDITMSG ---

# Check Signed-by: Orianna
if ! printf '%s\n' "$COMMIT_MSG" | grep -q "^Signed-by: Orianna"; then
  err 'ERROR: missing "Signed-by: Orianna" trailer in commit message'
  exit 1
fi

# Check Signed-phase: <phase>
SIGNED_PHASE="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-phase:/{sub(/^Signed-phase:[[:space:]]*/, ""); print; exit}')"
if [ -z "$SIGNED_PHASE" ]; then
  err 'ERROR: missing "Signed-phase: <phase>" trailer in commit message'
  exit 1
fi

# Check Signed-hash:
SIGNED_HASH="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-hash:/{sub(/^Signed-hash:[[:space:]]*/, ""); print; exit}')"
if [ -z "$SIGNED_HASH" ]; then
  err 'ERROR: missing "Signed-hash: sha256:<hash>" trailer in commit message'
  exit 1
fi

# CHECK 4: phase in Signed-phase trailer matches the signature line added
SIG_LINE_PHASE="$(printf '%s\n' "$DIFF_OUTPUT" | grep '^+orianna_signature_' | head -1 | awk '{sub(/^\+orianna_signature_/, ""); sub(/:.*/, ""); print}')"
if [ "$SIG_LINE_PHASE" != "$SIGNED_PHASE" ]; then
  err "ERROR: Signed-phase trailer \"$SIGNED_PHASE\" does not match signature line phase \"$SIG_LINE_PHASE\""
  exit 1
fi

exit 0
