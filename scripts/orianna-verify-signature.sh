#!/bin/sh
# orianna-verify-signature.sh — Verify an Orianna signature on a plan file.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D7.2, §D6.2, T2.2
#
# Four checks (§D6.2):
#   1. Body-hash match — SHA-256 of current body matches hash stored in signature field.
#   2. Commit-author email — commit that introduced the signature line authored by
#      orianna@agents.strawberry.local.
#   3. All three trailers present and consistent — Signed-by: Orianna, Signed-phase:
#      <phase>, Signed-hash: sha256:<hash> (hash matches frontmatter field).
#   4. Single-file diff scope — signing commit touches only the plan file (§D1.2).
#
# Usage:
#   bash scripts/orianna-verify-signature.sh <plan.md> <phase>
#
# <phase> is one of: approved, in_progress, implemented
#
# Exit codes:
#   0 — signature present and valid
#   1 — signature invalid (see stderr for specific failure)
#   2 — usage/invocation error

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HASH_BODY="$SCRIPT_DIR/orianna-hash-body.sh"

ORIANNA_EMAIL="orianna@agents.strawberry.local"

die()    { printf '[orianna-verify] ERROR: %s\n' "$*" >&2; exit 2; }
fail()   { printf '[orianna-verify] INVALID: %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 <<EOF
Usage: $0 <plan.md> <phase>

Verify Orianna's signature for a plan at the given phase.
<phase> must be: approved, in_progress, or implemented

Exit codes: 0=valid, 1=invalid (with diagnosis), 2=usage error
EOF
  exit 2
}

[ $# -eq 2 ] || usage
PLAN="$1"
PHASE="$2"

case "$PLAN" in
  /*) ;;
  *)  PLAN="$(pwd)/$PLAN" ;;
esac

[ -f "$PLAN" ] || die "plan file not found: $PLAN"
[ -f "$HASH_BODY" ] || die "orianna-hash-body.sh not found: $HASH_BODY"

case "$PHASE" in
  approved|in_progress|implemented) ;;
  *) die "unknown phase '$PHASE': must be approved, in_progress, or implemented" ;;
esac

FIELD_NAME="orianna_signature_${PHASE}"

# --- CHECK 1: signature field present in frontmatter ---
# Extract the signature value from YAML frontmatter (between first two ---)
SIG_VALUE="$(awk '
  BEGIN { dashes=0 }
  /^---[[:space:]]*$/ { dashes++; if (dashes==2) exit; next }
  dashes==1 && /^'"$FIELD_NAME"':/ {
    val=$0
    sub(/^'"$FIELD_NAME"':[[:space:]]*/, "", val)
    # Strip surrounding quotes if present
    gsub(/^"|"$/, "", val)
    print val
  }
' "$PLAN")"

[ -n "$SIG_VALUE" ] || fail "signature field '$FIELD_NAME' not found in plan frontmatter"

# Extract hash and timestamp from signature value: sha256:<hash>:<iso-timestamp>
case "$SIG_VALUE" in
  sha256:*) ;;
  *) fail "signature value does not start with 'sha256:' (got: $SIG_VALUE)" ;;
esac

SIG_HASH="$(printf '%s\n' "$SIG_VALUE" | awk -F: '{print $2}')"
[ -n "$SIG_HASH" ] || fail "could not extract hash from signature value: $SIG_VALUE"

# --- CHECK 1 (continued): current body hash matches stored hash ---
CURRENT_HASH="$(bash "$HASH_BODY" "$PLAN")"
if [ "$CURRENT_HASH" != "$SIG_HASH" ]; then
  fail "body-hash mismatch: stored='$SIG_HASH' current='$CURRENT_HASH' (plan body was edited after signing)"
fi

# --- Locate the signing commit: find commit that introduced the signature line ---
# Use git log to walk commits modifying the plan and look for the one that added the field.
PLAN_REL="$(git -C "$(dirname "$PLAN")" rev-parse --show-toplevel 2>/dev/null | xargs -I{} sh -c 'printf "%s\n" "${1#"$2/"}"' _ "$PLAN" {})"
REPO_ROOT="$(git -C "$(dirname "$PLAN")" rev-parse --show-toplevel 2>/dev/null)" || die "plan is not in a git repository"

PLAN_REL="${PLAN#"$REPO_ROOT/"}"

SIGNING_COMMIT=""
# Walk git log for the plan file, find commit that first added our signature line
while IFS= read -r log_line; do
  commit_hash="${log_line%% *}"
  [ -n "$commit_hash" ] || continue
  # Check if this commit added the signature field
  if git -C "$REPO_ROOT" show "$commit_hash" -- "$PLAN_REL" 2>/dev/null | grep -q "^+${FIELD_NAME}:"; then
    SIGNING_COMMIT="$commit_hash"
    break
  fi
done <<EOF
$(git -C "$REPO_ROOT" log --follow --format='%H %ae' -- "$PLAN_REL" 2>/dev/null)
EOF

[ -n "$SIGNING_COMMIT" ] || fail "could not find commit that introduced '$FIELD_NAME' in git log for $PLAN_REL"

# --- CHECK 2: commit author email must be Orianna's identity ---
COMMIT_AUTHOR_EMAIL="$(git -C "$REPO_ROOT" log -1 --format='%ae' "$SIGNING_COMMIT" 2>/dev/null)"
if [ "$COMMIT_AUTHOR_EMAIL" != "$ORIANNA_EMAIL" ]; then
  fail "signing commit $SIGNING_COMMIT has wrong author email '$COMMIT_AUTHOR_EMAIL' (expected '$ORIANNA_EMAIL')"
fi

# --- CHECK 3: all three trailers present and consistent ---
COMMIT_MSG="$(git -C "$REPO_ROOT" log -1 --format='%B' "$SIGNING_COMMIT" 2>/dev/null)"

# Check Signed-by: Orianna
printf '%s\n' "$COMMIT_MSG" | grep -q "^Signed-by: Orianna" \
  || fail "signing commit $SIGNING_COMMIT missing 'Signed-by: Orianna' trailer"

# Check Signed-phase: <phase>
printf '%s\n' "$COMMIT_MSG" | grep -q "^Signed-phase: ${PHASE}" \
  || fail "signing commit $SIGNING_COMMIT missing or wrong 'Signed-phase: ${PHASE}' trailer"

# Check Signed-hash matches the hash in the frontmatter
TRAILER_HASH="$(printf '%s\n' "$COMMIT_MSG" | awk '/^Signed-hash:/{sub(/^Signed-hash:[[:space:]]*sha256:/, ""); sub(/^Signed-hash:[[:space:]]*/, ""); print; exit}')"
[ -n "$TRAILER_HASH" ] || fail "signing commit $SIGNING_COMMIT missing 'Signed-hash:' trailer"

# The trailer stores the full hash value (may include sha256: prefix)
TRAILER_HASH_BARE="${TRAILER_HASH#sha256:}"
if [ "$TRAILER_HASH_BARE" != "$SIG_HASH" ]; then
  fail "Signed-hash trailer '$TRAILER_HASH_BARE' does not match frontmatter hash '$SIG_HASH'"
fi

# --- CHECK 4: signing commit diff scoped to exactly one file (the plan) ---
NUM_FILES="$(git -C "$REPO_ROOT" diff-tree --no-commit-id -r --name-only "$SIGNING_COMMIT" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$NUM_FILES" -ne 1 ]; then
  fail "signing commit $SIGNING_COMMIT touches $NUM_FILES files (must touch exactly 1 — the plan file); §D1.2 single-file diff scope violated"
fi

CHANGED_FILE="$(git -C "$REPO_ROOT" diff-tree --no-commit-id -r --name-only "$SIGNING_COMMIT" 2>/dev/null)"
if [ "$CHANGED_FILE" != "$PLAN_REL" ]; then
  fail "signing commit $SIGNING_COMMIT touches '$CHANGED_FILE' but expected '$PLAN_REL'"
fi

# --- All checks passed ---
printf '[orianna-verify] OK: %s signature for %s is valid (hash=%s commit=%s)\n' \
  "$PHASE" "$PLAN_REL" "$SIG_HASH" "$SIGNING_COMMIT" >&2
exit 0
