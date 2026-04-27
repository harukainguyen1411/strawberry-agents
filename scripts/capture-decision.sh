#!/usr/bin/env bash
# capture-decision.sh <coordinator> --file <path-to-prepared-log.md>
#
# Single entrypoint for writing one decision log file.
# Validates frontmatter, infers final path, writes file, git-adds it.
# Stdout: final path on success.
# Exit non-zero on failure with [capture-decision] BLOCK: on stderr.
#
# STRAWBERRY_MEMORY_ROOT env shim: when set, resolves coordinator memory base
# to $STRAWBERRY_MEMORY_ROOT/agents/<coordinator>/memory/ instead of the
# repo's agents/ tree. Used by integration tests (TT-INT, TT-INV).
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md §4.2
# POSIX-portable bash — runs on macOS and Git Bash on Windows (Rule 10)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/_lib_decision_capture.sh"

if [ ! -f "$LIB" ]; then
  printf '[capture-decision] BLOCK: library not found: %s\n' "$LIB" >&2
  exit 1
fi
# shellcheck source=scripts/_lib_decision_capture.sh
. "$LIB"

# Clean up decision-lib tmpfiles from the current PID on exit (belt-and-suspenders;
# lib already rm -f's at every return path, this guards abnormal exits).
trap 'rm -f "${TMPDIR:-/tmp}/decisions_"*"_$$" 2>/dev/null || true' EXIT INT TERM

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
COORDINATOR=""
FILE=""

if [ "$#" -lt 3 ]; then
  printf 'usage: capture-decision.sh <coordinator> --file <path>\n' >&2
  exit 1
fi

COORDINATOR="$1"
shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file)
      shift
      FILE="$1"
      shift
      ;;
    *)
      printf '[capture-decision] BLOCK: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$COORDINATOR" ]; then
  printf '[capture-decision] BLOCK: coordinator name required\n' >&2
  exit 1
fi

if [ -z "$FILE" ]; then
  printf '[capture-decision] BLOCK: --file <path> required\n' >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  printf '[capture-decision] BLOCK: file not found: %s\n' "$FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Resolve coordinator memory base
# ---------------------------------------------------------------------------
if [ -n "${STRAWBERRY_MEMORY_ROOT:-}" ]; then
  MEMORY_BASE="${STRAWBERRY_MEMORY_ROOT}/agents/${COORDINATOR}/memory"
  REPO_ROOT="${STRAWBERRY_MEMORY_ROOT}"
else
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  MEMORY_BASE="${REPO_ROOT}/agents/${COORDINATOR}/memory"
fi

LOG_DIR="${MEMORY_BASE}/decisions/log"

# ---------------------------------------------------------------------------
# No-orphan invariant: decisions/log/ must exist
# ---------------------------------------------------------------------------
if [ ! -d "$LOG_DIR" ]; then
  printf '[capture-decision] BLOCK: decisions/log/ does not exist for coordinator %s at %s\n' \
    "$COORDINATOR" "$LOG_DIR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Validate frontmatter
# ---------------------------------------------------------------------------
if ! validate_decision_frontmatter "$FILE"; then
  # validate_decision_frontmatter already wrote to stderr
  exit 1
fi

# ---------------------------------------------------------------------------
# Extract date and decision_id from frontmatter to build destination path
# ---------------------------------------------------------------------------
FRONTMATTER="$(
  in_fm=0
  while IFS= read -r line; do
    if [ "$in_fm" -eq 0 ] && [ "$line" = "---" ]; then
      in_fm=1
      continue
    fi
    if [ "$in_fm" -eq 1 ] && [ "$line" = "---" ]; then
      break
    fi
    if [ "$in_fm" -eq 1 ]; then
      printf '%s\n' "$line"
    fi
  done < "$FILE"
)"

DECISION_DATE="$(printf '%s' "$FRONTMATTER" | grep -E "^date:" | head -1 | sed 's/^date: *//')"
DECISION_ID="$(printf '%s' "$FRONTMATTER" | grep -E "^decision_id:" | head -1 | sed 's/^decision_id: *//')"

if [ -z "$DECISION_DATE" ] || [ -z "$DECISION_ID" ]; then
  printf '[capture-decision] BLOCK: cannot extract date or decision_id from frontmatter\n' >&2
  exit 1
fi

# Belt-and-suspenders path-traversal guard (I2): validate decision_id format here
# even though validate_decision_frontmatter already checks it. The lib may be called
# with DECISION_TEST_MODE or bypassed in future, so enforce at entrypoint too.
if ! printf '%s' "$DECISION_ID" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+$"; then
  printf '[capture-decision] BLOCK: decision_id (%s) is not a valid slug — must match YYYY-MM-DD-[a-z0-9-]+\n' "$DECISION_ID" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Compute destination path (collision-safe using decision_id as filename stem)
# ---------------------------------------------------------------------------
DEST="${LOG_DIR}/${DECISION_ID}.md"

# If file already exists with the same decision_id, use suffix loop
if [ -f "$DEST" ]; then
  n=2
  while [ -f "${LOG_DIR}/${DECISION_ID}-${n}.md" ]; do
    n=$((n + 1))
    if [ "$n" -gt 10 ]; then
      printf '[capture-decision] BLOCK: collision suffix exhausted for decision_id %s\n' "$DECISION_ID" >&2
      exit 1
    fi
  done
  DEST="${LOG_DIR}/${DECISION_ID}-${n}.md"
fi

# ---------------------------------------------------------------------------
# Write file to destination
# ---------------------------------------------------------------------------
cp "$FILE" "$DEST"

# ---------------------------------------------------------------------------
# git add the file (best-effort — may not be in a git repo in test mode)
# ---------------------------------------------------------------------------
if git -C "${REPO_ROOT}" add "$DEST" 2>/dev/null; then
  : # staged
fi

# ---------------------------------------------------------------------------
# DB write — projection into decisions table (non-fatal if DB unavailable)
# ---------------------------------------------------------------------------
if [ -n "${STRAWBERRY_STATE_DB:-}" ]; then
  DB_LIB="${SCRIPT_DIR}/state/_lib_db.sh"
  if [ -f "$DB_LIB" ]; then
    # shellcheck source=/dev/null
    . "$DB_LIB"
    # slug = decision_id with the leading YYYY-MM-DD- prefix stripped
    SLUG="$(printf '%s' "$DECISION_ID" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')"
    SQL="INSERT OR IGNORE INTO decisions (coordinator, decided_at, slug, shard_path, summary)
         VALUES (
           '${COORDINATOR}',
           '${DECISION_DATE}',
           '${SLUG}',
           '${DEST}',
           'captured via decision-capture skill'
         );"
    db_open "$STRAWBERRY_STATE_DB" 2>/dev/null || true
    db_write_tx "$STRAWBERRY_STATE_DB" "$SQL" 2>/dev/null || \
      printf '[capture-decision] WARNING: DB write failed — markdown shard is source of truth\n' >&2
  fi
fi

# ---------------------------------------------------------------------------
# Output final path
# ---------------------------------------------------------------------------
printf '%s\n' "$DEST"
