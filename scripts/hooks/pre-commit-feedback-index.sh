#!/usr/bin/env bash
# scripts/hooks/pre-commit-feedback-index.sh
#
# Pre-commit hook: regenerates feedback/INDEX.md when any feedback/*.md
# file is staged, and validates §D1 schema for all staged feedback files.
#
# Per §D6 of plans/approved/personal/2026-04-21-agent-feedback-system.md:
#   1. Detects if any staged diff file matches ^feedback/[^/]+\.md$
#   2. Validates all staged feedback/*.md files against §D1 schema
#   3. Regenerates feedback/INDEX.md and stages it in the same commit
#
# Exit codes:
#   0  ok — allow commit
#   1  schema validation failure or INDEX regeneration failure — block commit
#
# Bypass: FEEDBACK_TEST_MODE=1 skips git add of INDEX (for in-process test
#         isolation where git operations may be unsafe)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'pre-commit-feedback-index: ERROR: not inside a git repository\n' >&2
  exit 1
}

# Locate the feedback-index.sh script.
# Primary:  $REPO_ROOT/scripts/feedback-index.sh
# Fallback: $REPO_ROOT/scripts-feedback-index.sh  (test isolation copy)
if [ -f "$REPO_ROOT/scripts/feedback-index.sh" ]; then
  INDEX_SCRIPT="$REPO_ROOT/scripts/feedback-index.sh"
elif [ -f "$REPO_ROOT/scripts-feedback-index.sh" ]; then
  INDEX_SCRIPT="$REPO_ROOT/scripts-feedback-index.sh"
else
  printf 'pre-commit-feedback-index: ERROR: scripts/feedback-index.sh not found\n' >&2
  printf '  Expected at: %s/scripts/feedback-index.sh\n' "$REPO_ROOT" >&2
  exit 1
fi

FEEDBACK_DIR="$REPO_ROOT/feedback"

# ---------------------------------------------------------------------------
# 1. Detect staged feedback files
# ---------------------------------------------------------------------------

staged_feedback_files="$(git diff --cached --name-only 2>/dev/null | grep -E '^feedback/[^/]+\.md$' || true)"

if [ -z "$staged_feedback_files" ]; then
  # No feedback files staged — nothing to do
  exit 0
fi

# I2 guard: if only feedback/INDEX.md is staged (no source feedback file),
# the user is likely trying to commit a hand-edit of the generated file.
# Abort with a clear message rather than silently overwriting the staged edit.
staged_source_files="$(printf '%s\n' "$staged_feedback_files" | grep -v '^feedback/INDEX\.md$' || true)"
if [ -z "$staged_source_files" ]; then
  printf 'pre-commit-feedback-index: ERROR: feedback/INDEX.md is generated — do not hand-edit or commit it directly.\n' >&2
  printf '  Stage the source feedback file (feedback/YYYY-MM-DD-*.md) instead; the hook will regenerate INDEX.md automatically.\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Validate all staged feedback/*.md files against §D1 schema
# ---------------------------------------------------------------------------

validation_failed=0
for staged_file in $staged_feedback_files; do
  [ "$staged_file" = "feedback/INDEX.md" ] && continue
  full_path="$REPO_ROOT/$staged_file"
  # Only validate if the file still exists (not a deletion)
  if [ ! -f "$full_path" ]; then
    continue
  fi
  if ! bash "$INDEX_SCRIPT" --check "$full_path"; then
    printf 'pre-commit-feedback-index: §D1 schema validation failed for: %s\n' "$staged_file" >&2
    printf '  See plans/approved/personal/2026-04-21-agent-feedback-system.md §D1 for schema.\n' >&2
    validation_failed=1
  fi
done

if [ "$validation_failed" -ne 0 ]; then
  printf 'pre-commit-feedback-index: commit blocked — fix schema errors above and retry.\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Regenerate feedback/INDEX.md and stage it
# ---------------------------------------------------------------------------

if [ ! -d "$FEEDBACK_DIR" ]; then
  printf 'pre-commit-feedback-index: WARNING: feedback/ directory not found at %s\n' "$FEEDBACK_DIR" >&2
  exit 0
fi

INDEX_FILE="$FEEDBACK_DIR/INDEX.md"

# Generate the index
if ! bash "$INDEX_SCRIPT" --dir "$FEEDBACK_DIR" --out "$INDEX_FILE"; then
  printf 'pre-commit-feedback-index: ERROR: failed to regenerate feedback/INDEX.md\n' >&2
  exit 1
fi

# Stage the regenerated INDEX (unless in test mode)
if [ "${FEEDBACK_TEST_MODE:-0}" != "1" ]; then
  git add "$INDEX_FILE" 2>/dev/null || {
    printf 'pre-commit-feedback-index: WARNING: could not stage feedback/INDEX.md\n' >&2
  }
fi

exit 0
