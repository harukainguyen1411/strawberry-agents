#!/usr/bin/env bash
# T2a xfail — coord-memory-v1 ADR
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md
# This test will turn green when T2b lands the migration SQL.
#
# Coverage:
#   1. Apply on fresh DB — create temp DB, apply 0001-init.sql, assert all 10 D3 tables exist.
#   2. Coordinator column present — assert authored tables have coordinator TEXT NOT NULL.
#   3. Rollback — DROP all tables, assert clean state.
#   4. Replay clean — apply 0001-init.sql again post-rollback, assert tables return.

set -euo pipefail

MIGRATION_FILE="$(cd "$(dirname "$0")/../.." && pwd)/agents/_state/migrations/0001-init.sql"
DB_DIR="/tmp/test-migration-$$"
DB_PATH="$DB_DIR/state.db"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cleanup() {
  rm -rf "$DB_DIR"
}
trap cleanup EXIT

echo "=== T2a: schema migration xfail test ==="
echo ""

# ── preflight: migration file must exist (xfail anchor) ──────────────────────
if [ ! -f "$MIGRATION_FILE" ]; then
  echo "XFAIL: migration file not present: $MIGRATION_FILE"
  echo "This test is expected to be red until T2b lands 0001-init.sql."
  exit 1
fi

mkdir -p "$DB_DIR"

# ── §1: Apply on fresh DB ─────────────────────────────────────────────────────
echo "§1 Apply on fresh DB"

sqlite3 "$DB_PATH" < "$MIGRATION_FILE"

ALL_TABLES=(
  open_threads
  decisions
  sessions
  learnings
  plans_index
  projects_index
  prs_index
  inbox_index
  feedback_index
  refresh_log
)

for table in "${ALL_TABLES[@]}"; do
  count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table';")
  if [ "$count" -eq 1 ]; then
    pass "table '$table' exists"
  else
    fail "table '$table' missing"
  fi
done

# ── §2: Coordinator column present on authored tables ─────────────────────────
echo ""
echo "§2 Coordinator column on authored tables"

AUTHORED_TABLES=(open_threads decisions sessions learnings)

for table in "${AUTHORED_TABLES[@]}"; do
  # pragma table_info returns: cid|name|type|notnull|dflt_value|pk
  col_info=$(sqlite3 "$DB_PATH" "PRAGMA table_info($table);" | awk -F'|' '$2=="coordinator"{print $3"|"$4}')
  if [ -z "$col_info" ]; then
    fail "'$table'.coordinator column missing"
    continue
  fi
  col_type=$(echo "$col_info" | cut -d'|' -f1)
  col_notnull=$(echo "$col_info" | cut -d'|' -f2)
  if echo "$col_type" | grep -qi "TEXT"; then
    pass "'$table'.coordinator is TEXT"
  else
    fail "'$table'.coordinator type is '$col_type', want TEXT"
  fi
  if [ "$col_notnull" = "1" ]; then
    pass "'$table'.coordinator is NOT NULL"
  else
    fail "'$table'.coordinator is nullable (want NOT NULL)"
  fi
done

# ── §3: Rollback — DROP all tables, assert clean ──────────────────────────────
echo ""
echo "§3 Rollback via DROP"

for table in "${ALL_TABLES[@]}"; do
  sqlite3 "$DB_PATH" "DROP TABLE IF EXISTS $table;"
done

remaining=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
if [ "$remaining" -eq 0 ]; then
  pass "all tables dropped — clean state"
else
  fail "expected 0 tables after DROP, got $remaining"
fi

# ── §4: Replay clean ──────────────────────────────────────────────────────────
echo ""
echo "§4 Replay clean — re-apply after rollback"

sqlite3 "$DB_PATH" < "$MIGRATION_FILE"

for table in "${ALL_TABLES[@]}"; do
  count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table';")
  if [ "$count" -eq 1 ]; then
    pass "table '$table' back after replay"
  else
    fail "table '$table' missing after replay"
  fi
done

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
