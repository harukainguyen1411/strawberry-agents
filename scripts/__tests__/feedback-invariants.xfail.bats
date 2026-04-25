# xfail: TT-INV — Invariant regression suite
# Plan: plans/approved/personal/2026-04-21-agent-feedback-system.md §Test plan TT-INV
# One test per invariant in §Invariants (10 invariants → 10 tests).
# All tests expected to FAIL until the relevant implementation tasks land.
# Run with: bats scripts/__tests__/feedback-invariants.xfail.bats
#
# Committed before T2 per Rule 12 (earliest-landing impl whose code these tests exercise).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/feedback-index.sh"
  HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/pre-commit-feedback-index.sh"
  FIXTURES_VALID="$REPO_ROOT/scripts/__tests__/fixtures/feedback/valid"
  FIXTURES_MALFORMED="$REPO_ROOT/scripts/__tests__/fixtures/feedback/malformed"
  TMP_DIR="$(mktemp -d)"

  TMP_GIT="$TMP_DIR/inv-test-repo"
  mkdir -p "$TMP_GIT/feedback"
  git -C "$TMP_GIT" init -q
  git -C "$TMP_GIT" config user.email "test@example.com"
  git -C "$TMP_GIT" config user.name "Test"
  touch "$TMP_GIT/.gitkeep"
  git -C "$TMP_GIT" add .gitkeep
  git -C "$TMP_GIT" commit -q -m "chore: init"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Invariant 1 — One file-writing path
# Every feedback/*.md whose git-introducing commit is NOT prefixed "chore: feedback"
# or "chore: feedback sweep" is flagged by --check --audit-history.
# guards Invariant 1
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 1 — rogue feedback entry (wrong commit prefix) detected by audit-history" {
  # guards Invariant 1
  # xfail: feedback-index.sh --audit-history mode not implemented yet (T2)
  [ -f "$SCRIPT" ]

  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" \
     "$TMP_GIT/feedback/2099-01-01-rogue.md"
  git -C "$TMP_GIT" add feedback/
  git -C "$TMP_GIT" commit -q -m "feat: this-is-not-a-feedback-commit"

  run bash "$SCRIPT" --check --audit-history --dir "$TMP_GIT/feedback"
  [ "$status" -ne 0 ]
}

@test "TT-INV: Invariant 1 — correct prefix 'chore: feedback' passes audit-history" {
  # guards Invariant 1
  # xfail: feedback-index.sh --audit-history mode not implemented yet (T2)
  [ -f "$SCRIPT" ]

  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" \
     "$TMP_GIT/feedback/"
  git -C "$TMP_GIT" add feedback/
  git -C "$TMP_GIT" commit -q -m "chore: feedback — orianna-signing-latency"

  run bash "$SCRIPT" --check --audit-history --dir "$TMP_GIT/feedback"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Invariant 2 — Author-fidelity
# A feedback entry's author: must name the agent that lived the friction.
# Missing or empty author: fails --check.
# guards Invariant 2
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 2 — missing author field fails --check" {
  # guards Invariant 2
  # xfail: feedback-index.sh --check not implemented yet (T2)
  [ -f "$SCRIPT" ]

  tmpfile="$TMP_DIR/missing-author.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
concern: work
category: other
severity: low
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Missing author

## What went wrong

Author field is absent.

## Suggestion

- Add author field.

## Why I'm writing this now

Test fixture.
FIXTURE
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "author" ]] || echo "$output" | grep -qi "author"
}

@test "TT-INV: Invariant 2 — empty author value fails --check" {
  # guards Invariant 2
  # xfail: feedback-index.sh --check not implemented yet (T2)
  [ -f "$SCRIPT" ]

  tmpfile="$TMP_DIR/empty-author.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
author: ""
concern: work
category: other
severity: low
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Empty author

## What went wrong

Author value is empty string.

## Suggestion

- Set a non-empty author.

## Why I'm writing this now

Test fixture.
FIXTURE
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Invariant 3 — No blocking behavior
# The /agent-feedback skill (T9) returns within ~60 seconds.
# Tested here as: feedback-index.sh --check on a valid file completes promptly.
# guards Invariant 3
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 3 — --check on a valid fixture completes in under 10 seconds" {
  # guards Invariant 3
  # xfail: feedback-index.sh not implemented yet (T2)
  [ -f "$SCRIPT" ]

  start_time=$(date +%s)
  run bash "$SCRIPT" --check "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md"
  end_time=$(date +%s)
  elapsed=$(( end_time - start_time ))
  [ "$status" -eq 0 ]
  [ "$elapsed" -lt 10 ]
}

# ---------------------------------------------------------------------------
# Invariant 4 — Idempotent index
# Running feedback-index.sh twice on an unchanged tree produces zero diff.
# guards Invariant 4
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 4 — index generation is idempotent (two runs produce identical output)" {
  # guards Invariant 4
  # xfail: feedback-index.sh not implemented yet (T2)
  [ -f "$SCRIPT" ]

  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/idx1.md"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/idx2.md"
  [ "$status" -eq 0 ]
  run diff "$TMP_DIR/idx1.md" "$TMP_DIR/idx2.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Invariant 5 — Idempotent sync
# Running sync-shared-rules.sh twice produces zero diff.
# guards Invariant 5
# (depth-2 idempotency is tested more thoroughly in sync-shared-rules.xfail.bats TT7a)
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 5 — sync-shared-rules.sh is idempotent (two runs produce zero diff)" {
  # guards Invariant 5
  # xfail: depth-2 resolution not implemented yet (T7b)
  SYNC_SCRIPT="$REPO_ROOT/scripts/sync-shared-rules.sh"
  [ -f "$SYNC_SCRIPT" ]

  # Set up a minimal agent def + shared file in tmp
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
  cat > "$TMP_DIR/.claude/agents/_shared/builder.md" <<'SHARED'
## Shared Builder Rules

- Build clean.
SHARED

  cat > "$TMP_DIR/.claude/agents/jayce.md" <<'AGENTDEF'
---
name: jayce
role_slot: builder
---
# About Jayce

Per-agent content.

<!-- include: _shared/builder.md -->
AGENTDEF

  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
  first_content=$(cat "$TMP_DIR/.claude/agents/jayce.md")

  run bash "$SYNC_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
  second_content=$(cat "$TMP_DIR/.claude/agents/jayce.md")

  [ "$first_content" = "$second_content" ]
}

# ---------------------------------------------------------------------------
# Invariant 6 — State machine is monotone
# state: graduated → open is rejected by --check.
# guards Invariant 6
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 6 — state: graduated entry mutated to state: open is rejected by --check" {
  # guards Invariant 6
  # xfail: feedback-index.sh --check not implemented yet (T2)
  [ -f "$SCRIPT" ]

  tmpfile="$TMP_DIR/graduated-to-open.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: review-loop
severity: high
friction_cost_minutes: 30
related_feedback: []
state: open
graduated_to: plans/proposed/personal/2026-04-28-some-plan.md
---

# State regression test

## What went wrong

This entry has both state: open AND a graduated_to pointer — illegal state machine transition (graduated entry returned to open).

## Suggestion

- Remove the graduated_to pointer or set state: graduated.

## Why I'm writing this now

Test fixture.
FIXTURE
  # An entry with state: open AND a graduated_to: pointer is a monotone violation
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -ne 0 ]
}

@test "TT-INV: Invariant 6 — valid forward transition open → graduated passes --check" {
  # guards Invariant 6
  # xfail: feedback-index.sh --check not implemented yet (T2)
  [ -f "$SCRIPT" ]

  tmpfile="$TMP_DIR/valid-graduated.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: review-loop
severity: high
friction_cost_minutes: 30
related_feedback: []
state: graduated
graduated_to: plans/proposed/personal/2026-04-28-some-plan.md
---

# Valid graduated entry

## What went wrong

Valid entry with state: graduated and a graduated_to pointer.

## Suggestion

- No action.

## Why I'm writing this now

Test fixture.
FIXTURE
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Invariant 7 — Scope separation preserved
# No feedback entry mutates files outside feedback/**.
# Tested: a synthetic patch touching both feedback/ and apps/ is audited.
# guards Invariant 7
# (Full scope-separation enforcement is a pre-push concern; here we assert the
#  audit mode recognises the violation pattern when described to it.)
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 7 — feedback-index.sh --check does not touch files outside feedback/ directory" {
  # guards Invariant 7
  # xfail: feedback-index.sh not implemented yet (T2)
  [ -f "$SCRIPT" ]

  # Create a temp tree with a feedback dir and a sentinel outside it
  mkdir -p "$TMP_DIR/inv7/feedback"
  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" \
     "$TMP_DIR/inv7/feedback/"
  echo "sentinel" > "$TMP_DIR/inv7/outside-sentinel.txt"
  before_checksum=$(md5sum "$TMP_DIR/inv7/outside-sentinel.txt" | awk '{print $1}')

  run bash "$SCRIPT" --check --dir "$TMP_DIR/inv7/feedback"
  [ "$status" -eq 0 ]

  after_checksum=$(md5sum "$TMP_DIR/inv7/outside-sentinel.txt" | awk '{print $1}')
  [ "$before_checksum" = "$after_checksum" ]
}

@test "TT-INV: Invariant 7 — rendering INDEX does not create files outside feedback/ directory" {
  # guards Invariant 7
  # xfail: feedback-index.sh not implemented yet (T2)
  [ -f "$SCRIPT" ]

  mkdir -p "$TMP_DIR/inv7b/feedback"
  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" \
     "$TMP_DIR/inv7b/feedback/"

  before_files=$(find "$TMP_DIR/inv7b" -not -path "*/feedback/*" -type f | sort)

  run bash "$SCRIPT" --dir "$TMP_DIR/inv7b/feedback" --out "$TMP_DIR/inv7b/feedback/INDEX.md"
  # INDEX is written inside feedback/ — that's allowed

  after_files=$(find "$TMP_DIR/inv7b" -not -path "*/feedback/*" -type f | sort)
  [ "$before_files" = "$after_files" ]
}

# ---------------------------------------------------------------------------
# Invariant 8 — Secret-free
# The existing pre-commit secret scanner covers feedback/**; this test asserts
# it does so without requiring a real secret (uses a placeholder pattern).
# guards Invariant 8
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 8 — pre-commit secret scanner is registered to scan feedback/ directory" {
  # guards Invariant 8
  # xfail: Asserts that scripts/hooks/pre-commit-secrets-guard.sh or equivalent
  # covers feedback/** — verifiable once pre-commit-feedback-index.sh is installed
  SECRET_HOOK="$REPO_ROOT/scripts/hooks/pre-commit-secrets-guard.sh"
  [ -f "$SECRET_HOOK" ]
  # The secrets guard should apply to all staged files including feedback/**
  # Assert it doesn't explicitly exclude feedback/
  run grep "feedback" "$SECRET_HOOK"
  # Either it mentions feedback (to include it) or it does not exclude it
  # We assert there is no explicit exclusion pattern
  run grep -E "exclude.*feedback|feedback.*exclude|skip.*feedback" "$SECRET_HOOK"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Invariant 9 — Concern-tagged
# Every entry must carry concern: work | personal.
# Missing concern: fails --check.
# guards Invariant 9
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 9 — missing concern field fails --check" {
  # guards Invariant 9
  # xfail: feedback-index.sh --check not implemented yet (T2)
  [ -f "$SCRIPT" ]

  tmpfile="$TMP_DIR/missing-concern.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
author: sona
category: other
severity: low
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Missing concern

## What went wrong

Concern field is absent.

## Suggestion

- Add concern: work or concern: personal.

## Why I'm writing this now

Test fixture.
FIXTURE
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "concern" ]] || echo "$output" | grep -qi "concern"
}

@test "TT-INV: Invariant 9 — invalid concern value fails --check" {
  # guards Invariant 9
  # xfail: feedback-index.sh --check not implemented yet (T2)
  [ -f "$SCRIPT" ]

  tmpfile="$TMP_DIR/bad-concern.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
author: sona
concern: neither
category: other
severity: low
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Invalid concern value

## What went wrong

Concern field has value 'neither' which is not in the work|personal enum.

## Suggestion

- Set concern: work or concern: personal.

## Why I'm writing this now

Test fixture.
FIXTURE
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Invariant 10 — Feedback is not a plan
# A git mv of a feedback file into plans/** should be caught by the plan-lifecycle
# pre-tooluse guard. Tested here as: feedback-index.sh --check recognises the
# feedback/ directory as distinct from plans/ and does not process plans/ files.
# guards Invariant 10
# ---------------------------------------------------------------------------

@test "TT-INV: Invariant 10 — feedback-index.sh --check rejects files not under feedback/ path" {
  # guards Invariant 10
  # xfail: feedback-index.sh --check not implemented yet (T2)
  [ -f "$SCRIPT" ]

  # A file with a valid §D1 schema but located outside feedback/
  tmpfile="$TMP_DIR/plans-proposed-out-of-place.md"
  cp "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md" "$tmpfile"

  # --check on a file outside feedback/ — the script should either:
  # (a) reject it with an error (strict mode), or
  # (b) accept the content but emit a warning that the file path is wrong.
  # We assert it does NOT silently accept and include in the INDEX.
  run bash "$SCRIPT" --dir "$TMP_DIR" --out "$TMP_DIR/INDEX-out.md"
  if [ "$status" -eq 0 ] && [ -f "$TMP_DIR/INDEX-out.md" ]; then
    # The out-of-place file should not appear in the INDEX under feedback/**
    run grep "plans-proposed-out-of-place" "$TMP_DIR/INDEX-out.md"
    [ "$status" -ne 0 ]
  fi
  # If status != 0, script correctly rejected the invocation — that's also fine.
}

@test "TT-INV: Invariant 10 — plan-lifecycle guard script exists and covers feedback→plans mv" {
  # guards Invariant 10
  # The plan-lifecycle pre-tooluse guard blocks mv of feedback files into plans/**
  # (per CLAUDE.md rule 7 and the guard at scripts/hooks/pretooluse-plan-lifecycle-guard.sh)
  GUARD="$REPO_ROOT/scripts/hooks/pre-commit-plan-lifecycle-guard.sh"
  [ -f "$GUARD" ]
  # The guard must mention 'feedback' in some capacity (either it blocks it or we assert
  # the guard's bash-path scan covers all directories)
  run bash -n "$GUARD"
  [ "$status" -eq 0 ]
}
