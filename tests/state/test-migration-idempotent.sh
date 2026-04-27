#!/usr/bin/env bash
# T3a surface extension — coord-memory-v1 ADR (complex track, Rakan)
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T3a
# Rationale: Senna review of PR #96 found that 0001-init.sql uses bare CREATE TABLE
#   (no IF NOT EXISTS guards), so naive re-application errors with "table already exists".
#   The helper library's db_apply_migrations function must track applied migrations via
#   a schema_migrations table and skip already-applied files on subsequent calls.
#
# Invariants under test:
#   1. db_apply_migrations on a fresh DB applies 0001-init.sql cleanly (exit 0)
#   2. db_apply_migrations called a second time on the SAME DB does NOT error
#   3. schema_migrations table exists after first run
#   4. schema_migrations has exactly ONE row per migration file after two runs
#      (idempotency: no duplicate rows inserted on re-run)
#
# This test is expected RED until T3b lands _lib_db.sh with db_apply_migrations.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_DB="$REPO_ROOT/scripts/state/_lib_db.sh"
MIGRATIONS_DIR="$REPO_ROOT/agents/_state/migrations"

# ── xfail anchor ─────────────────────────────────────────────────────────────
if [ ! -f "$LIB_DB" ]; then
  echo "XFAIL: _lib_db.sh not present at $LIB_DB"
  echo "This test is expected RED until T3b lands the helper library with db_apply_migrations."
  exit 1
fi

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "XFAIL: migrations directory not present at $MIGRATIONS_DIR"
  exit 1
fi

MIGRATION_COUNT=$(find "$MIGRATIONS_DIR" -maxdepth 1 -name '*.sql' | wc -l | tr -d ' ')
if [ "$MIGRATION_COUNT" -eq 0 ]; then
  echo "XFAIL: no .sql files found in $MIGRATIONS_DIR"
  exit 1
fi

# shellcheck source=/dev/null
. "$LIB_DB"

# Verify db_apply_migrations is defined by the library.
if ! declare -f db_apply_migrations > /dev/null 2>&1; then
  echo "XFAIL: db_apply_migrations function not defined in $LIB_DB"
  echo "Viktor's T3b implementation must expose this function."
  exit 1
fi

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

DB_DIR=$(mktemp -d /tmp/test-migration-idempotent-XXXXXX)
DB_PATH="$DB_DIR/state.db"

cleanup() { rm -rf "$DB_DIR"; }
trap cleanup EXIT

echo "=== T3a-ext: migration idempotency (schema_migrations) ==="
echo "Migration count in $MIGRATIONS_DIR: $MIGRATION_COUNT"
echo ""

# ── §1: First run — fresh DB ─────────────────────────────────────────────────
echo "§1 First call to db_apply_migrations on a fresh DB"
db_open "$DB_PATH"
if db_apply_migrations "$DB_PATH" "$MIGRATIONS_DIR" 2>/dev/null; then
  pass "first db_apply_migrations call exited 0"
else
  fail "first db_apply_migrations call failed (exit non-zero)"
fi

# ── §2: schema_migrations table exists ──────────────────────────────────────
echo ""
echo "§2 schema_migrations table exists after first run"
SM_EXISTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='schema_migrations';")
if [ "$SM_EXISTS" -eq 1 ]; then
  pass "schema_migrations table exists"
else
  fail "schema_migrations table missing — db_apply_migrations must create it"
fi

# ── §3: Row count after first run = number of migration files ────────────────
echo ""
echo "§3 schema_migrations row count matches migration file count after first run"
ROWS_AFTER_FIRST=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM schema_migrations;" 2>/dev/null || echo 0)
if [ "$ROWS_AFTER_FIRST" -eq "$MIGRATION_COUNT" ]; then
  pass "schema_migrations has $ROWS_AFTER_FIRST row(s) = $MIGRATION_COUNT migration file(s)"
else
  fail "schema_migrations has $ROWS_AFTER_FIRST row(s), want $MIGRATION_COUNT"
fi

# ── §4: Second run — same DB — must not error ────────────────────────────────
echo ""
echo "§4 Second call to db_apply_migrations on the same DB (idempotency)"
if db_apply_migrations "$DB_PATH" "$MIGRATIONS_DIR" 2>/dev/null; then
  pass "second db_apply_migrations call exited 0 (no error on re-run)"
else
  fail "second db_apply_migrations call failed — 'table already exists' or similar regression"
fi

# ── §5: Row count after second run = same as after first run ─────────────────
echo ""
echo "§5 schema_migrations row count unchanged after second run"
ROWS_AFTER_SECOND=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM schema_migrations;" 2>/dev/null || echo 0)
if [ "$ROWS_AFTER_SECOND" -eq "$MIGRATION_COUNT" ]; then
  pass "schema_migrations still has $ROWS_AFTER_SECOND row(s) — no duplicates inserted"
else
  fail "schema_migrations has $ROWS_AFTER_SECOND row(s) after second run, want $MIGRATION_COUNT (duplicate insert?)"
fi

# ── §6: D3 application tables still intact after double migration ────────────
echo ""
echo "§6 Application tables intact after double migration run"
ALL_TABLES=(open_threads decisions sessions learnings plans_index projects_index prs_index inbox_index feedback_index refresh_log)
for table in "${ALL_TABLES[@]}"; do
  count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table';")
  if [ "$count" -eq 1 ]; then
    pass "table '$table' intact"
  else
    fail "table '$table' missing after double migration"
  fi
done

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
