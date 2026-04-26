#!/usr/bin/env bats
# scripts/tests/test-qa-pipeline-doc-presence.bats
#
# T4 xfail — Test 4 from the plan §Test plan:
#   "test -f architecture/agent-network-v1/qa-pipeline.md returns 0.
#    Doc contains all four stage headings."
#
# Plan: plans/approved/personal/2026-04-25-structured-qa-pipeline.md §T4
# OQ-K3: inline grep assertion for stage headings; no separate bats file needed —
#         but per Rule 12 this xfail commit must precede the impl commit.
#
# xfail: file does not yet exist; both tests skip/fail until T4 impl lands the doc.
#
# Run: bats scripts/tests/test-qa-pipeline-doc-presence.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
DOC="$REPO_ROOT/architecture/agent-network-v1/qa-pipeline.md"

# ---------------------------------------------------------------------------
# T4-1 — doc file exists
# ---------------------------------------------------------------------------

@test "T4-1: architecture/agent-network-v1/qa-pipeline.md exists" {
  # xfail: file not yet authored (T4 impl pending)
  if [ ! -f "$DOC" ]; then
    skip "xfail — qa-pipeline.md not yet authored"
  fi
  [ -f "$DOC" ]
}

# ---------------------------------------------------------------------------
# T4-2 — doc contains exactly four ### Stage N headings
# ---------------------------------------------------------------------------

@test "T4-2: doc contains exactly four '### Stage' headings" {
  # xfail: file not yet authored (T4 impl pending)
  if [ ! -f "$DOC" ]; then
    skip "xfail — qa-pipeline.md not yet authored"
  fi
  count="$(grep -c '^### Stage' "$DOC")"
  [ "$count" -eq 4 ]
}

# ---------------------------------------------------------------------------
# T4-3 — doc cites Rule 16 and Rule 17
# ---------------------------------------------------------------------------

@test "T4-3: doc cites Rule 16 and Rule 17" {
  if [ ! -f "$DOC" ]; then
    skip "xfail — qa-pipeline.md not yet authored"
  fi
  grep -q 'Rule 16' "$DOC"
  grep -q 'Rule 17' "$DOC"
}

# ---------------------------------------------------------------------------
# T4-4 — doc cites the two-stage Swain ADR (qa-two-stage-architecture)
# ---------------------------------------------------------------------------

@test "T4-4: doc cites two-stage Swain ADR (qa-two-stage-architecture)" {
  if [ ! -f "$DOC" ]; then
    skip "xfail — qa-pipeline.md not yet authored"
  fi
  grep -q 'qa-two-stage-architecture' "$DOC"
}

# ---------------------------------------------------------------------------
# T4-5 — doc cites this ADR (structured-qa-pipeline)
# ---------------------------------------------------------------------------

@test "T4-5: doc cites this ADR slug (structured-qa-pipeline)" {
  if [ ! -f "$DOC" ]; then
    skip "xfail — qa-pipeline.md not yet authored"
  fi
  grep -q 'structured-qa-pipeline' "$DOC"
}

# ---------------------------------------------------------------------------
# T4-6 — doc cites plan-frontmatter.md
# ---------------------------------------------------------------------------

@test "T4-6: doc cites architecture/agent-network-v1/plan-frontmatter.md" {
  if [ ! -f "$DOC" ]; then
    skip "xfail — qa-pipeline.md not yet authored"
  fi
  grep -q 'plan-frontmatter' "$DOC"
}

# ---------------------------------------------------------------------------
# T4-7 — doc cites Karma v1 hook plan (akali-qa-discipline-hooks)
# ---------------------------------------------------------------------------

@test "T4-7: doc cites Karma v1 hook plan (akali-qa-discipline-hooks)" {
  if [ ! -f "$DOC" ]; then
    skip "xfail — qa-pipeline.md not yet authored"
  fi
  grep -q 'akali-qa-discipline-hooks' "$DOC"
}
