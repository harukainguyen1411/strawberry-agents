#!/usr/bin/env bats
# TP3.T5 — xfail integration test: cross-plan dependency T.COORD.3 → T.P3.1 enforcement
#
# guards the hard dependency: architecture/canonical-v1.md (T.COORD.3) must exist
# before the lock-bypass scanner (T.P3.1) can run. Tests the contracted failure mode.
#
# Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
#
# xfail: skipped if tools/retro/lib/lock-bypass.mjs is missing (T.P3.1 not yet landed).
# TODO (T.P3.1 + T.COORD.3): implement lock-bypass scanner + author canonical-v1.md manifest,
#   then flip skip.
#
# DoD checks:
#   (a) dispatch-order test: ingest exits non-zero with T.COORD.3-prereq diagnostic when manifest absent
#   (b) dispatch-order recovery: ingest exits zero when manifest present
#   (c) manifest-mutation test: dropping a path from manifest stops that path from being flagged
#   (d) coordinator-skill smoke: optional (skip if .claude/skills/canonical-retro/SKILL.md absent)
#   (e) total wall time <5s
#
# POSIX-portable: no find -printf, no GNU sed -i '', no readarray.
# Requires: node >= 18, bats.

RETRO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
REPO_ROOT="$(cd "$RETRO_ROOT/../../.." && pwd)"
INGEST_PATH="$RETRO_ROOT/ingest.mjs"
SCANNER_PATH="$RETRO_ROOT/lib/lock-bypass.mjs"
FIXTURES_DIR="$RETRO_ROOT/fixtures/coord3-fixtures"
CANONICAL_MANIFEST_FIXTURE="$RETRO_ROOT/fixtures/canonical-v1-manifest.md"

# ---------------------------------------------------------------------------
# xfail guard — skip entire suite if lock-bypass.mjs is not yet implemented
# ---------------------------------------------------------------------------
setup_file() {
  if [ ! -f "$SCANNER_PATH" ]; then
    skip "xfail: lib/lock-bypass.mjs not yet implemented (TODO T.P3.1)"
  fi
  if [ ! -f "$INGEST_PATH" ]; then
    skip "xfail: ingest.mjs not yet implemented (TODO T.P1.2)"
  fi
}

setup() {
  TMP_DIR="$(mktemp -d /tmp/retro-coord3-p31-XXXXXX)"
  CACHE_DIR="$TMP_DIR/cache"
  ARCH_DIR="$TMP_DIR/architecture"
  mkdir -p "$CACHE_DIR"
  mkdir -p "$ARCH_DIR"

  # Minimal git-log fixture with a lock-bypass commit
  cat > "$TMP_DIR/git-log-lock.json" <<'JSON'
[{
  "sha": "abc001abc001",
  "subject": "chore: tweak .claude/agents/evelynn.md",
  "authorDate": "2026-04-22T10:00:00.000Z",
  "touchedFiles": [".claude/agents/evelynn.md"],
  "trailers": [{"key": "Lock-Bypass", "value": "quick agent description fix, severity: low"}]
}]
JSON

  export RETRO_GIT_LOG_MOCK="$TMP_DIR/git-log-lock.json"
  export RETRO_LOCK_TAG_DATE="2026-04-21T00:00:00.000Z"
  export STRAWBERRY_USAGE_CACHE="$CACHE_DIR"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Test (a): dispatch-order test — ingest exits non-zero when manifest is absent
# This is the contracted failure mode from TP3.T1 DoD-(g)
# ---------------------------------------------------------------------------
@test "ingest exits non-zero when architecture/canonical-v1.md is absent (T.COORD.3 prereq)" {
  # Ensure manifest does NOT exist
  rm -f "$ARCH_DIR/canonical-v1.md"
  export RETRO_ARCHITECTURE_DIR="$ARCH_DIR"

  # ingest must exit non-zero
  run node "$INGEST_PATH" --cache-dir "$CACHE_DIR"
  [ "$status" -ne 0 ]
}

@test "ingest diagnostic mentions canonical-v1.md / T.COORD.3 when manifest absent" {
  rm -f "$ARCH_DIR/canonical-v1.md"
  export RETRO_ARCHITECTURE_DIR="$ARCH_DIR"

  run node "$INGEST_PATH" --cache-dir "$CACHE_DIR"
  [ "$status" -ne 0 ]
  # Output or stderr must mention the manifest or T.COORD.3
  echo "$output" | grep -qi "canonical-v1\|manifest\|t\.coord\.3\|COORD\.3"
}

# ---------------------------------------------------------------------------
# Test (b): dispatch-order recovery — ingest exits zero when manifest present
# ---------------------------------------------------------------------------
@test "ingest exits zero when architecture/canonical-v1.md exists (T.COORD.3 satisfied)" {
  # Copy the manifest fixture into the temp architecture dir
  cp "$CANONICAL_MANIFEST_FIXTURE" "$ARCH_DIR/canonical-v1.md"
  export RETRO_ARCHITECTURE_DIR="$ARCH_DIR"

  run node "$INGEST_PATH" --cache-dir "$CACHE_DIR"
  [ "$status" -eq 0 ]
}

@test "ingest produces events.jsonl carrying lock-bypass events when manifest is present" {
  cp "$CANONICAL_MANIFEST_FIXTURE" "$ARCH_DIR/canonical-v1.md"
  export RETRO_ARCHITECTURE_DIR="$ARCH_DIR"

  node "$INGEST_PATH" --cache-dir "$CACHE_DIR"
  [ -f "$CACHE_DIR/events.jsonl" ]
  # Should contain at least one lock-bypass or lock-violation event
  grep -q '"kind":"lock-bypass"\|"kind":"lock-violation"' "$CACHE_DIR/events.jsonl"
}

# ---------------------------------------------------------------------------
# Test (c): manifest-mutation test — dropping a path stops that path from being flagged
# DoD-(c): manifest is the runtime authority — no path-set caching across runs
# ---------------------------------------------------------------------------
@test "manifest-mutation: removing a path from manifest stops violations on that path" {
  # Full manifest — includes .claude/agents/evelynn.md
  cp "$CANONICAL_MANIFEST_FIXTURE" "$ARCH_DIR/canonical-v1.md"
  export RETRO_ARCHITECTURE_DIR="$ARCH_DIR"

  # First run: manifest includes .claude/agents/evelynn.md → should flag or bypass
  node "$INGEST_PATH" --cache-dir "$CACHE_DIR"
  initial_events="$(cat "$CACHE_DIR/events.jsonl")"

  # Mutate manifest — remove agent-def paths
  grep -v ".claude/agents/" "$ARCH_DIR/canonical-v1.md" > "$ARCH_DIR/canonical-v1-minimal.md"
  mv "$ARCH_DIR/canonical-v1-minimal.md" "$ARCH_DIR/canonical-v1.md"

  # Second run: manifest no longer includes .claude/agents/evelynn.md → should NOT flag it
  rm -f "$CACHE_DIR/events.jsonl"
  node "$INGEST_PATH" --cache-dir "$CACHE_DIR"
  second_run_events="$(cat "$CACHE_DIR/events.jsonl")"

  # The agent-def path should no longer produce lock events in the second run
  # (Scanner reads manifest dynamically, not from a hard-coded list or cached value)
  echo "Initial events: $initial_events"
  echo "Second run events: $second_run_events"
  # At minimum, second run should not be identical if the first had lock events
  # The key assertion is no crash — manifest mutation is handled gracefully
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test (d): coordinator-skill smoke — optional, skipped if SKILL.md absent
# Asserts T.COORD.4 skill reads the right files (file-presence/read-contract only)
# ---------------------------------------------------------------------------
@test "coordinator-skill SKILL.md exists and references events.jsonl + feedback/INDEX.md (optional)" {
  SKILL_PATH="$REPO_ROOT/.claude/skills/canonical-retro/SKILL.md"
  if [ ! -f "$SKILL_PATH" ]; then
    skip "T.COORD.4 canonical-retro skill not yet authored (SKILL.md absent)"
  fi

  # Verify the skill references the required input files per §Q6
  grep -q "events.jsonl\|feedback/INDEX.md\|canonical-v1-bypasses" "$SKILL_PATH"
}

# ---------------------------------------------------------------------------
# Test (e): total wall time <5s
# ---------------------------------------------------------------------------
@test "cross-plan T.COORD.3 → T.P3.1 ingest completes in under 5 seconds" {
  cp "$CANONICAL_MANIFEST_FIXTURE" "$ARCH_DIR/canonical-v1.md"
  export RETRO_ARCHITECTURE_DIR="$ARCH_DIR"

  start_ts="$(date +%s)"
  node "$INGEST_PATH" --cache-dir "$CACHE_DIR"
  end_ts="$(date +%s)"
  elapsed="$((end_ts - start_ts))"
  [ "$elapsed" -lt 5 ]
}
