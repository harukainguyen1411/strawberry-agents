#!/usr/bin/env bash
# T7a xfail — coord-memory-v1 ADR
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md
# This test will turn green when T7b lands scripts/state/migrate-open-threads-notes.sh.
#
# Coverage:
#   §1  Migration script presence gate (xfail anchor — exits red if missing)
#   §2  Evelynn snapshot — every ## heading produces an open_threads row with source_ref set
#   §3  Sona snapshot — same assertion for Sona fixture
#   §4  No annotation text lost — aggregate body text in note column >= aggregate heading-body
#       text in the source fixture (lossy heading parse is flagged, not silently dropped)
#   §5  coordinator column set correctly per snapshot ('evelynn' vs 'sona')
#   §6  Idempotency — running migration twice produces the same row count (UNIQUE constraint)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATE_SCRIPT="$REPO_ROOT/scripts/state/migrate-open-threads-notes.sh"
LIB_DB="$REPO_ROOT/scripts/state/_lib_db.sh"
MIGRATIONS_DIR="$REPO_ROOT/agents/_state/migrations"
FIXTURES_DIR="$(dirname "$0")/fixtures"

EVELYNN_FIXTURE="$FIXTURES_DIR/open-threads-evelynn-snapshot.md"
SONA_FIXTURE="$FIXTURES_DIR/open-threads-sona-snapshot.md"

DB_DIR="/tmp/test-annotation-migration-$$"
DB_PATH="$DB_DIR/state.db"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cleanup() { rm -rf "$DB_DIR"; }
trap cleanup EXIT

echo "=== T7a: open-threads annotation migration xfail test ==="
echo ""

# ── §1: Migration script presence gate ───────────────────────────────────────
echo "§1 Migration script presence check"

if [ ! -f "$MIGRATE_SCRIPT" ]; then
  echo "XFAIL: migration script not present: $MIGRATE_SCRIPT"
  echo "This test is expected to be red until T7b lands migrate-open-threads-notes.sh."
  exit 1
fi

if [ ! -f "$LIB_DB" ]; then
  echo "XFAIL: _lib_db.sh not found: $LIB_DB"
  exit 1
fi

for fixture in "$EVELYNN_FIXTURE" "$SONA_FIXTURE"; do
  if [ ! -f "$fixture" ]; then
    echo "FAIL: fixture not found: $fixture"
    exit 1
  fi
done

pass "migrate-open-threads-notes.sh present"

# ── DB setup ──────────────────────────────────────────────────────────────────
mkdir -p "$DB_DIR"
# shellcheck source=/dev/null
. "$LIB_DB"
db_apply_migrations "$DB_PATH" "$MIGRATIONS_DIR"

# helper: count ## headings in a file (lines starting with exactly "## ")
count_headings() {
  grep -c '^## ' "$1" 2>/dev/null || echo 0
}

# helper: sum of character lengths of all body blocks (text between ## headings)
# Body = all lines between one ## heading and the next ## or EOF
aggregate_body_chars() {
  local file="$1"
  awk '/^## /{in_body=1; next} in_body{len+=length($0)} END{print len+0}' "$file"
}

# ── §2: Evelynn fixture ────────────────────────────────────────────────────────
echo ""
echo "§2 Evelynn fixture migration"

EVELYNN_HEADING_COUNT=$(count_headings "$EVELYNN_FIXTURE")
EVELYNN_BODY_CHARS=$(aggregate_body_chars "$EVELYNN_FIXTURE")

bash "$MIGRATE_SCRIPT" \
  --db "$DB_PATH" \
  --file "$EVELYNN_FIXTURE" \
  --coordinator "evelynn" 2>/dev/null

evelynn_rows=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn' AND note IS NOT NULL AND note != '';")

if [ "$evelynn_rows" -eq "$EVELYNN_HEADING_COUNT" ]; then
  pass "evelynn: $evelynn_rows rows == $EVELYNN_HEADING_COUNT headings"
else
  fail "evelynn: got $evelynn_rows rows, expected $EVELYNN_HEADING_COUNT headings"
fi

# Every row must have a source_ref set (non-empty)
evelynn_missing_ref=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn' AND (source_ref IS NULL OR source_ref='');")
if [ "$evelynn_missing_ref" -eq 0 ]; then
  pass "evelynn: all rows have source_ref set"
else
  fail "evelynn: $evelynn_missing_ref rows missing source_ref"
fi

# ── §3: Sona fixture ──────────────────────────────────────────────────────────
echo ""
echo "§3 Sona fixture migration"

SONA_HEADING_COUNT=$(count_headings "$SONA_FIXTURE")
SONA_BODY_CHARS=$(aggregate_body_chars "$SONA_FIXTURE")

bash "$MIGRATE_SCRIPT" \
  --db "$DB_PATH" \
  --file "$SONA_FIXTURE" \
  --coordinator "sona" 2>/dev/null

sona_rows=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='sona' AND note IS NOT NULL AND note != '';")

if [ "$sona_rows" -eq "$SONA_HEADING_COUNT" ]; then
  pass "sona: $sona_rows rows == $SONA_HEADING_COUNT headings"
else
  fail "sona: got $sona_rows rows, expected $SONA_HEADING_COUNT headings"
fi

sona_missing_ref=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='sona' AND (source_ref IS NULL OR source_ref='');")
if [ "$sona_missing_ref" -eq 0 ]; then
  pass "sona: all rows have source_ref set"
else
  fail "sona: $sona_missing_ref rows missing source_ref"
fi

# ── §4: No annotation text lost ───────────────────────────────────────────────
echo ""
echo "§4 Annotation text preservation"

# Aggregate note column character count from DB vs source body chars.
# We require DB total >= 80% of source body chars as a floor (parsing overhead is acceptable
# for separator lines, blank lines, and markdown fence discards, but bulk prose must land).
evelynn_db_chars=$(db_read "$DB_PATH" \
  "SELECT COALESCE(SUM(LENGTH(note)),0) FROM open_threads WHERE coordinator='evelynn';")
sona_db_chars=$(db_read "$DB_PATH" \
  "SELECT COALESCE(SUM(LENGTH(note)),0) FROM open_threads WHERE coordinator='sona';")

# 80% floor — allows stripping of blank lines / hr separators during parse
evelynn_floor=$(( EVELYNN_BODY_CHARS * 80 / 100 ))
sona_floor=$(( SONA_BODY_CHARS * 80 / 100 ))

if [ "$evelynn_db_chars" -ge "$evelynn_floor" ]; then
  pass "evelynn: note chars $evelynn_db_chars >= 80% of source body $EVELYNN_BODY_CHARS (floor: $evelynn_floor)"
else
  fail "evelynn: note chars $evelynn_db_chars < 80% of source body $EVELYNN_BODY_CHARS (floor: $evelynn_floor) — text lost"
fi

if [ "$sona_db_chars" -ge "$sona_floor" ]; then
  pass "sona: note chars $sona_db_chars >= 80% of source body $SONA_BODY_CHARS (floor: $sona_floor)"
else
  fail "sona: note chars $sona_db_chars < 80% of source body $SONA_BODY_CHARS (floor: $sona_floor) — text lost"
fi

# ── §5: coordinator column correct ────────────────────────────────────────────
echo ""
echo "§5 Coordinator column correctness"

evelynn_wrong_coord=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator != 'evelynn' AND rowid IN (
     SELECT rowid FROM open_threads WHERE coordinator='evelynn'
   );" 2>/dev/null || echo 0)
# Simpler: just assert all evelynn rows have coordinator='evelynn'
evelynn_coord_ok=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn';")
if [ "$evelynn_coord_ok" -eq "$EVELYNN_HEADING_COUNT" ]; then
  pass "evelynn: coordinator column = 'evelynn' on all $evelynn_coord_ok rows"
else
  fail "evelynn: coordinator column mismatch ($evelynn_coord_ok rows with 'evelynn', expected $EVELYNN_HEADING_COUNT)"
fi

sona_coord_ok=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='sona';")
if [ "$sona_coord_ok" -eq "$SONA_HEADING_COUNT" ]; then
  pass "sona: coordinator column = 'sona' on all $sona_coord_ok rows"
else
  fail "sona: coordinator column mismatch ($sona_coord_ok rows with 'sona', expected $SONA_HEADING_COUNT)"
fi

# ── §6: Idempotency — re-running migration must not duplicate rows ─────────────
echo ""
echo "§6 Idempotency — re-run both fixtures"

bash "$MIGRATE_SCRIPT" \
  --db "$DB_PATH" \
  --file "$EVELYNN_FIXTURE" \
  --coordinator "evelynn" 2>/dev/null

bash "$MIGRATE_SCRIPT" \
  --db "$DB_PATH" \
  --file "$SONA_FIXTURE" \
  --coordinator "sona" 2>/dev/null

evelynn_rows_after=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn';")
sona_rows_after=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='sona';")

if [ "$evelynn_rows_after" -eq "$EVELYNN_HEADING_COUNT" ]; then
  pass "evelynn: row count stable after re-run ($evelynn_rows_after)"
else
  fail "evelynn: row count changed after re-run ($evelynn_rows_after != $EVELYNN_HEADING_COUNT) — UNIQUE constraint not enforced"
fi

if [ "$sona_rows_after" -eq "$SONA_HEADING_COUNT" ]; then
  pass "sona: row count stable after re-run ($sona_rows_after)"
else
  fail "sona: row count changed after re-run ($sona_rows_after != $SONA_HEADING_COUNT) — UNIQUE constraint not enforced"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Expected heading counts (from today's snapshot):"
echo "  evelynn: $EVELYNN_HEADING_COUNT headings"
echo "  sona:    $SONA_HEADING_COUNT headings"
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
