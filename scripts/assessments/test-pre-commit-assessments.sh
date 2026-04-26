#!/bin/sh
# xfail: T16 — pre-commit-assessments-index-gen.sh does not exist yet
# Plan: plans/approved/personal/2026-04-25-assessments-folder-structure.md §Tasks Phase C T16
# Tasks: T16 impl gates on this xfail passing
#
# Run: bash scripts/assessments/test-pre-commit-assessments.sh
#
# Tests that scripts/hooks/pre-commit-assessments-index-gen.sh:
#   H1  — script exists and passes bash -n syntax check
#   H2  — scripts/install-hooks.sh mentions pre-commit-assessments-index-gen
#   H3  — committing an assessment .md file triggers regeneration of that category's INDEX.md
#          and auto-stages the INDEX.md in the same commit
#   H4  — committing a file outside assessments/ does not invoke the script (no-op)
#   H5  — committing an assessment file missing one or more of the 8 mandatory frontmatter
#          fields causes the hook to exit non-zero (commit blocked) and names the
#          offending field(s) in stderr
#   H6  — hook is idempotent: if INDEX.md is already up to date, the hook is a no-op
#          (does not alter INDEX.md unnecessarily)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Navigate from scripts/assessments/ up to repo root and then into hooks/
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/pre-commit-assessments-index-gen.sh"
INSTALL_HOOKS="$REPO_ROOT/scripts/install-hooks.sh"
INDEX_GEN="$REPO_ROOT/scripts/assessments/index-gen.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------
# XFAIL guard — hook script must not exist yet
# -----------------------------------------------------------------------
MISSING=""
[ ! -f "$HOOK_SCRIPT" ] && MISSING="$MISSING scripts/hooks/pre-commit-assessments-index-gen.sh"
[ ! -f "$INDEX_GEN" ]   && MISSING="$MISSING scripts/assessments/index-gen.sh"

if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  for c in \
    H1_HOOK_EXISTS_AND_SYNTAX_CLEAN \
    H2_INSTALL_HOOKS_MENTIONS_HOOK \
    H3_ASSESSMENT_COMMIT_TRIGGERS_INDEX_REGEN \
    H4_NON_ASSESSMENT_COMMIT_IS_NOOP \
    H5_MISSING_FRONTMATTER_BLOCKS_COMMIT \
    H6_ALREADY_CURRENT_INDEX_IS_NOOP
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 6 xfail (expected — T16 pre-commit-assessments-index-gen.sh + index-gen.sh not yet implemented)\n'
  exit 0
fi

# -----------------------------------------------------------------------
# H1 — hook exists and passes bash -n syntax check
# -----------------------------------------------------------------------
if bash -n "$HOOK_SCRIPT" 2>/dev/null; then
  pass "H1_HOOK_EXISTS_AND_SYNTAX_CLEAN"
else
  fail "H1_HOOK_EXISTS_AND_SYNTAX_CLEAN" "bash -n failed on $HOOK_SCRIPT"
fi

# -----------------------------------------------------------------------
# H2 — install-hooks.sh mentions the hook by name
# -----------------------------------------------------------------------
if grep -q "pre-commit-assessments-index-gen" "$INSTALL_HOOKS" 2>/dev/null; then
  pass "H2_INSTALL_HOOKS_MENTIONS_HOOK"
else
  fail "H2_INSTALL_HOOKS_MENTIONS_HOOK" "install-hooks.sh does not reference pre-commit-assessments-index-gen"
fi

# -----------------------------------------------------------------------
# Shared git repo helper for H3–H6
# -----------------------------------------------------------------------

make_test_repo() {
  local dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  # Scaffold all 8 category dirs
  for cat in research qa-reports audits reviews retrospectives runbooks advisories artifacts; do
    mkdir -p "$dir/assessments/$cat"
    touch "$dir/assessments/$cat/.gitkeep"
  done
  # Copy index-gen.sh and hook into the test repo so hook calls work in isolation
  mkdir -p "$dir/scripts/assessments"
  mkdir -p "$dir/scripts/hooks"
  cp "$INDEX_GEN"   "$dir/scripts/assessments/index-gen.sh"
  cp "$HOOK_SCRIPT" "$dir/scripts/hooks/pre-commit-assessments-index-gen.sh"
  # Initial commit
  git -C "$dir" add .
  git -C "$dir" commit -q -m "chore: init"
  # Install the hook
  mkdir -p "$dir/.git/hooks"
  cp "$HOOK_SCRIPT" "$dir/.git/hooks/pre-commit"
  chmod +x "$dir/.git/hooks/pre-commit"
  printf '%s' "$dir"
}

write_valid_assessment() {
  local path="$1" cat="$2" date="$3"
  cat > "$path" <<ENTRY
---
date: $date
author: lux
category: $cat
concern: personal
target: test assessment for $cat
state: active
owner: lux
session: none
---

# Test entry for $cat
ENTRY
}

write_invalid_assessment() {
  local path="$1" cat="$2"
  # Missing 'state' and 'owner' — two of the 8 required fields
  cat > "$path" <<ENTRY
---
date: 2026-04-10
author: lux
category: $cat
concern: personal
target: malformed entry missing state and owner
session: none
---

# Malformed entry
ENTRY
}

# -----------------------------------------------------------------------
# H3 — committing a valid assessment file regenerates and auto-stages INDEX.md
# -----------------------------------------------------------------------
REPO_H3="$(make_test_repo)"
AFILE_H3="$REPO_H3/assessments/research/2026-04-10-sample.md"
write_valid_assessment "$AFILE_H3" "research" "2026-04-10"
git -C "$REPO_H3" add "assessments/research/2026-04-10-sample.md"

set +e
commit_out_h3="$(git -C "$REPO_H3" commit -m "chore: add research assessment" 2>&1)"
rc_h3=$?
set -e

# After the commit, INDEX.md must exist under assessments/research/
# AND must have been included in the commit (git show --name-only HEAD)
index_in_commit=0
git -C "$REPO_H3" show --name-only HEAD 2>/dev/null | grep -q "assessments/research/INDEX.md" \
  && index_in_commit=1

if [ "$rc_h3" -eq 0 ] && [ "$index_in_commit" -eq 1 ]; then
  pass "H3_ASSESSMENT_COMMIT_TRIGGERS_INDEX_REGEN"
else
  fail "H3_ASSESSMENT_COMMIT_TRIGGERS_INDEX_REGEN" "rc=$rc_h3; INDEX.md in commit=$index_in_commit; out: $(printf '%s' "$commit_out_h3" | head -5)"
fi
rm -rf "$REPO_H3"

# -----------------------------------------------------------------------
# H4 — committing a file outside assessments/ does not touch INDEX.md
# -----------------------------------------------------------------------
REPO_H4="$(make_test_repo)"
OTHER_FILE="$REPO_H4/plans/test-plan.md"
mkdir -p "$(dirname "$OTHER_FILE")"
printf '# Not an assessment\n' > "$OTHER_FILE"
git -C "$REPO_H4" add "plans/test-plan.md"

set +e
commit_out_h4="$(git -C "$REPO_H4" commit -m "chore: add test plan" 2>&1)"
rc_h4=$?
set -e

index_touched=0
git -C "$REPO_H4" show --name-only HEAD 2>/dev/null | grep -q "assessments.*INDEX.md" \
  && index_touched=1

if [ "$rc_h4" -eq 0 ] && [ "$index_touched" -eq 0 ]; then
  pass "H4_NON_ASSESSMENT_COMMIT_IS_NOOP"
else
  fail "H4_NON_ASSESSMENT_COMMIT_IS_NOOP" "rc=$rc_h4; index_touched=$index_touched; out: $(printf '%s' "$commit_out_h4" | head -5)"
fi
rm -rf "$REPO_H4"

# -----------------------------------------------------------------------
# H5 — committing an assessment file missing required frontmatter fields
#       causes the hook to block the commit (non-zero exit) and names the field
# -----------------------------------------------------------------------
REPO_H5="$(make_test_repo)"
AFILE_H5="$REPO_H5/assessments/audits/2026-04-10-broken.md"
write_invalid_assessment "$AFILE_H5" "audits"
git -C "$REPO_H5" add "assessments/audits/2026-04-10-broken.md"

set +e
commit_out_h5="$(git -C "$REPO_H5" commit -m "chore: add broken assessment" 2>&1)"
rc_h5=$?
set -e

# Commit must be blocked (non-zero) and output should name the missing field(s)
missing_named=0
printf '%s' "$commit_out_h5" | grep -qi "state\|owner\|missing\|required\|frontmatter" \
  && missing_named=1

if [ "$rc_h5" -ne 0 ] && [ "$missing_named" -eq 1 ]; then
  pass "H5_MISSING_FRONTMATTER_BLOCKS_COMMIT"
else
  fail "H5_MISSING_FRONTMATTER_BLOCKS_COMMIT" "expected blocked commit naming missing field; rc=$rc_h5 named=$missing_named; out: $(printf '%s' "$commit_out_h5" | head -5)"
fi
rm -rf "$REPO_H5"

# -----------------------------------------------------------------------
# H6 — if INDEX.md is already current, committing a second assessment does
#       not produce a different INDEX.md (idempotency at hook level)
# -----------------------------------------------------------------------
REPO_H6="$(make_test_repo)"
# First assessment commit — seeds the INDEX
AFILE_H6A="$REPO_H6/assessments/research/2026-04-10-first.md"
write_valid_assessment "$AFILE_H6A" "research" "2026-04-10"
git -C "$REPO_H6" add "assessments/research/2026-04-10-first.md"
git -C "$REPO_H6" commit -q -m "chore: first assessment"

INDEX_AFTER_FIRST="$(cksum "$REPO_H6/assessments/research/INDEX.md" 2>/dev/null | awk '{print $1}')"

# Second assessment commit — INDEX should be updated to include the new entry
AFILE_H6B="$REPO_H6/assessments/research/2026-04-11-second.md"
write_valid_assessment "$AFILE_H6B" "research" "2026-04-11"
git -C "$REPO_H6" add "assessments/research/2026-04-11-second.md"

set +e
git -C "$REPO_H6" commit -q -m "chore: second assessment" 2>/dev/null
rc_h6=$?
set -e

INDEX_AFTER_SECOND="$(cksum "$REPO_H6/assessments/research/INDEX.md" 2>/dev/null | awk '{print $1}')"

# Third run: commit an unrelated file — INDEX should NOT change again
OTHER_H6="$REPO_H6/plans/note.md"
mkdir -p "$(dirname "$OTHER_H6")"
printf '# note\n' > "$OTHER_H6"
git -C "$REPO_H6" add "plans/note.md"
git -C "$REPO_H6" commit -q -m "chore: unrelated commit" 2>/dev/null || true

INDEX_AFTER_UNRELATED="$(cksum "$REPO_H6/assessments/research/INDEX.md" 2>/dev/null | awk '{print $1}')"

if [ "$rc_h6" -eq 0 ] && [ "$INDEX_AFTER_SECOND" = "$INDEX_AFTER_UNRELATED" ]; then
  pass "H6_ALREADY_CURRENT_INDEX_IS_NOOP"
else
  fail "H6_ALREADY_CURRENT_INDEX_IS_NOOP" "rc=$rc_h6; INDEX changed on unrelated commit (checksum after 2nd=$INDEX_AFTER_SECOND, after unrelated=$INDEX_AFTER_UNRELATED)"
fi
rm -rf "$REPO_H6"

# -----------------------------------------------------------------------
printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
