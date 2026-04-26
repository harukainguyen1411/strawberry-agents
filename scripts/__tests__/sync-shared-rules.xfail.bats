# xfail: §D4.3 — scripts/sync-shared-rules.sh
# (plans/in-progress/2026-04-20-agent-pair-taxonomy.md §D4.3)
# Bats tests expected to fail until sync-shared-rules.sh is implemented.
# Run with: bats scripts/__tests__/sync-shared-rules.xfail.bats
#
# xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
# Cases (a)-(d): depth-2 nested-include resolution for feedback-trigger propagation.
# Expected to fail until T7b lands (depth-2 pass implemented in sync-shared-rules.sh).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SYNC_SCRIPT="$REPO_ROOT/scripts/sync-shared-rules.sh"
  # Temp dir for isolated fixture files
  TMP_DIR="$(mktemp -d)"
  # Mirror the expected agents dir layout inside TMP_DIR
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# --- Syntax / presence ---

@test "sync-shared-rules.sh: script file exists" {
  [ -f "$SYNC_SCRIPT" ]
}

@test "sync-shared-rules.sh: passes bash -n syntax check" {
  run bash -n "$SYNC_SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Error handling ---

@test "sync-shared-rules.sh: exits non-zero and prints error when _shared/<role>.md is missing" {
  # Set up a minimal agent def that references a shared file that does not exist
  mkdir -p "$TMP_DIR/.claude/agents"
  cat > "$TMP_DIR/.claude/agents/testbot.md" <<'EOF'
---
name: testbot
role_slot: nonexistent-role
---

# About Testbot

Some per-agent content.

<!-- include: _shared/nonexistent-role.md -->
EOF

  # Script must exit with non-zero and print an error message to stderr
  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "nonexistent-role" ]] || [[ "$output" =~ "missing" ]] || [[ "$output" =~ "not found" ]]
}

@test "sync-shared-rules.sh: skips agent with warning when no include marker present" {
  # Agent file with no <!-- include: --> marker — should be skipped with a warning
  mkdir -p "$TMP_DIR/.claude/agents"
  cat > "$TMP_DIR/.claude/agents/nomarker.md" <<'EOF'
---
name: nomarker
role_slot: builder
---

# About Nomarker

No include marker in this file.
EOF
  cat > "$TMP_DIR/.claude/agents/_shared/builder.md" <<'EOF'
## Shared builder rules

- Build clean code
EOF

  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  # Should exit 0 (skip is not fatal)
  [ "$status" -eq 0 ]
  # Should emit a warning about the missing marker
  [[ "$output" =~ "warn" ]] || [[ "$output" =~ "skip" ]] || [[ "$output" =~ "no include marker" ]]
}

# --- Core inlining behavior ---

@test "sync-shared-rules.sh: inlines shared content below include marker" {
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
  cat > "$TMP_DIR/.claude/agents/_shared/builder.md" <<'EOF'
## Shared Builder Rules

- Build clean code
- Follow patterns
EOF

  cat > "$TMP_DIR/.claude/agents/jayce.md" <<'EOF'
---
name: jayce
role_slot: builder
tier: normal
pair_mate: viktor
---

# About Jayce

Normal-track builder, greenfield work.

<!-- include: _shared/builder.md -->
Old content to be replaced.
Extra old content.
EOF

  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]

  # The file should now contain the shared content after the include marker
  run grep -c "Shared Builder Rules" "$TMP_DIR/.claude/agents/jayce.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "sync-shared-rules.sh: preserves per-agent header (frontmatter + About section) unchanged" {
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
  cat > "$TMP_DIR/.claude/agents/_shared/builder.md" <<'EOF'
## Shared Rules

- Rule one
EOF

  cat > "$TMP_DIR/.claude/agents/jayce.md" <<'EOF'
---
name: jayce
role_slot: builder
tier: normal
pair_mate: viktor
---

# About Jayce

Unique per-agent personality text.

<!-- include: _shared/builder.md -->
Old shared content.
EOF

  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]

  # The About section must still be present
  run grep "Unique per-agent personality text" "$TMP_DIR/.claude/agents/jayce.md"
  [ "$status" -eq 0 ]

  # The frontmatter must still be present
  run grep "name: jayce" "$TMP_DIR/.claude/agents/jayce.md"
  [ "$status" -eq 0 ]
}

@test "sync-shared-rules.sh: old content below include marker is fully replaced" {
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
  cat > "$TMP_DIR/.claude/agents/_shared/builder.md" <<'EOF'
## New Shared Content

- New rule
EOF

  cat > "$TMP_DIR/.claude/agents/jayce.md" <<'EOF'
---
name: jayce
role_slot: builder
---

# About Jayce

Per-agent intro.

<!-- include: _shared/builder.md -->
## Old Shared Content

- Old rule that must be gone
EOF

  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]

  # Old content must be gone
  run grep "Old rule that must be gone" "$TMP_DIR/.claude/agents/jayce.md"
  [ "$status" -ne 0 ]
}

@test "sync-shared-rules.sh: idempotent — running twice produces identical output" {
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
  cat > "$TMP_DIR/.claude/agents/_shared/builder.md" <<'EOF'
## Shared Rules

- Build clean code
EOF

  cat > "$TMP_DIR/.claude/agents/jayce.md" <<'EOF'
---
name: jayce
role_slot: builder
---

# About Jayce

Per-agent content.

<!-- include: _shared/builder.md -->
EOF

  bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  first_hash="$(md5sum "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null || md5 -q "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null)"

  bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  second_hash="$(md5sum "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null || md5 -q "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null)"

  [ "$first_hash" = "$second_hash" ]
}

@test "sync-shared-rules.sh: handles multiple agents in the same _shared role" {
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
  cat > "$TMP_DIR/.claude/agents/_shared/builder.md" <<'EOF'
## Shared Builder Rules

- Build clean code
EOF

  # Two agents sharing the same role
  cat > "$TMP_DIR/.claude/agents/jayce.md" <<'EOF'
---
name: jayce
role_slot: builder
tier: normal
---

# About Jayce

Normal track.

<!-- include: _shared/builder.md -->
EOF

  cat > "$TMP_DIR/.claude/agents/viktor.md" <<'EOF'
---
name: viktor
role_slot: builder
tier: complex
---

# About Viktor

Complex track.

<!-- include: _shared/builder.md -->
EOF

  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]

  # Both files should have the shared content
  run grep "Shared Builder Rules" "$TMP_DIR/.claude/agents/jayce.md"
  [ "$status" -eq 0 ]
  run grep "Shared Builder Rules" "$TMP_DIR/.claude/agents/viktor.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T7a — depth-2 nested-include resolution
# xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
# All four cases below are expected to FAIL until T7b implements pass-2.
# ---------------------------------------------------------------------------

# Helper: build a minimal fixture tree with:
#   _shared/feedback-trigger.md  — the nested leaf
#   _shared/<role>.md            — includes feedback-trigger.md
#   <agent>.md                   — includes _shared/<role>.md
# Writes into TMP_DIR.
_make_nested_fixture() {
  local agents_dir="$1"
  local role="${2:-builder}"
  local agent_name="${3:-jayce}"
  local trigger_content="${4:-Feedback trigger sentinel line.}"

  mkdir -p "$agents_dir/_shared"

  # Leaf (depth-2 target): feedback-trigger.md
  printf '## Feedback trigger\n\n%s\n' "$trigger_content" \
    > "$agents_dir/_shared/feedback-trigger.md"

  # Intermediate shared role file: carries an include marker for feedback-trigger
  printf '## Shared %s rules\n\nRole rule line.\n\n<!-- include: _shared/feedback-trigger.md -->\n' \
    "$role" > "$agents_dir/_shared/${role}.md"

  # Agent def: carries include marker for the role file
  printf -- '---\nname: %s\nrole_slot: %s\n---\n\n# About %s\n\nPer-agent intro.\n\n<!-- include: _shared/%s.md -->\n' \
    "$agent_name" "$role" "$agent_name" "$role" \
    > "$agents_dir/${agent_name}.md"
}

# (a) depth-2 idempotency on clean tree — zero diff after two runs
@test "sync-shared-rules.sh [T7a-a]: depth-2 idempotency — two runs produce identical agent def" {
  # xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
  # Expected to fail until T7b implements pass-2 nested-include resolution.
  _make_nested_fixture "$TMP_DIR/.claude/agents"

  bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  first_hash="$(md5sum "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null \
    || md5 -q "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null)"

  bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  second_hash="$(md5sum "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null \
    || md5 -q "$TMP_DIR/.claude/agents/jayce.md" 2>/dev/null)"

  if [ "$first_hash" != "$second_hash" ]; then
    printf '%s\n' "depth-2 idempotency FAIL: agent def changed on second run" >&2
    return 1
  fi
}

# (a) continued — agent def must contain feedback-trigger content inlined (not just the marker)
@test "sync-shared-rules.sh [T7a-a2]: depth-2 sync — agent def contains inlined feedback-trigger content after one run" {
  # xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
  # Correct depth-2 resolution: after one run, agent def should contain the trigger CONTENT,
  # and must NOT contain a bare <!-- include: _shared/feedback-trigger.md --> marker.
  _make_nested_fixture "$TMP_DIR/.claude/agents"

  bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"

  # Must contain the trigger sentinel line (inlined content)
  if ! grep -q "Feedback trigger sentinel line" "$TMP_DIR/.claude/agents/jayce.md"; then
    printf '%s\n' "depth-2 content FAIL: trigger sentinel not found in jayce.md after one sync run" >&2
    return 1
  fi

  # Must NOT still contain a bare include marker for feedback-trigger
  if grep -q '<!-- include: _shared/feedback-trigger.md -->' "$TMP_DIR/.claude/agents/jayce.md"; then
    printf '%s\n' "depth-2 content FAIL: bare feedback-trigger include marker still present in jayce.md (nested include not resolved)" >&2
    return 1
  fi
}

# (b) one-line edit to _shared/feedback-trigger.md propagates to all 10 role files
#     AND to every paired agent def carrying the role include.
#     Fixture uses 3 roles + 3 agents (representative sample; real run covers 10).
@test "sync-shared-rules.sh [T7a-b]: feedback-trigger edit propagates through role files into agent defs" {
  # xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
  mkdir -p "$TMP_DIR/.claude/agents/_shared"

  # feedback-trigger.md — initial content
  printf '## Feedback trigger\n\nInitial trigger line.\n' \
    > "$TMP_DIR/.claude/agents/_shared/feedback-trigger.md"

  # Three role files, each with a nested include marker
  for role in builder architect test-impl; do
    printf '## Shared %s rules\n\nRole rule.\n\n<!-- include: _shared/feedback-trigger.md -->\n' \
      "$role" > "$TMP_DIR/.claude/agents/_shared/${role}.md"
  done

  # Three agent defs, one per role
  for pair in "jayce builder" "azir architect" "xayah test-impl"; do
    agent="${pair%% *}"
    role="${pair##* }"
    printf -- '---\nname: %s\nrole_slot: %s\n---\n\n# About %s\n\nPer-agent intro.\n\n<!-- include: _shared/%s.md -->\n' \
      "$agent" "$role" "$agent" "$role" \
      > "$TMP_DIR/.claude/agents/${agent}.md"
  done

  # First sync — establish baseline
  bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"

  # Edit feedback-trigger.md by one line
  printf '## Feedback trigger\n\nEDITED trigger line — propagation test.\n' \
    > "$TMP_DIR/.claude/agents/_shared/feedback-trigger.md"

  # Second sync — must propagate the change
  bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"

  # All three agent defs must contain the edited trigger text
  # AND must NOT contain a raw <!-- include: _shared/feedback-trigger.md --> marker
  # (which would indicate the nested include was NOT resolved — only inlined-then-leaked).
  local fail=0
  for agent in jayce azir xayah; do
    if ! grep -q "EDITED trigger line" "$TMP_DIR/.claude/agents/${agent}.md"; then
      printf '%s\n' "propagation FAIL: EDITED trigger line missing from ${agent}.md" >&2
      fail=1
    fi
    # A correct depth-2 resolution must NOT leave a bare include marker for feedback-trigger
    # in the agent def — that marker belongs inside the role file only.
    if grep -q '<!-- include: _shared/feedback-trigger.md -->' "$TMP_DIR/.claude/agents/${agent}.md"; then
      printf '%s\n' "propagation FAIL: bare feedback-trigger include marker found in ${agent}.md (depth-2 not resolved cleanly)" >&2
      fail=1
    fi
  done
  if [ "$fail" -eq 1 ]; then
    return 1
  fi
}

# (c) depth-3 include emits a clear error referencing §OQ2
@test "sync-shared-rules.sh [T7a-c]: depth-3 include emits error referencing OQ2" {
  # xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
  mkdir -p "$TMP_DIR/.claude/agents/_shared"

  # depth-3 chain: agent → role → feedback-trigger → another-nested
  printf '## Another nested file\n\nDepth-3 content.\n' \
    > "$TMP_DIR/.claude/agents/_shared/another-nested.md"

  # feedback-trigger.md includes a third-level file (depth-3)
  printf '## Feedback trigger\n\nTrigger content.\n\n<!-- include: _shared/another-nested.md -->\n' \
    > "$TMP_DIR/.claude/agents/_shared/feedback-trigger.md"

  # Role file includes feedback-trigger (depth-2)
  printf '## Shared builder rules\n\nRole rule.\n\n<!-- include: _shared/feedback-trigger.md -->\n' \
    > "$TMP_DIR/.claude/agents/_shared/builder.md"

  # Agent def includes role (depth-1)
  printf -- '---\nname: jayce\nrole_slot: builder\n---\n\n# About Jayce\n\nPer-agent intro.\n\n<!-- include: _shared/builder.md -->\n' \
    > "$TMP_DIR/.claude/agents/jayce.md"

  # Must exit non-zero and mention OQ2 or "depth" or "nested" limit
  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  if [ "$status" -eq 0 ]; then
    printf '%s\n' "depth-3 check FAIL: expected non-zero exit but got 0" >&2
    return 1
  fi
  if ! printf '%s' "$output" | grep -qi "OQ2\|depth\|nested\|limit"; then
    printf '%s\n' "depth-3 check FAIL: error output did not reference OQ2 or depth limit" >&2
    return 1
  fi
}

# (d) lint-subagent-rules verifies each _shared/<role>.md carries exactly ONE
#     <!-- include: _shared/feedback-trigger.md --> marker (§D4.2).
#     Duplicate-marker fixture trips the lint.
@test "lint-subagent-rules.sh [T7a-d]: duplicate feedback-trigger marker in shared role file trips lint" {
  # xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
  LINT_SCRIPT="$REPO_ROOT/scripts/lint-subagent-rules.sh"

  mkdir -p "$TMP_DIR/.claude/agents/_shared"

  # feedback-trigger.md — the leaf
  printf '## Feedback trigger\n\nTrigger sentinel.\n' \
    > "$TMP_DIR/.claude/agents/_shared/feedback-trigger.md"

  # Role file with TWO include markers (duplicate — must fail lint)
  printf '## Shared builder rules\n\nRole rule.\n\n<!-- include: _shared/feedback-trigger.md -->\nExtra text.\n<!-- include: _shared/feedback-trigger.md -->\n' \
    > "$TMP_DIR/.claude/agents/_shared/builder.md"

  # Run lint against the temp agents dir
  run bash "$LINT_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  if [ "$status" -eq 0 ]; then
    printf '%s\n' "lint duplicate-marker FAIL: expected non-zero exit for duplicate marker but lint passed" >&2
    return 1
  fi
}

# (d) complementary — single marker passes lint
@test "lint-subagent-rules.sh [T7a-d2]: exactly one feedback-trigger marker in shared role file passes lint" {
  # xfail: plans/approved/personal/2026-04-21-agent-feedback-system.md T7a
  LINT_SCRIPT="$REPO_ROOT/scripts/lint-subagent-rules.sh"

  mkdir -p "$TMP_DIR/.claude/agents/_shared"

  printf '## Feedback trigger\n\nTrigger sentinel.\n' \
    > "$TMP_DIR/.claude/agents/_shared/feedback-trigger.md"

  # Role file with exactly one marker — must pass lint
  printf '## Shared builder rules\n\nRole rule.\n\n<!-- include: _shared/feedback-trigger.md -->\n' \
    > "$TMP_DIR/.claude/agents/_shared/builder.md"

  run bash "$LINT_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "lint single-marker FAIL: expected zero exit but lint rejected a valid single-marker file" >&2
    return 1
  fi
}
