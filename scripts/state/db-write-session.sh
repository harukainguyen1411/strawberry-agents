#!/usr/bin/env bash
# scripts/state/db-write-session.sh — write a sessions row to the state DB
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D3 §T6b
#
# Usage: db-write-session.sh <db_path> <id> <coordinator> <started_at> <ended_at> <shard_path> [tldr] [branch]
#
# Idempotent: INSERT OR IGNORE on PRIMARY KEY (id).
# Non-fatal: if STRAWBERRY_STATE_DB is unset and db_path arg is empty, exits 0 silently.
# Source: _lib_db.sh must be co-located in scripts/state/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DB="$SCRIPT_DIR/_lib_db.sh"

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

SQL="INSERT OR IGNORE INTO sessions (id, coordinator, started_at, ended_at, shard_path, tldr, branch)
     VALUES (
       '${ID}',
       '${COORDINATOR}',
       '${STARTED_AT}',
       nullif('${ENDED_AT}', ''),
       '${SHARD_PATH}',
       nullif('${TLDR}', ''),
       nullif('${BRANCH}', '')
     );"

db_open "$DB_PATH"
if ! db_write_tx "$DB_PATH" "$SQL"; then
    printf '[db-write-session] WARNING: DB write failed — session close continues\n' >&2
    exit 0
fi
