# xfail: §D4.3 — scripts/sync-shared-rules.sh
# (plans/in-progress/2026-04-20-agent-pair-taxonomy.md §D4.3)
# Bats tests expected to fail until sync-shared-rules.sh is implemented.
# Run with: bats scripts/__tests__/sync-shared-rules.xfail.bats

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
