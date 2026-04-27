#!/usr/bin/env bash
# T7a xfail — coord-memory-v1 ADR
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md
# This test will turn green when T7b lands scripts/state/migrate-open-threads-notes.sh.
#
# Coverage:
#   §1    Migration script presence gate (xfail anchor — exits red if missing)
#   §2    Evelynn fixture — every ## heading produces an open_threads row with source_ref set
#   §2.5  Evelynn source_ref content pins — spot-check 7 expected source_ref values
#   §3    Sona fixture — same assertions for Sona
#   §3.5  Sona source_ref content pins — spot-check 7 expected source_ref values
#   §4    No annotation text lost — aggregate note chars >= 80% of source body chars
#   §5    coordinator column set correctly per invocation arg
#   §6    Idempotency (UPSERT) — re-run with mutated note, assert update reflected

# shellcheck disable=SC2317  # cleanup() called via trap — not a dead function

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

run_migrate() {
  local file="$1" coord="$2"
  local err rc
  err=$(bash "$MIGRATE_SCRIPT" --db "$DB_PATH" --file "$file" --coordinator "$coord" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  [stderr from migrate-open-threads-notes.sh]: $err" >&2
    return "$rc"
  fi
  return 0
}

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
aggregate_body_chars() {
  local file="$1"
  awk '/^## /{in_body=1; next} in_body{len+=length($0)} END{print len+0}' "$file"
}

# ── §2: Evelynn fixture ────────────────────────────────────────────────────────
echo ""
echo "§2 Evelynn fixture migration"

EVELYNN_HEADING_COUNT=$(count_headings "$EVELYNN_FIXTURE")
EVELYNN_BODY_CHARS=$(aggregate_body_chars "$EVELYNN_FIXTURE")

if run_migrate "$EVELYNN_FIXTURE" "evelynn"; then
  evelynn_rows=$(db_read "$DB_PATH" \
    "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn' AND note IS NOT NULL AND note != '';")

  if [ "$evelynn_rows" -eq "$EVELYNN_HEADING_COUNT" ]; then
    pass "evelynn: $evelynn_rows rows == $EVELYNN_HEADING_COUNT headings"
  else
    fail "evelynn: got $evelynn_rows rows, expected $EVELYNN_HEADING_COUNT headings"
  fi

  evelynn_missing_ref=$(db_read "$DB_PATH" \
    "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn' AND (source_ref IS NULL OR source_ref='');")
  if [ "$evelynn_missing_ref" -eq 0 ]; then
    pass "evelynn: all rows have source_ref set"
  else
    fail "evelynn: $evelynn_missing_ref rows missing source_ref"
  fi
else
  fail "evelynn: migration script exited non-zero"
fi

# ── §2.5: Evelynn source_ref content pins ─────────────────────────────────────
echo ""
echo "§2.5 Evelynn source_ref content pins"

# These headings exercise 4 distinct source_ref inference patterns:
#   pr#NN  — "## PR #93 ..." (explicit PR number)
#   named  — "## Dashboard Phase 1 — SHIPPED" (topic slug, no PR)
#   plan   — "## Cornerstone Plan A (agent-feedback-system) — RESOLVED" (plan name ref)
#   simple — "## canonical-v1 lock-watch" (plain descriptor, no PR/plan anchor)
EVELYNN_PINS=(
  "PR #93 (T.P2.3 decision-rollup fidelity) — awaiting Senna r3"
  "Dashboard Phase 1 — SHIPPED"
  "Cornerstone Plan A (agent-feedback-system) — RESOLVED"
  "Cornerstone Plan B (coordinator-decision-feedback) — MERGED"
  "canonical-v1 lock-watch"
  "PR #69 — RESOLVED"
  "Inbox watcher PreToolUse hook — REMOVED"
)

for pin in "${EVELYNN_PINS[@]}"; do
  # source_ref may be exact heading text, a normalised slug, or an inferred pr/plan ref.
  # We accept any non-null row whose source_ref contains the distinguishing substring.
  # The substring chosen per pin is the most distinctive fragment that survives any
  # reasonable normalisation (lowercasing, slug-ification, trimming).
  hint=$(echo "$pin" | cut -c1-40)
  count=$(db_read "$DB_PATH" \
    "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn' AND source_ref LIKE '%$(echo "$pin" | sed "s/'/''/g")%';" 2>/dev/null || echo 0)
  if [ "$count" -ge 1 ]; then
    pass "evelynn source_ref pin: '$hint...'"
  else
    fail "evelynn source_ref pin missing: '$hint...' — regex misfire on this heading pattern?"
  fi
done

# ── §3: Sona fixture ──────────────────────────────────────────────────────────
echo ""
echo "§3 Sona fixture migration"

SONA_HEADING_COUNT=$(count_headings "$SONA_FIXTURE")
SONA_BODY_CHARS=$(aggregate_body_chars "$SONA_FIXTURE")

if run_migrate "$SONA_FIXTURE" "sona"; then
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
else
  fail "sona: migration script exited non-zero"
fi

# ── §3.5: Sona source_ref content pins ────────────────────────────────────────
echo ""
echo "§3.5 Sona source_ref content pins"

# Sona headings exercise: ALLCAPS topic (RUNWAY), date-tagged (S2 persistence),
# resolution-tagged (RESOLVED), severity-tagged (HIGH SEVERITY), plain descriptor.
SONA_PINS=(
  "RUNWAY — E2E ship of demo-studio-v3 (live)"
  "S2 persistence — in-progress (2026-04-24, shard ec53a0d6)"
  "Work-reviewer identity model correction (2026-04-24, RESOLVED — standing rule update)"
  "Plan lifecycle guard — heredoc false-close (2026-04-24, open, HIGH SEVERITY)"
  "Co-authored-by Viktor leak on main (2026-04-24, open)"
  "Self-invite ADR — in execution (2026-04-24, open)"
  "Akali security breach — addressed (2026-04-24, shard ec53a0d6)"
)

for pin in "${SONA_PINS[@]}"; do
  hint=$(echo "$pin" | cut -c1-40)
  count=$(db_read "$DB_PATH" \
    "SELECT COUNT(*) FROM open_threads WHERE coordinator='sona' AND source_ref LIKE '%$(echo "$pin" | sed "s/'/''/g")%';" 2>/dev/null || echo 0)
  if [ "$count" -ge 1 ]; then
    pass "sona source_ref pin: '$hint...'"
  else
    fail "sona source_ref pin missing: '$hint...' — regex misfire on this heading pattern?"
  fi
done

# ── §4: No annotation text lost ───────────────────────────────────────────────
echo ""
echo "§4 Annotation text preservation"

evelynn_db_chars=$(db_read "$DB_PATH" \
  "SELECT COALESCE(SUM(LENGTH(note)),0) FROM open_threads WHERE coordinator='evelynn';")
sona_db_chars=$(db_read "$DB_PATH" \
  "SELECT COALESCE(SUM(LENGTH(note)),0) FROM open_threads WHERE coordinator='sona';")

# 80% floor — allows stripping blank lines / hr separators; flags bulk prose loss
evelynn_floor=$(( EVELYNN_BODY_CHARS * 80 / 100 ))
sona_floor=$(( SONA_BODY_CHARS * 80 / 100 ))

if [ "$evelynn_db_chars" -ge "$evelynn_floor" ]; then
  pass "evelynn: note chars $evelynn_db_chars >= 80% of source body $EVELYNN_BODY_CHARS (floor: $evelynn_floor)"
else
  fail "evelynn: note chars $evelynn_db_chars < floor $evelynn_floor — text lost"
fi

if [ "$sona_db_chars" -ge "$sona_floor" ]; then
  pass "sona: note chars $sona_db_chars >= 80% of source body $SONA_BODY_CHARS (floor: $sona_floor)"
else
  fail "sona: note chars $sona_db_chars < floor $sona_floor — text lost"
fi

# ── §5: coordinator column correct ────────────────────────────────────────────
echo ""
echo "§5 Coordinator column correctness"

evelynn_coord_ok=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn';")
if [ "$evelynn_coord_ok" -eq "$EVELYNN_HEADING_COUNT" ]; then
  pass "evelynn: coordinator='evelynn' on all $evelynn_coord_ok rows"
else
  fail "evelynn: coordinator mismatch ($evelynn_coord_ok rows, expected $EVELYNN_HEADING_COUNT)"
fi

sona_coord_ok=$(db_read "$DB_PATH" \
  "SELECT COUNT(*) FROM open_threads WHERE coordinator='sona';")
if [ "$sona_coord_ok" -eq "$SONA_HEADING_COUNT" ]; then
  pass "sona: coordinator='sona' on all $sona_coord_ok rows"
else
  fail "sona: coordinator mismatch ($sona_coord_ok rows, expected $SONA_HEADING_COUNT)"
fi

# ── §6: Idempotency — UPSERT semantics ────────────────────────────────────────
echo ""
echo "§6 Idempotency (UPSERT — mutated note must reflect on re-run)"

# Inject a sentinel note directly to simulate a coordinator annotation on one row.
# Then re-run migration — the script must UPSERT (not INSERT OR IGNORE) so any
# refreshed note content from the source file overwrites the sentinel.
# Row count must remain stable (no duplicates from the UNIQUE constraint).
first_evelynn_ref=$(db_read "$DB_PATH" \
  "SELECT source_ref FROM open_threads WHERE coordinator='evelynn' LIMIT 1;" 2>/dev/null || echo "")

if [ -n "$first_evelynn_ref" ]; then
  db_write_tx "$DB_PATH" \
    "UPDATE open_threads SET note='__SENTINEL_NOTE__' WHERE coordinator='evelynn' AND source_ref='$(echo "$first_evelynn_ref" | sed "s/'/''/g")';"

  sentinel_before=$(db_read "$DB_PATH" \
    "SELECT note FROM open_threads WHERE coordinator='evelynn' AND source_ref='$(echo "$first_evelynn_ref" | sed "s/'/''/g")';" 2>/dev/null || echo "")

  err=$(run_migrate "$EVELYNN_FIXTURE" "evelynn" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "§6 UPSERT: migration exited non-zero on re-run: $err"
  else
    note_after=$(db_read "$DB_PATH" \
      "SELECT note FROM open_threads WHERE coordinator='evelynn' AND source_ref='$(echo "$first_evelynn_ref" | sed "s/'/''/g")';" 2>/dev/null || echo "")
    rows_after=$(db_read "$DB_PATH" \
      "SELECT COUNT(*) FROM open_threads WHERE coordinator='evelynn';")

    if [ "$note_after" != "__SENTINEL_NOTE__" ]; then
      pass "§6 UPSERT: note updated on re-run (sentinel overwritten)"
    else
      fail "§6 UPSERT: note unchanged — INSERT OR IGNORE instead of UPSERT? (sentinel survived)"
    fi

    if [ "$rows_after" -eq "$EVELYNN_HEADING_COUNT" ]; then
      pass "§6 row count stable after UPSERT re-run ($rows_after)"
    else
      fail "§6 row count changed after re-run ($rows_after != $EVELYNN_HEADING_COUNT)"
    fi
  fi
else
  fail "§6 UPSERT: could not fetch first source_ref from evelynn rows"
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
