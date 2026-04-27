#!/usr/bin/env bash
# T3a xfail — coord-memory-v1 ADR (complex track, Rakan)
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D6 §T3a
#
# D6 PRAGMA invariants under test (applied by _lib_db.sh on every connection open):
#   - journal_mode = WAL   (readers don't block writers) — DB-header persistent; raw sqlite3 ok
#   - busy_timeout = 5000  (ms; writer waits up to 5s before failing) — per-connection; must use db_read
#   - synchronous = NORMAL (WAL-safe; faster than FULL; loses at most last tx on hard crash) — per-connection; must use db_read
#
# IMPORTANT contract this test pins on Viktor's T3b implementation:
#   busy_timeout and synchronous are per-connection settings — they are NOT persisted in the DB
#   header and do not survive process boundaries. A raw `sqlite3 "$DB" "PRAGMA …"` call sees
#   SQLite defaults, not the values db_open set. Therefore §3 and §4 route through db_read,
#   which must apply all D6 PRAGMAs at the top of every query in the same sqlite3 invocation.
#
# This test is expected RED until T3b lands _lib_db.sh.
# It turns green when Viktor implements the helper library and sets all three PRAGMAs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_DB="$REPO_ROOT/scripts/state/_lib_db.sh"
MIGRATION="$REPO_ROOT/agents/_state/migrations/0001-init.sql"

# ── xfail anchor ─────────────────────────────────────────────────────────────
if [ ! -f "$LIB_DB" ]; then
  echo "XFAIL: _lib_db.sh not present at $LIB_DB"
  echo "This test is expected RED until T3b lands the helper library."
  exit 1
fi

if [ ! -f "$MIGRATION" ]; then
  echo "XFAIL: migration file not present at $MIGRATION"
  exit 1
fi

# shellcheck source=/dev/null
. "$LIB_DB"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

DB_DIR=$(mktemp -d /tmp/test-helper-lib-pragmas-XXXXXX)
DB_PATH="$DB_DIR/state.db"

cleanup() { rm -rf "$DB_DIR"; }
trap cleanup EXIT

echo "=== T3a: helper library PRAGMA assertions ==="
echo ""

# ── §1: Open connection via library ─────────────────────────────────────────
echo "§1 Open connection via db_open"
db_open "$DB_PATH"
sqlite3 "$DB_PATH" < "$MIGRATION"
pass "db_open completed without error"

# ── §2: journal_mode = WAL ───────────────────────────────────────────────────
echo ""
echo "§2 PRAGMA journal_mode"
# journal_mode PRAGMA returns the mode that was set; after WAL is active it returns 'wal'.
JOURNAL_MODE=$(sqlite3 "$DB_PATH" "PRAGMA journal_mode;")
if [ "$JOURNAL_MODE" = "wal" ]; then
  pass "journal_mode = wal"
else
  fail "journal_mode = '$JOURNAL_MODE' (want 'wal')"
fi

# ── §3: busy_timeout = 5000 ──────────────────────────────────────────────────
echo ""
echo "§3 PRAGMA busy_timeout (via db_read — per-connection; raw sqlite3 would see defaults)"
# Must route through db_read so the PRAGMA is queried within the same connection that
# db_open configured. A bare sqlite3 invocation opens a fresh connection with busy_timeout=0.
BUSY_TIMEOUT=$(db_read "$DB_PATH" "PRAGMA busy_timeout;")
if [ "$BUSY_TIMEOUT" -eq 5000 ]; then
  pass "busy_timeout = 5000 ms"
else
  fail "busy_timeout = '$BUSY_TIMEOUT' ms (want 5000) — db_read must apply PRAGMA busy_timeout=5000"
fi

# ── §4: synchronous = NORMAL (value 1) ───────────────────────────────────────
echo ""
echo "§4 PRAGMA synchronous (via db_read — per-connection; raw sqlite3 would see defaults)"
# synchronous PRAGMA returns an integer: 0=OFF 1=NORMAL 2=FULL 3=EXTRA
# Must route through db_read for the same reason as §3.
SYNC_VAL=$(db_read "$DB_PATH" "PRAGMA synchronous;")
if [ "$SYNC_VAL" -eq 1 ]; then
  pass "synchronous = NORMAL (1)"
else
  fail "synchronous = '$SYNC_VAL' (want 1 / NORMAL) — db_read must apply PRAGMA synchronous=NORMAL"
fi

# ── §5: PRAGMAs apply on a second independent db_open call ──────────────────
# journal_mode is persistent in the DB header once WAL is set; busy_timeout and
# synchronous are per-connection. This section asserts db_open + db_read apply
# them consistently on each new DB (not just the first opened in the process).
echo ""
echo "§5 PRAGMAs apply on a second independent db_open + db_read call"

DB_PATH2="$DB_DIR/state2.db"
db_open "$DB_PATH2"
sqlite3 "$DB_PATH2" < "$MIGRATION"

JOURNAL2=$(sqlite3 "$DB_PATH2" "PRAGMA journal_mode;")
BUSY2=$(db_read "$DB_PATH2" "PRAGMA busy_timeout;")
SYNC2=$(db_read "$DB_PATH2" "PRAGMA synchronous;")

if [ "$JOURNAL2" = "wal" ]; then
  pass "second db: journal_mode = wal"
else
  fail "second db: journal_mode = '$JOURNAL2' (want 'wal')"
fi

if [ "$BUSY2" -eq 5000 ]; then
  pass "second db: busy_timeout = 5000 ms"
else
  fail "second db: busy_timeout = '$BUSY2' ms (want 5000)"
fi

if [ "$SYNC2" -eq 1 ]; then
  pass "second db: synchronous = NORMAL (1)"
else
  fail "second db: synchronous = '$SYNC2' (want 1)"
fi

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
