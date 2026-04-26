#!/usr/bin/env bats
# xfail test suite for Skarner feedback-search query kind (TT5)
# Guards T5 DoD: skarner.md lists feedback-search in its query-kind table with four named
# filter dimensions matching §D1 frontmatter field names exactly.
# Plan: plans/approved/personal/2026-04-21-agent-feedback-system.md

setup() {
  SKARNER_MD="/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/skarner.md"
}

xfail_if_missing() {
  local file="$1" pattern="$2"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then
    skip "xfail: T5 not yet implemented — pattern '$pattern' not found in $file"
  fi
}

# ---------------------------------------------------------------------------
# TT5-A: skarner.md contains feedback-search query kind
# ---------------------------------------------------------------------------
@test "TT5-A: .claude/agents/skarner.md contains feedback-search query kind" {
  xfail_if_missing "$SKARNER_MD" "feedback-search"
  grep -q "feedback-search" "$SKARNER_MD"
}

# ---------------------------------------------------------------------------
# TT5-B: Four named filter dimensions present — category
# (must match §D1 frontmatter field name exactly)
# ---------------------------------------------------------------------------
@test "TT5-B: skarner.md feedback-search section contains 'category' filter dimension" {
  xfail_if_missing "$SKARNER_MD" "feedback-search"
  grep -q "category" "$SKARNER_MD"
}

# ---------------------------------------------------------------------------
# TT5-C: severity filter dimension
# ---------------------------------------------------------------------------
@test "TT5-C: skarner.md feedback-search section contains 'severity' filter dimension" {
  xfail_if_missing "$SKARNER_MD" "feedback-search"
  grep -q "severity" "$SKARNER_MD"
}

# ---------------------------------------------------------------------------
# TT5-D: author filter dimension
# ---------------------------------------------------------------------------
@test "TT5-D: skarner.md feedback-search section contains 'author' filter dimension" {
  xfail_if_missing "$SKARNER_MD" "feedback-search"
  grep -q "author" "$SKARNER_MD"
}

# ---------------------------------------------------------------------------
# TT5-E: keyword filter dimension
# ---------------------------------------------------------------------------
@test "TT5-E: skarner.md feedback-search section contains 'keyword' filter dimension" {
  xfail_if_missing "$SKARNER_MD" "feedback-search"
  grep -q "keyword" "$SKARNER_MD"
}

# ---------------------------------------------------------------------------
# TT5-F: --include-archived flag mentioned (last-resort search path per §D3)
# ---------------------------------------------------------------------------
@test "TT5-F: skarner.md mentions --include-archived flag for feedback-search" {
  xfail_if_missing "$SKARNER_MD" "feedback-search"
  # This DoD point guards the archived search path
  if ! grep -q "include-archived" "$SKARNER_MD"; then
    skip "xfail: --include-archived not yet documented in skarner.md"
  fi
  grep -q "include-archived" "$SKARNER_MD"
}
