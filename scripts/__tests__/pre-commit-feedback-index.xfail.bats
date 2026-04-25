# xfail: TT3 — pre-commit hook for feedback INDEX regeneration
# Plan: plans/approved/personal/2026-04-21-agent-feedback-system.md §Test plan TT3
# All tests expected to FAIL until T3 implements scripts/hooks/pre-commit-feedback-index.sh.
# Run with: bats scripts/__tests__/pre-commit-feedback-index.xfail.bats
#
# Guards:
#   (a) Commit touching feedback file with valid frontmatter → INDEX regenerated + staged in same commit
#   (b) Commit touching feedback file with malformed frontmatter → hook exits non-zero, stderr cites §D1
#   (c) Invariant 1 audit — rogue feedback file whose introducing commit prefix is not
#       "chore: feedback" or "chore: feedback sweep" is detected by feedback-index.sh
#       --check --audit-history mode
#   Also verifies: hooks installed by scripts/install-hooks.sh without manual steps

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/pre-commit-feedback-index.sh"
  INSTALL_HOOKS="$REPO_ROOT/scripts/install-hooks.sh"
  INDEX_SCRIPT="$REPO_ROOT/scripts/feedback-index.sh"
  FIXTURES_VALID="$REPO_ROOT/scripts/__tests__/fixtures/feedback/valid"
  FIXTURES_MALFORMED="$REPO_ROOT/scripts/__tests__/fixtures/feedback/malformed"
  TMP_DIR="$(mktemp -d)"

  # Build a minimal git repo for hook testing
  TMP_GIT="$TMP_DIR/test-repo"
  mkdir -p "$TMP_GIT/feedback"
  git -C "$TMP_GIT" init -q
  git -C "$TMP_GIT" config user.email "test@example.com"
  git -C "$TMP_GIT" config user.name "Test"
  # Initial commit so HEAD exists
  touch "$TMP_GIT/.gitkeep"
  git -C "$TMP_GIT" add .gitkeep
  git -C "$TMP_GIT" commit -q -m "chore: init"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Script presence + syntax
# ---------------------------------------------------------------------------

@test "TT3: pre-commit-feedback-index.sh exists" {
  # xfail: T3 not implemented yet
  [ -f "$HOOK_SCRIPT" ]
}

@test "TT3: pre-commit-feedback-index.sh passes bash -n syntax check" {
  # xfail: T3 not implemented yet
  [ -f "$HOOK_SCRIPT" ]
  run bash -n "$HOOK_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "TT3: scripts/install-hooks.sh mentions pre-commit-feedback-index" {
  # xfail: T3 must wire into install-hooks.sh
  [ -f "$INSTALL_HOOKS" ]
  run grep "pre-commit-feedback-index" "$INSTALL_HOOKS"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (a) Valid feedback file commit: INDEX is regenerated and auto-staged
# ---------------------------------------------------------------------------

@test "TT3 (a): commit with valid feedback frontmatter succeeds and INDEX is staged" {
  # xfail: T3 not implemented yet
  [ -f "$HOOK_SCRIPT" ] && [ -f "$INDEX_SCRIPT" ]

  # Copy a valid feedback fixture into the test repo
  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" \
     "$TMP_GIT/feedback/"
  git -C "$TMP_GIT" add feedback/

  # Install the hook manually into the temp repo
  mkdir -p "$TMP_GIT/.git/hooks"
  cp "$HOOK_SCRIPT" "$TMP_GIT/.git/hooks/pre-commit"
  chmod +x "$TMP_GIT/.git/hooks/pre-commit"

  # Copy the index script so the hook can call it
  cp "$INDEX_SCRIPT" "$TMP_GIT/scripts-feedback-index.sh"
  chmod +x "$TMP_GIT/scripts-feedback-index.sh"

  run git -C "$TMP_GIT" commit -m "chore: feedback — orianna-signing-latency"
  [ "$status" -eq 0 ]

  # INDEX.md must have been committed as part of this commit
  run git -C "$TMP_GIT" show --name-only HEAD
  [[ "$output" =~ "feedback/INDEX.md" ]]
}

# ---------------------------------------------------------------------------
# (b) Malformed feedback file commit: hook exits non-zero, cites §D1
# ---------------------------------------------------------------------------

@test "TT3 (b): commit with malformed frontmatter (missing severity) is rejected by hook" {
  # xfail: T3 not implemented yet
  [ -f "$HOOK_SCRIPT" ] && [ -f "$INDEX_SCRIPT" ]

  cp "$FIXTURES_MALFORMED/missing-severity.md" \
     "$TMP_GIT/feedback/"
  git -C "$TMP_GIT" add feedback/

  mkdir -p "$TMP_GIT/.git/hooks"
  cp "$HOOK_SCRIPT" "$TMP_GIT/.git/hooks/pre-commit"
  chmod +x "$TMP_GIT/.git/hooks/pre-commit"
  cp "$INDEX_SCRIPT" "$TMP_GIT/scripts-feedback-index.sh"
  chmod +x "$TMP_GIT/scripts-feedback-index.sh"

  run git -C "$TMP_GIT" commit -m "chore: feedback — missing-severity"
  # Hook must block the commit
  [ "$status" -ne 0 ]
  # Error output must cite §D1 or name the offending field
  [[ "$output" =~ "severity" ]] || [[ "$output" =~ "D1" ]] || [[ "$output" =~ "schema" ]]
}

@test "TT3 (b): commit with invalid category value is rejected by hook and names 'category' in output" {
  # xfail: T3 not implemented yet
  [ -f "$HOOK_SCRIPT" ] && [ -f "$INDEX_SCRIPT" ]

  cp "$FIXTURES_MALFORMED/invalid-category.md" \
     "$TMP_GIT/feedback/"
  git -C "$TMP_GIT" add feedback/

  mkdir -p "$TMP_GIT/.git/hooks"
  cp "$HOOK_SCRIPT" "$TMP_GIT/.git/hooks/pre-commit"
  chmod +x "$TMP_GIT/.git/hooks/pre-commit"
  cp "$INDEX_SCRIPT" "$TMP_GIT/scripts-feedback-index.sh"
  chmod +x "$TMP_GIT/scripts-feedback-index.sh"

  run git -C "$TMP_GIT" commit -m "chore: feedback — invalid-category"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "category" ]] || [[ "$output" =~ "D1" ]]
}

@test "TT3 (b): commit with missing ## What went wrong section is rejected by hook" {
  # xfail: T3 not implemented yet
  [ -f "$HOOK_SCRIPT" ] && [ -f "$INDEX_SCRIPT" ]

  cp "$FIXTURES_MALFORMED/missing-what-went-wrong.md" \
     "$TMP_GIT/feedback/"
  git -C "$TMP_GIT" add feedback/

  mkdir -p "$TMP_GIT/.git/hooks"
  cp "$HOOK_SCRIPT" "$TMP_GIT/.git/hooks/pre-commit"
  chmod +x "$TMP_GIT/.git/hooks/pre-commit"
  cp "$INDEX_SCRIPT" "$TMP_GIT/scripts-feedback-index.sh"
  chmod +x "$TMP_GIT/scripts-feedback-index.sh"

  run git -C "$TMP_GIT" commit -m "chore: feedback — missing-section"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "What went wrong" ]] || [[ "$output" =~ "what went wrong" ]] || [[ "$output" =~ "D1" ]]
}

# ---------------------------------------------------------------------------
# (b) Hook must not use --no-verify anywhere (CLAUDE.md rule 14)
# ---------------------------------------------------------------------------

@test "TT3 (b): pre-commit-feedback-index.sh does not contain --no-verify" {
  # xfail: T3 not implemented yet
  [ -f "$HOOK_SCRIPT" ]
  run grep -- "--no-verify" "$HOOK_SCRIPT"
  # Must NOT be found
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# (c) Invariant 1 audit: --check --audit-history detects rogue entries
#     (entries whose introducing commit prefix is not "chore: feedback*")
# ---------------------------------------------------------------------------

@test "TT3 (c): --check --audit-history detects rogue feedback file with wrong commit prefix" {
  # xfail: T2 --audit-history mode + T3 not implemented yet
  [ -f "$INDEX_SCRIPT" ]

  # Create a rogue feedback entry committed without the correct prefix
  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" \
     "$TMP_GIT/feedback/2099-01-01-rogue.md"
  git -C "$TMP_GIT" add feedback/
  # Bypass the hook for this test by not having the hook installed yet
  git -C "$TMP_GIT" commit -q -m "feat: some feature — not a feedback commit"

  # Now audit: this entry should be flagged because its commit prefix is "feat:", not "chore: feedback*"
  run bash "$INDEX_SCRIPT" --check --audit-history --dir "$TMP_GIT/feedback"
  # Must exit non-zero and name the rogue file or wrong prefix
  [ "$status" -ne 0 ]
  [[ "$output" =~ "rogue" ]] || [[ "$output" =~ "chore: feedback" ]] || [[ "$output" =~ "prefix" ]] || [[ "$output" =~ "audit" ]]
}

@test "TT3 (c): --check --audit-history passes on entries committed with correct prefix" {
  # xfail: T2 --audit-history mode not implemented yet
  [ -f "$INDEX_SCRIPT" ]

  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" \
     "$TMP_GIT/feedback/"
  git -C "$TMP_GIT" add feedback/
  git -C "$TMP_GIT" commit -q -m "chore: feedback — orianna-signing-latency"

  run bash "$INDEX_SCRIPT" --check --audit-history --dir "$TMP_GIT/feedback"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# install-hooks.sh installs the hook without manual steps
# ---------------------------------------------------------------------------

@test "TT3: fresh install-hooks.sh in a clean repo installs pre-commit-feedback-index hook" {
  # xfail: T3 must register the hook in scripts/install-hooks.sh
  [ -f "$INSTALL_HOOKS" ]
  [ -f "$HOOK_SCRIPT" ]

  # Simulate a clean repo with only the scripts and hooks dirs copied
  mkdir -p "$TMP_DIR/clean-repo/scripts/hooks"
  cp "$HOOK_SCRIPT" "$TMP_DIR/clean-repo/scripts/hooks/"
  cp "$INSTALL_HOOKS" "$TMP_DIR/clean-repo/scripts/"
  git -C "$TMP_DIR/clean-repo" init -q
  mkdir -p "$TMP_DIR/clean-repo/.git/hooks"

  run bash "$TMP_DIR/clean-repo/scripts/install-hooks.sh"
  # After install, the hook dispatcher or symlink should exist
  [ -f "$TMP_DIR/clean-repo/.git/hooks/pre-commit" ] || \
    [ -L "$TMP_DIR/clean-repo/.git/hooks/pre-commit" ] || \
    grep -q "pre-commit-feedback-index" "$TMP_DIR/clean-repo/.git/hooks/pre-commit" 2>/dev/null
}
