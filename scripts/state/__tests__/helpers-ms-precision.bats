#!/usr/bin/env bats
# xfail: T1 — ms-precision timestamp contract for db-write-session.sh,
#   db-write-learning.sh, and capture-decision.sh (§D6.2).
#
# Plan: plans/approved/personal/2026-04-27-helper-retrofit-ms-precision.md
# Rule 12: xfail scaffold committed before any impl commit on this branch.
# All three @test blocks are expected to FAIL against current code because the
# helpers bind caller-supplied second-precision / date-only strings directly
# without strftime normalisation. After T2-T4 land, rename to .bats.
#
# Regex: ^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$
# (23-char fixed-width ms-precision ISO-8601 shape per §D6.2)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
LIB_DB="$REPO_ROOT/scripts/state/_lib_db.sh"
MIGRATIONS_DIR="$REPO_ROOT/agents/_state/migrations"
WRITE_SESSION="$REPO_ROOT/scripts/state/db-write-session.sh"
WRITE_LEARNING="$REPO_ROOT/scripts/state/db-write-learning.sh"
CAPTURE_DECISION="$REPO_ROOT/scripts/capture-decision.sh"

MS_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$'

setup() {
  # shellcheck source=/dev/null
  . "$LIB_DB"
  TMPDIR_TEST="$(mktemp -d)"
  DB_PATH="$TMPDIR_TEST/state.db"
  db_open "$DB_PATH"
  db_apply_migrations "$DB_PATH" "$MIGRATIONS_DIR"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── T1-session: second-precision started_at is stored as 23-char ms-precision ─

@test "T1-session: started_at written by db-write-session.sh matches ms-precision regex" {
  # xfail: db-write-session.sh currently binds raw string — no strftime coercion
  export STRAWBERRY_STATE_DB="$DB_PATH"
  run bash "$WRITE_SESSION" \
    "$DB_PATH" \
    "test-session-001" \
    "evelynn" \
    "2026-04-27 10:00:00" \
    "" \
    "agents/evelynn/memory/last-sessions/test.md"
  [ "$status" -eq 0 ]

  result="$(sqlite3 "$DB_PATH" "SELECT started_at FROM sessions WHERE id='test-session-001';")"
  [ -n "$result" ]
  [[ "$result" =~ $MS_REGEX ]]
}

# ── T1-learning: second-precision learned_at is stored as 23-char ms-precision ─

@test "T1-learning: learned_at written by db-write-learning.sh matches ms-precision regex" {
  # xfail: db-write-learning.sh currently binds raw string — no strftime coercion
  export STRAWBERRY_STATE_DB="$DB_PATH"
  run bash "$WRITE_LEARNING" \
    "$DB_PATH" \
    "talon" \
    "evelynn" \
    "2026-04-27 11:00:00" \
    "2026-04-27-test-learning" \
    "agents/talon/learnings/2026-04-27-test-learning.md"
  [ "$status" -eq 0 ]

  result="$(sqlite3 "$DB_PATH" "SELECT learned_at FROM learnings WHERE slug='2026-04-27-test-learning';")"
  [ -n "$result" ]
  [[ "$result" =~ $MS_REGEX ]]
}

# ── T1-decision: date-only decided_at is stored as 23-char ms-precision ────────

@test "T1-decision: decided_at written by capture-decision.sh matches ms-precision regex" {
  # xfail: capture-decision.sh currently binds raw DECISION_DATE (date-only) — no strftime coercion
  export STRAWBERRY_STATE_DB="$DB_PATH"
  export STRAWBERRY_MEMORY_ROOT="$TMPDIR_TEST"

  # Bootstrap minimal coordinator memory tree required by capture-decision.sh
  mkdir -p "$TMPDIR_TEST/agents/evelynn/memory/decisions/log"
  git init -q "$TMPDIR_TEST" 2>/dev/null || true
  git -C "$TMPDIR_TEST" config user.email "test@test.local" 2>/dev/null || true
  git -C "$TMPDIR_TEST" config user.name "Test" 2>/dev/null || true

  SHARD="$(mktemp "$TMPDIR_TEST/decision-XXXXXX.md")"
  cat > "$SHARD" <<'YAML'
---
decision_id: 2026-04-27-test-ms-precision
date: 2026-04-27
session_short_uuid: abcd1234
coordinator: evelynn
axes: [scope-vs-debt]
question: "Does decided_at use ms-precision?"
options:
  - letter: a
    description: "Yes, via strftime"
coordinator_pick: a
coordinator_confidence: high
coordinator_rationale: "§D6.2 mandates it."
duong_pick: a
duong_concurred_silently: true
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-abcd1234
---

Test decision body.
YAML

  run bash "$CAPTURE_DECISION" evelynn --file "$SHARD"
  [ "$status" -eq 0 ]

  result="$(sqlite3 "$DB_PATH" "SELECT decided_at FROM decisions WHERE slug='test-ms-precision';")"
  [ -n "$result" ]
  [[ "$result" =~ $MS_REGEX ]]
}
