#!/usr/bin/env bash
# scripts/state/db-write-learning.sh — write a learnings row to the state DB
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D3 §T6b
#
# Usage: db-write-learning.sh <db_path> <agent> <coordinator> <learned_at> <slug> <path> [topic]
#
# Idempotent: INSERT OR IGNORE on UNIQUE(agent, slug, learned_at).
# Non-fatal: if db_path is unreachable, logs a warning and exits 0.
# Source: _lib_db.sh must be co-located in scripts/state/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DB="$SCRIPT_DIR/_lib_db.sh"

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

SQL="INSERT OR IGNORE INTO learnings (agent, coordinator, learned_at, slug, path, topic)
     VALUES (
       '${AGENT}',
       '${COORDINATOR}',
       '${LEARNED_AT}',
       '${SLUG}',
       '${LEARNING_PATH}',
       $([ -n "$TOPIC" ] && printf "'%s'" "$TOPIC" || printf 'NULL')
     );"

db_open "$DB_PATH"
if ! db_write_tx "$DB_PATH" "$SQL"; then
    printf '[db-write-learning] WARNING: DB write failed — subagent close continues\n' >&2
    exit 0
fi
