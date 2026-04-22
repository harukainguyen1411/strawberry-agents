#!/bin/sh
# pre-commit-orianna-body-hash-guard.sh — Block commits that invalidate a plan's Orianna signature.
#
# Plan: plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md T2
#
# For every staged plan file (plans/**/*.md) that carries one or more
# orianna_signature_<phase> frontmatter fields, re-computes the body hash
# and compares it against the hash embedded in each signature value.
# Fails with a self-documenting runbook message if any hash mismatches.
#
# Bypass: if the commit message contains an "Orianna-Bypass: <reason>" trailer
# (admin-only, enforced by pre-commit-plan-promote-guard.sh), this guard exits 0.
#
# Does NOT run for non-Orianna authors modifying non-plan files — but it does
# run for ALL authors on plan files, because any author can break a signature.
#
# Usage: called automatically as part of the pre-commit dispatcher.
#
# Exit codes:
#   0 — all staged plan signatures still valid (or no signatures present)
#   1 — at least one body-hash mismatch detected; commit blocked

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HASH_BODY="$REPO_ROOT/scripts/orianna-hash-body.sh"

# Determine git context
GIT_DIR="${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}"
GIT_WORK_TREE="${GIT_WORK_TREE:-$(git rev-parse --show-toplevel 2>/dev/null)}"

# ---- Bypass check: Orianna-Bypass trailer in COMMIT_EDITMSG ---------------
EDITMSG="$GIT_DIR/COMMIT_EDITMSG"
if [ -f "$EDITMSG" ] && grep -q "^Orianna-Bypass:" "$EDITMSG" 2>/dev/null; then
  exit 0
fi

# ---- Require hash-body helper ---------------------------------------------
if [ ! -f "$HASH_BODY" ]; then
  printf '[body-hash-guard] WARNING: orianna-hash-body.sh not found — skipping body-hash check\n' >&2
  exit 0
fi

# ---- Collect staged plan files --------------------------------------------
STAGED_PLANS="$(git diff --cached --name-only 2>/dev/null | grep '^plans/.*\.md$' || true)"

if [ -z "$STAGED_PLANS" ]; then
  exit 0
fi

FAIL=0

# ---- For each staged plan, extract signature fields and verify hashes -----
for rel_path in $STAGED_PLANS; do
  abs_path="$GIT_WORK_TREE/$rel_path"

  # Extract staged blob content to a temp file for accurate post-edit hash
  STAGED_TMP="$(mktemp /tmp/body-hash-guard-XXXXXX.md)"
  # git show :path gives the staged blob content
  if ! git show ":$rel_path" > "$STAGED_TMP" 2>/dev/null; then
    # File may be newly added and not yet trackable this way — skip
    rm -f "$STAGED_TMP"
    continue
  fi

  # Extract orianna_signature_<phase> fields from the staged blob frontmatter
  # Format: orianna_signature_<phase>: "sha256:<hash>:<timestamp>"
  SIG_LINES="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if (dashes == 2) exit; next }
    dashes == 1 && /^orianna_signature_/ { print }
  ' "$STAGED_TMP")"

  if [ -z "$SIG_LINES" ]; then
    rm -f "$STAGED_TMP"
    continue
  fi

  # Compute actual body hash of the staged blob
  ACTUAL_HASH="$(bash "$HASH_BODY" "$STAGED_TMP" 2>/dev/null || echo "")"

  if [ -z "$ACTUAL_HASH" ]; then
    rm -f "$STAGED_TMP"
    printf '[body-hash-guard] WARNING: could not compute hash for %s — skipping\n' "$rel_path" >&2
    continue
  fi

  rm -f "$STAGED_TMP"

  # Check each signature field
  printf '%s\n' "$SIG_LINES" | while IFS= read -r sig_line; do
    # Parse: orianna_signature_<phase>: "sha256:<hash>:<ts>"
    phase="$(printf '%s\n' "$sig_line" | sed 's/^orianna_signature_\([^:]*\):.*/\1/')"
    # Extract hash portion: sha256:<64-hex>:<timestamp> → take the second colon-delimited field
    embedded_hash="$(printf '%s\n' "$sig_line" | sed 's/.*"sha256:\([^:]*\):.*/\1/')"

    if [ -z "$embedded_hash" ] || [ -z "$phase" ]; then
      continue
    fi

    if [ "$embedded_hash" != "$ACTUAL_HASH" ]; then
      printf '\n[body-hash-guard] ERROR: body-hash mismatch for plan: %s\n' "$rel_path" >&2
      printf '  Phase:         %s\n' "$phase" >&2
      printf '  Embedded hash: %s\n' "$embedded_hash" >&2
      printf '  Actual hash:   %s\n' "$ACTUAL_HASH" >&2
      printf '\n' >&2
      printf '  RECOVERY RUNBOOK:\n' >&2
      printf '  The plan body was edited after it was Orianna-signed. The signature is\n' >&2
      printf '  now invalid. You have two options:\n' >&2
      printf '\n' >&2
      printf '  Option A — Re-sign with Orianna (recommended):\n' >&2
      printf '    1. Remove the stale orianna_signature_%s field from frontmatter.\n' "$phase" >&2
      printf '    2. Move the plan back to the correct proposed/ or approved/ directory.\n' >&2
      printf '    3. Run: bash scripts/orianna-sign.sh <plan.md> %s\n' "$phase" >&2
      printf '\n' >&2
      printf '  Option B — Admin bypass (Duong only, harukainguyen1411 identity):\n' >&2
      printf '    Add an "Orianna-Bypass: <reason>" trailer to the commit message.\n' >&2
      printf '    This bypass is audited and blocked for agent identities.\n' >&2
      printf '\n' >&2
      printf '  Stale phase: %s  |  Mismatched body hash — orianna-bypass or re-sign required\n' "$phase" >&2
      # Signal failure by writing to a temp file (subshell cannot mutate parent FAIL)
      printf 'FAIL\n' >> /tmp/body-hash-guard-failures-$$.txt 2>/dev/null || true
    fi
  done
done

# Check if any failures were recorded (subshell cannot propagate variable)
if [ -f "/tmp/body-hash-guard-failures-$$.txt" ]; then
  rm -f "/tmp/body-hash-guard-failures-$$.txt"
  exit 1
fi

exit 0
