#!/usr/bin/env bash
# Sanity-grep test for Rule 18 amendment (2026-04-22).
# Run from repo root. Exits non-zero on any FAIL.
# xfail state: before T1+T2+T3+T5 edits land, assertions 2, 4, 5 FAIL.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"  # "pass" or "fail"
  if [ "$result" = "pass" ]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

# Assertion 1: Rule 18 still contains "--admin" prohibition
if grep -q "gh pr merge --admin" "$CLAUDE_MD"; then
  check "Rule 18 retains --admin prohibition" pass
else
  check "Rule 18 retains --admin prohibition" fail
fi

# Assertion 2: Rule 18 no longer contains "merge a PR they authored"
if grep -q "merge a PR they authored" "$CLAUDE_MD"; then
  check "Rule 18 drops 'merge a PR they authored' clause" fail
else
  check "Rule 18 drops 'merge a PR they authored' clause" pass
fi

# Assertion 3: Rule 18 still requires non-author approval (phrase may span lines; check components)
if grep -q "account other than the PR author" "$CLAUDE_MD"; then
  check "Rule 18 retains non-author approval requirement" pass
else
  check "Rule 18 retains non-author approval requirement" fail
fi

# Assertion 4: No architecture/ or agents/memory/ file contains old clause
if grep -rq "must NOT merge a PR they authored" "$REPO_ROOT/architecture/" "$REPO_ROOT/agents/memory/" 2>/dev/null; then
  check "No architecture/ or agents/memory/ restates 'must NOT merge a PR they authored'" fail
else
  check "No architecture/ or agents/memory/ restates 'must NOT merge a PR they authored'" pass
fi

# Assertion 5: No file under .claude/agents/, CLAUDE.md, architecture/ contains old phrase
if grep -rq "merge a PR they authored" "$REPO_ROOT/.claude/agents/" "$CLAUDE_MD" "$REPO_ROOT/architecture/" 2>/dev/null; then
  check "No .claude/agents/, CLAUDE.md, or architecture/ contains 'merge a PR they authored'" fail
else
  check "No .claude/agents/, CLAUDE.md, or architecture/ contains 'merge a PR they authored'" pass
fi

# Assertion 6 (T4-broadened): No architecture/ or agents/memory/ file contains alternate old phrasing
# "merge their own PRs" — catches cross-repo-workflow.md drift that T4 previously missed.
if grep -rq "merge their own PRs" "$REPO_ROOT/architecture/" "$REPO_ROOT/agents/memory/" 2>/dev/null; then
  check "No architecture/ or agents/memory/ contains 'merge their own PRs'" fail
else
  check "No architecture/ or agents/memory/ contains 'merge their own PRs'" pass
fi

echo ""
echo "Results: $PASS PASS, $FAIL FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
