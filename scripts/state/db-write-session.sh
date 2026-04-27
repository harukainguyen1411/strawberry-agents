#!/usr/bin/env bash
# scripts/state/db-write-session.sh — write a sessions row to the state DB
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D3 §T6b
#
# Usage: db-write-session.sh <db_path> <id> <coordinator> <started_at> <ended_at> <shard_path> [tldr] [branch]
#
# Idempotent: INSERT OR IGNORE on PRIMARY KEY (id).
# Non-fatal: all failure paths exit 0; systemic failures appended to
#   ~/.strawberry-state/db-write-failures.log for boot-time health inspection.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DB="$SCRIPT_DIR/_lib_db.sh"
FAILURE_LOG="${STRAWBERRY_STATE_DB_FAILURES:-${HOME}/.strawberry-state/db-write-failures.log}"

_log_failure() {
    local script="$1" rc="$2" detail="$3"
    mkdir -p "$(dirname "$FAILURE_LOG")" 2>/dev/null || true
    printf '%s db-write-session rc=%d %s: %s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)" \
        "$rc" "$script" "$detail" >> "$FAILURE_LOG" 2>/dev/null || true
    printf '[db-write-session] SYSTEMIC: DB write failed (rc=%d) — logged to %s\n' "$rc" "$FAILURE_LOG" >&2
}

if [ ! -f "$LIB_DB" ]; then
    printf '[db-write-session] WARNING: _lib_db.sh not found at %s — skipping DB write\n' "$LIB_DB" >&2
    exit 0
fi
# shellcheck source=/dev/null
. "$LIB_DB"

DB_PATH="${1:-}"
ID="${2:-}"
COORDINATOR="${3:-}"
STARTED_AT="${4:-}"
ENDED_AT="${5:-}"
SHARD_PATH="${6:-}"
TLDR="${7:-}"
BRANCH="${8:-}"

if [ -z "$DB_PATH" ] || [ -z "$ID" ] || [ -z "$COORDINATOR" ] || [ -z "$STARTED_AT" ] || [ -z "$SHARD_PATH" ]; then
    printf '[db-write-session] WARNING: required args missing — skipping DB write\n' >&2
    exit 0
fi

if [ ! -f "$DB_PATH" ] && [ ! -d "$(dirname "$DB_PATH")" ]; then
    printf '[db-write-session] WARNING: DB path not reachable: %s — skipping\n' "$DB_PATH" >&2
    exit 0
fi

# Escape single quotes in all string values (SQL injection prevention).
_esc() { printf '%s' "${1//\'/\'\'}"; }

SQL="INSERT OR IGNORE INTO sessions (id, coordinator, started_at, ended_at, shard_path, tldr, branch)
     VALUES (
       '$(_esc "$ID")',
       '$(_esc "$COORDINATOR")',
       strftime('%Y-%m-%d %H:%M:%f', '$(_esc "$STARTED_AT")'),
       nullif(strftime('%Y-%m-%d %H:%M:%f', '$(_esc "$ENDED_AT")'), strftime('%Y-%m-%d %H:%M:%f', '')),
       '$(_esc "$SHARD_PATH")',
       nullif('$(_esc "$TLDR")', ''),
       nullif('$(_esc "$BRANCH")', '')
     );"

# db_open is non-fatal: errors suppressed, failure logged but does not abort.
db_open "$DB_PATH" 2>/dev/null || {
    _log_failure "db_open" "$?" "db_path=$DB_PATH"
    exit 0
}

db_rc=0
db_write_tx "$DB_PATH" "$SQL" 2>/dev/null || db_rc=$?
if [ "$db_rc" -ne 0 ]; then
    if [ "$db_rc" -eq 5 ]; then
        printf '[db-write-session] WARNING: SQLITE_BUSY after retries — session close continues\n' >&2
    else
        _log_failure "db_write_tx" "$db_rc" "id=$ID coordinator=$COORDINATOR"
    fi
fi
exit 0
