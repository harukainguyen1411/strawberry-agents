#!/usr/bin/env bash
# T6a xfail — coord-memory-v1 ADR (complex track, Rakan)
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T6a
#
# Three skill write paths exercised:
#   1. decision-capture — scripts/capture-decision.sh writes markdown shard
#      AND (post-T6b) a row in the decisions table.
#   2. /end-session Step 6/6b — shard write AND (post-T6b) a row in sessions.
#      T6b will introduce scripts/state/db-write-session.sh as the callable
#      bash hook invoked from the skill. This test calls that script directly.
#   3. /end-subagent-session learning write — AND (post-T6b) a row in learnings.
#      T6b will introduce scripts/state/db-write-learning.sh. This test calls
#      that script directly.
#
# Plus idempotency: re-running each write on the same input must NOT cause
# UNIQUE-constraint failures (per D3).
#
# DoD: committed RED against unmodified skills. Turns green when T6b lands
# the DB INSERTs and the three helper scripts exist.
#
# Dependencies: T2b (migration SQL), T3b (_lib_db.sh).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

MIGRATION_DIR="$REPO_ROOT/agents/_state/migrations"
LIB_DB="$REPO_ROOT/scripts/state/_lib_db.sh"
CAPTURE_DECISION="$REPO_ROOT/scripts/capture-decision.sh"
DB_WRITE_SESSION="$REPO_ROOT/scripts/state/db-write-session.sh"
DB_WRITE_LEARNING="$REPO_ROOT/scripts/state/db-write-learning.sh"

PASS=0
FAIL=0
XFAIL=0

pass()  { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail()  { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
xfail() { printf '  XFAIL: %s\n' "$1"; XFAIL=$((XFAIL + 1)); }

# ── xfail anchors — check prerequisites ──────────────────────────────────────

missing_prereqs=0

if [ ! -f "$LIB_DB" ]; then
    xfail "_lib_db.sh not present at $LIB_DB — expected RED until T3b lands"
    missing_prereqs=1
fi

if [ ! -d "$MIGRATION_DIR" ] || [ -z "$(ls "$MIGRATION_DIR"/*.sql 2>/dev/null)" ]; then
    xfail "migration SQL not present at $MIGRATION_DIR — expected RED until T2b lands"
    missing_prereqs=1
fi

if [ ! -f "$CAPTURE_DECISION" ]; then
    xfail "capture-decision.sh not found at $CAPTURE_DECISION"
    missing_prereqs=1
fi

if [ $missing_prereqs -gt 0 ]; then
    printf '\nXFAIL: prerequisite files missing — this test is expected RED until T2b+T3b land.\n'
    exit 1
fi

# shellcheck source=/dev/null
. "$LIB_DB"

# ── fixture setup ─────────────────────────────────────────────────────────────

DB_DIR=$(mktemp -d /tmp/test-authored-writes-XXXXXX)
DB_PATH="$DB_DIR/state.db"
MEM_ROOT="$DB_DIR/mem-root"

# Simulated coordinator memory tree (STRAWBERRY_MEMORY_ROOT shim)
COORDINATOR="evelynn"
mkdir -p "$MEM_ROOT/agents/$COORDINATOR/memory/decisions/log"

cleanup() { rm -rf "$DB_DIR"; }
trap cleanup EXIT

db_open "$DB_PATH"
db_apply_migrations "$DB_PATH" "$MIGRATION_DIR"

printf '=== T6a: authored-entity write paths xfail test ===\n\n'

# ── §1: decision-capture — markdown shard + decisions row ─────────────────────

printf '§1 decision-capture skill\n'

DECISION_FILE=$(mktemp /tmp/decision-XXXXXX.md)
cat > "$DECISION_FILE" << 'DECISION_EOF'
---
decision_id: 2026-04-27-test-slug
date: 2026-04-27
session_short_uuid: t6a-test-001
coordinator: evelynn
axes: [reliability]
question: "Should T6a tests run as xfail first?"
options:
  - letter: a
    description: "Yes — xfail first"
  - letter: b
    description: "No — implement first"
coordinator_pick: a
coordinator_confidence: high
coordinator_rationale: "xfail-first is Rule 12"
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /test-t6a
---
## Context
This is a fixture decision for T6a integration testing.

## Why this matters
Validates that decision-capture writes both markdown and DB row.
DECISION_EOF

# §1.1 Invoke capture-decision.sh with STRAWBERRY_MEMORY_ROOT shim.
#   STRAWBERRY_STATE_DB points to the test DB so T6b's db_write_tx
#   lands in our fixture DB, not the production one.
SHARD_PATH=$(
    STRAWBERRY_MEMORY_ROOT="$MEM_ROOT" \
    STRAWBERRY_STATE_DB="$DB_PATH" \
    bash "$CAPTURE_DECISION" "$COORDINATOR" --file "$DECISION_FILE" 2>/dev/null
) || true

rm -f "$DECISION_FILE"

if [ -n "$SHARD_PATH" ] && [ -f "$SHARD_PATH" ]; then
    pass "§1.1 markdown shard written: $SHARD_PATH"
else
    fail "§1.1 markdown shard NOT written (capture-decision.sh returned empty or non-existent path)"
fi

# §1.2 Assert decisions row exists in DB.
#   This will be 0 until T6b modifies capture-decision.sh to call db_write_tx.
DECISION_COUNT=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM decisions WHERE coordinator='evelynn' AND slug='test-slug';")
if [ "$DECISION_COUNT" -ge 1 ]; then
    pass "§1.2 decisions row present (count=$DECISION_COUNT)"
else
    fail "§1.2 decisions row NOT present — expected T6b DB insert, got count=$DECISION_COUNT (XFAIL: T6b not yet landed)"
fi

# §1.3 Idempotency — re-run with same decision_id.
#   capture-decision.sh handles file collision by suffix; the DB insert must use
#   INSERT OR IGNORE (or equivalent) so UNIQUE(coordinator, slug, decided_at)
#   does not blow up. We invoke once more and assert count stays ≤ 2 (not a crash).
DECISION_FILE2=$(mktemp /tmp/decision-XXXXXX.md)
cat > "$DECISION_FILE2" << 'DECISION_EOF2'
---
decision_id: 2026-04-27-test-slug
date: 2026-04-27
session_short_uuid: t6a-test-001
coordinator: evelynn
axes: [reliability]
question: "Should T6a tests run as xfail first?"
options:
  - letter: a
    description: "Yes — xfail first"
coordinator_pick: a
coordinator_confidence: high
coordinator_rationale: "xfail-first is Rule 12"
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /test-t6a
---
## Context
Idempotency re-run fixture.

## Why this matters
Validates UNIQUE constraint does not fail on re-run.
DECISION_EOF2

IDEMPOTENT_RC=0
STRAWBERRY_MEMORY_ROOT="$MEM_ROOT" \
STRAWBERRY_STATE_DB="$DB_PATH" \
    bash "$CAPTURE_DECISION" "$COORDINATOR" --file "$DECISION_FILE2" > /dev/null 2>&1 || IDEMPOTENT_RC=$?

rm -f "$DECISION_FILE2"

if [ "$IDEMPOTENT_RC" -eq 0 ]; then
    pass "§1.3 idempotency re-run succeeded (no UNIQUE constraint failure)"
else
    fail "§1.3 idempotency re-run failed with rc=$IDEMPOTENT_RC (possible UNIQUE constraint blow-up)"
fi

# ── §2: /end-session Step 6 — session shard + sessions row ───────────────────

printf '\n§2 /end-session session shard write (db-write-session.sh)\n'

# T6b will introduce scripts/state/db-write-session.sh with signature:
#   db-write-session.sh <db_path> <id> <coordinator> <started_at> <ended_at> <shard_path> [tldr] [branch]
# The xfail asserts the script exists and writes a sessions row.

SESSION_SHARD="$MEM_ROOT/agents/evelynn/memory/last-sessions/t6a-test-session.md"
mkdir -p "$(dirname "$SESSION_SHARD")"
cat > "$SESSION_SHARD" << 'SESSION_EOF'
## Session 2026-04-27 (S1, cli)

Summary: T6a test fixture session.

## Open threads into next session
- none
SESSION_EOF

# §2.1 Script existence check — expected absent until T6b lands.
if [ ! -f "$DB_WRITE_SESSION" ]; then
    fail "§2.1 db-write-session.sh not found at $DB_WRITE_SESSION (XFAIL: T6b not yet landed)"
else
    pass "§2.1 db-write-session.sh present"

    # §2.2 Invoke and assert sessions row.
    SESSION_WRITE_RC=0
    STRAWBERRY_STATE_DB="$DB_PATH" \
        bash "$DB_WRITE_SESSION" \
            "$DB_PATH" \
            "t6a-sess-001" \
            "evelynn" \
            "2026-04-27T10:00:00Z" \
            "2026-04-27T11:00:00Z" \
            "$SESSION_SHARD" \
            "T6a test session" \
            "" \
        2>/dev/null || SESSION_WRITE_RC=$?

    if [ "$SESSION_WRITE_RC" -eq 0 ]; then
        SESSION_COUNT=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM sessions WHERE id='t6a-sess-001';")
        if [ "$SESSION_COUNT" -ge 1 ]; then
            pass "§2.2 sessions row present (count=$SESSION_COUNT)"
        else
            fail "§2.2 sessions row NOT present after db-write-session.sh invocation"
        fi
    else
        fail "§2.2 db-write-session.sh exited with rc=$SESSION_WRITE_RC"
    fi

    # §2.3 Idempotency — re-run must not fail on UNIQUE(id).
    SESSION_IDEMPOTENT_RC=0
    STRAWBERRY_STATE_DB="$DB_PATH" \
        bash "$DB_WRITE_SESSION" \
            "$DB_PATH" \
            "t6a-sess-001" \
            "evelynn" \
            "2026-04-27T10:00:00Z" \
            "2026-04-27T11:00:00Z" \
            "$SESSION_SHARD" \
            "T6a test session" \
            "" \
        2>/dev/null || SESSION_IDEMPOTENT_RC=$?

    if [ "$SESSION_IDEMPOTENT_RC" -eq 0 ]; then
        pass "§2.3 sessions idempotency re-run succeeded"
    else
        fail "§2.3 sessions idempotency re-run failed with rc=$SESSION_IDEMPOTENT_RC"
    fi
fi

# ── §3: /end-subagent-session learning write — learning shard + learnings row ─

printf '\n§3 /end-subagent-session learning write (db-write-learning.sh)\n'

# T6b will introduce scripts/state/db-write-learning.sh with signature:
#   db-write-learning.sh <db_path> <agent> <coordinator> <learned_at> <slug> <path> [topic]
# The xfail asserts the script exists and writes a learnings row.

LEARNING_PATH="$MEM_ROOT/agents/rakan/learnings/2026-04-27-t6a-test-learning.md"
mkdir -p "$(dirname "$LEARNING_PATH")"
cat > "$LEARNING_PATH" << 'LEARNING_EOF'
# 2026-04-27 — T6a fixture learning

T6a xfail tests must exercise the db-write helper scripts directly, not the AI skill docs.
LEARNING_EOF

# §3.1 Script existence check — expected absent until T6b lands.
if [ ! -f "$DB_WRITE_LEARNING" ]; then
    fail "§3.1 db-write-learning.sh not found at $DB_WRITE_LEARNING (XFAIL: T6b not yet landed)"
else
    pass "§3.1 db-write-learning.sh present"

    # §3.2 Invoke and assert learnings row.
    LEARNING_WRITE_RC=0
    STRAWBERRY_STATE_DB="$DB_PATH" \
        bash "$DB_WRITE_LEARNING" \
            "$DB_PATH" \
            "rakan" \
            "evelynn" \
            "2026-04-27" \
            "t6a-test-learning" \
            "$LEARNING_PATH" \
            "T6a test fixture topic" \
        2>/dev/null || LEARNING_WRITE_RC=$?

    if [ "$LEARNING_WRITE_RC" -eq 0 ]; then
        LEARNING_COUNT=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM learnings WHERE agent='rakan' AND slug='t6a-test-learning';")
        if [ "$LEARNING_COUNT" -ge 1 ]; then
            pass "§3.2 learnings row present (count=$LEARNING_COUNT)"
        else
            fail "§3.2 learnings row NOT present after db-write-learning.sh invocation"
        fi
    else
        fail "§3.2 db-write-learning.sh exited with rc=$LEARNING_WRITE_RC"
    fi

    # §3.3 Idempotency — re-run must not fail on UNIQUE(agent, slug, learned_at).
    LEARNING_IDEMPOTENT_RC=0
    STRAWBERRY_STATE_DB="$DB_PATH" \
        bash "$DB_WRITE_LEARNING" \
            "$DB_PATH" \
            "rakan" \
            "evelynn" \
            "2026-04-27" \
            "t6a-test-learning" \
            "$LEARNING_PATH" \
            "T6a test fixture topic" \
        2>/dev/null || LEARNING_IDEMPOTENT_RC=$?

    if [ "$LEARNING_IDEMPOTENT_RC" -eq 0 ]; then
        pass "§3.3 learnings idempotency re-run succeeded"
    else
        fail "§3.3 learnings idempotency re-run failed with rc=$LEARNING_IDEMPOTENT_RC"
    fi
fi

# ── summary ───────────────────────────────────────────────────────────────────

printf '\n=== Results: %d passed, %d failed, %d xfail (expected absent) ===\n' "$PASS" "$FAIL" "$XFAIL"

if [ "$FAIL" -gt 0 ]; then
    printf 'XFAIL expected — %d DB-write assertions fail because T6b has not yet modified the skills.\n' "$FAIL"
    exit 1
fi
exit 0
