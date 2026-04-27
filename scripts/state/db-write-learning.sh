#!/usr/bin/env bash
# scripts/state/db-write-learning.sh — write a learnings row to the state DB
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D3 §T6b
#
# Usage: db-write-learning.sh <db_path> <agent> <coordinator> <learned_at> <slug> <path> [topic]
#
# Idempotent: INSERT OR IGNORE on UNIQUE(agent, slug, learned_at).
# Non-fatal: all failure paths exit 0; systemic failures appended to
#   ~/.strawberry-state/db-write-failures.log for boot-time health inspection.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DB="$SCRIPT_DIR/_lib_db.sh"
FAILURE_LOG="${STRAWBERRY_STATE_DB_FAILURES:-${HOME}/.strawberry-state/db-write-failures.log}"

_log_failure() {
    local rc="$1" detail="$2"
    mkdir -p "$(dirname "$FAILURE_LOG")" 2>/dev/null || true
    printf '%s db-write-learning rc=%d %s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)" \
        "$rc" "$detail" >> "$FAILURE_LOG" 2>/dev/null || true
    printf '[db-write-learning] SYSTEMIC: DB write failed (rc=%d) — logged to %s\n' "$rc" "$FAILURE_LOG" >&2
}

if [ ! -f "$LIB_DB" ]; then
    printf '[db-write-learning] WARNING: _lib_db.sh not found at %s — skipping DB write\n' "$LIB_DB" >&2
    exit 0
fi
# shellcheck source=/dev/null
. "$LIB_DB"

DB_PATH="${1:-}"
AGENT="${2:-}"
COORDINATOR="${3:-}"
LEARNED_AT="${4:-}"
SLUG="${5:-}"
LEARNING_PATH="${6:-}"
TOPIC="${7:-}"

if [ -z "$DB_PATH" ] || [ -z "$AGENT" ] || [ -z "$COORDINATOR" ] || [ -z "$LEARNED_AT" ] || [ -z "$SLUG" ] || [ -z "$LEARNING_PATH" ]; then
    printf '[db-write-learning] WARNING: required args missing — skipping DB write\n' >&2
    exit 0
fi

if [ ! -f "$DB_PATH" ] && [ ! -d "$(dirname "$DB_PATH")" ]; then
    printf '[db-write-learning] WARNING: DB path not reachable: %s — skipping\n' "$DB_PATH" >&2
    exit 0
fi

# Escape single quotes in all string values (SQL injection prevention).
_esc() { printf '%s' "${1//\'/\'\'}"; }

SQL="INSERT OR IGNORE INTO learnings (agent, coordinator, learned_at, slug, path, topic)
     VALUES (
       '$(_esc "$AGENT")',
       '$(_esc "$COORDINATOR")',
       '$(_esc "$LEARNED_AT")',
       '$(_esc "$SLUG")',
       '$(_esc "$LEARNING_PATH")',
       nullif('$(_esc "$TOPIC")', '')
     );"

# db_open is non-fatal: errors suppressed, failure logged but does not abort.
db_open "$DB_PATH" 2>/dev/null || {
    _log_failure "$?" "db_path=$DB_PATH"
    exit 0
}

db_rc=0
db_write_tx "$DB_PATH" "$SQL" 2>/dev/null || db_rc=$?
if [ "$db_rc" -ne 0 ]; then
    if [ "$db_rc" -eq 5 ]; then
        printf '[db-write-learning] WARNING: SQLITE_BUSY after retries — subagent close continues\n' >&2
    else
        _log_failure "$db_rc" "agent=$AGENT slug=$SLUG"
    fi
fi
exit 0
