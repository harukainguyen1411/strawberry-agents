#!/bin/bash
# test-pretooluse-plan-lifecycle-guard.sh
# xfail: pretooluse-plan-lifecycle-guard.sh does not exist yet.
# Rule 12 — xfail test committed before T1 implementation.
#
# Tests six invariants from the plan-lifecycle-physical-guard plan:
#   INV-1: Bash git mv proposed->approved with non-Orianna agent -> exit 2
#   INV-2: Bash git mv proposed->approved with Orianna agent -> exit 0
#   INV-3: Write to plans/approved/ with non-Orianna agent -> exit 2
#   INV-4: Write to plans/proposed/personal/ with non-Orianna agent -> exit 0
#   INV-5: No identity env var set (protected path) -> exit 2 (fail-closed)
#   INV-6: Bash rm -rf plans/in-progress/foo/ with non-Orianna agent -> exit 2

set -u

REPO_ROOT="$(git rev-parse --show-toplevel)"
GUARD="$REPO_ROOT/scripts/hooks/pretooluse-plan-lifecycle-guard.sh"

PASS=0
FAIL=0

assert_exit() {
  label="$1"
  expected="$2"
  shift 2
  actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    printf '  PASS: %s\n' "$label"
    PASS=$((PASS+1))
  else
    printf '  FAIL: %s (expected exit %s, got %s)\n' "$label" "$expected" "$actual"
    FAIL=$((FAIL+1))
  fi
}

# Guard must exist before tests can run
if [ ! -f "$GUARD" ]; then
  printf 'XFAIL: %s not found — T1 not yet implemented (expected per Rule 12)\n' "$GUARD"
  exit 1
fi

echo "=== pretooluse-plan-lifecycle-guard.sh tests ==="

# INV-1: Bash git mv proposed->approved, non-Orianna agent -> exit 2
PAYLOAD_INV1='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/personal/foo.md plans/approved/personal/foo.md"}}'
assert_exit "INV-1: Bash git mv proposed->approved, ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV1}
JSON
"

# INV-2: Bash git mv proposed->approved, Orianna -> exit 0
assert_exit "INV-2: Bash git mv proposed->approved, orianna -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=orianna bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV1}
JSON
"

# INV-3: Write file_path under plans/approved/, non-Orianna -> exit 2
PAYLOAD_INV3='{"tool_name":"Write","tool_input":{"file_path":"plans/approved/personal/new.md","content":"test"}}'
assert_exit "INV-3: Write to plans/approved/, karma -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV3}
JSON
"

# INV-4: Write file_path under plans/proposed/personal/, non-Orianna -> exit 0
PAYLOAD_INV4='{"tool_name":"Write","tool_input":{"file_path":"plans/proposed/personal/new-plan.md","content":"test"}}'
assert_exit "INV-4: Write to plans/proposed/personal/, karma -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV4}
JSON
"

# INV-5: No identity env vars set, Write to protected path -> exit 2 (fail-closed)
PAYLOAD_INV5='{"tool_name":"Write","tool_input":{"file_path":"plans/in-progress/personal/plan.md","content":"test"}}'
assert_exit "INV-5: No identity env, Write to plans/in-progress/ -> exit 2 (fail-closed)" 2 \
  bash -c "unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT; bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV5}
JSON
"

# INV-6: Bash rm -rf plans/in-progress/foo/, non-Orianna -> exit 2
PAYLOAD_INV6='{"tool_name":"Bash","tool_input":{"command":"rm -rf plans/in-progress/foo/"}}'
assert_exit "INV-6: Bash rm -rf plans/in-progress/foo/, ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_INV6}
JSON
"

# --- Senna C1-C4 bypass vectors (xfail until guard patched) ---

# C1: single-quoted path bypass — tokenizer must strip quotes before matching
PAYLOAD_C1='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md '\''plans/approved/x.md'\''"}}'
assert_exit "C1: single-quoted dest path, ekko -> exit 2 (quote-strip required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C1}
JSON
"

# C1b: double-quoted path bypass
PAYLOAD_C1B='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md \"plans/approved/x.md\""}}'
assert_exit "C1b: double-quoted dest path, ekko -> exit 2 (quote-strip required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C1B}
JSON
"

# C2: double-slash bypass — slash collapsing required
PAYLOAD_C2='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md plans//approved/x.md"}}'
assert_exit "C2: double-slash in path, ekko -> exit 2 (slash-collapse required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C2}
JSON
"

# C3: dot-dot traversal bypass — canonicalization required
PAYLOAD_C3='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md plans/../plans/approved/x.md"}}'
assert_exit "C3: dotdot traversal in path, ekko -> exit 2 (canonicalize required)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_C3}
JSON
"

# C4: malformed JSON must fail-closed (exit 2), not fall through
assert_exit "C4: malformed JSON input -> exit 2 (fail-closed)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<<'NOT_JSON'"

# --- Edit/Write/NotebookEdit file-existence semantics (xfail until impl patched) ---
# Rule: Edit/NotebookEdit on EXISTING file in protected path -> exit 0 (permitted edit)
#       Write to NON-EXISTING file in protected path -> exit 2 (blocked new-file creation)
#       Write to EXISTING file in protected path -> exit 0 (overwrite = edit, permitted)

# Use the repo's own plan file as the "existing" test fixture
_EXISTING_PLAN="$REPO_ROOT/plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md"
_EXISTING_APPROVED="$REPO_ROOT/plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md"

# C5: Edit on existing protected file, non-Orianna -> exit 0 (edit permitted)
if [ -f "$_EXISTING_PLAN" ]; then
  PAYLOAD_C5="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md\",\"old_string\":\"x\",\"new_string\":\"y\"}}"
  assert_exit "C5: Edit existing protected file, aphelios -> exit 0 (existing-file edit allowed)" 0 \
    bash -c "CLAUDE_AGENT_NAME=aphelios bash \"$GUARD\" <<'JSON'
${PAYLOAD_C5}
JSON
"
else
  printf '  SKIP: C5 — %s not found, skipping Edit-existing test\n' "$_EXISTING_PLAN"
fi

# C6: Write to NON-EXISTING file in protected path, non-Orianna -> exit 2 (new file blocked)
_NON_EXISTING="plans/in-progress/personal/non-existent-xfail-$(date +%s).md"
PAYLOAD_C6="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"${_NON_EXISTING}\",\"content\":\"test\"}}"
assert_exit "C6: Write to non-existing protected file, aphelios -> exit 2 (new-file creation blocked)" 2 \
  bash -c "CLAUDE_AGENT_NAME=aphelios bash \"$GUARD\" <<'JSON'
${PAYLOAD_C6}
JSON
"

# C7: Write to EXISTING file in protected path, non-Orianna -> exit 0 (overwrite = edit, permitted)
if [ -f "$_EXISTING_APPROVED" ]; then
  PAYLOAD_C7="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md\",\"content\":\"updated\"}}"
  assert_exit "C7: Write to existing protected file, karma -> exit 0 (overwrite/edit allowed)" 0 \
    bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_C7}
JSON
"
else
  printf '  SKIP: C7 — %s not found, skipping Write-existing test\n' "$_EXISTING_APPROVED"
fi

# C8: NotebookEdit on existing file -> exit 0
if [ -f "$_EXISTING_PLAN" ]; then
  PAYLOAD_C8="{\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md\",\"new_source\":\"test\"}}"
  assert_exit "C8: NotebookEdit on existing protected file, xayah -> exit 0" 0 \
    bash -c "CLAUDE_AGENT_NAME=xayah bash \"$GUARD\" <<'JSON'
${PAYLOAD_C8}
JSON
"
else
  printf '  SKIP: C8 — %s not found, skipping NotebookEdit-existing test\n' "$_EXISTING_PLAN"
fi

# --- Senna round-2: AST walker xfail tests (xfail until bashlex helper implemented) ---

# R2-1: shell redirect no-space (echo x >plans/approved/y.md), non-Orianna -> exit 2
# The tokenizer splits on whitespace — ">plans/approved/y.md" has no space before ">"
# so the old tokenizer sees it as one token but doesn't strip the ">". AST walker must
# detect the redirect target.
PAYLOAD_R2_1='{"tool_name":"Bash","tool_input":{"command":"echo x >plans/approved/y.md"}}'
assert_exit "R2-1: redirect no-space (echo x >plans/approved/y.md), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R2_1}
JSON
"

# R2-2: case-fold bypass (PLANS/APPROVED/x.md on case-insensitive FS), non-Orianna -> exit 2
# Test asserts exit 2 regardless of actual FS (guard must case-fold on its own).
PAYLOAD_R2_2='{"tool_name":"Bash","tool_input":{"command":"git mv src PLANS/APPROVED/x.md"}}'
assert_exit "R2-2: case-fold bypass (PLANS/APPROVED/x.md), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R2_2}
JSON
"

# R2-3: variable assignment resolution (dest=plans/approved/x.md; git mv src $dest), non-Orianna -> exit 2
# The old tokenizer sees "$dest" as a literal token — AST walker must trace var assignment.
PAYLOAD_R2_3='{"tool_name":"Bash","tool_input":{"command":"dest=plans/approved/x.md; git mv src $dest"}}'
assert_exit "R2-3: var assignment (dest=plans/approved/x.md; git mv src \$dest), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R2_3}
JSON
"

# R2-4: ANSI-C quoting ($'...'), non-Orianna -> exit 2
PAYLOAD_R2_4='{"tool_name":"Bash","tool_input":{"command":"git mv src $'"'"'plans/approved/x.md'"'"'"}}'
assert_exit "R2-4: ANSI-C quoting (\$'plans/approved/x.md'), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R2_4}
JSON
"

# R2-5: missing python3/bashlex -> fail-closed, exit 2 with install message
# We simulate missing python3 by providing a PYTHON3_CMD override pointing at /nonexistent.
PAYLOAD_R2_5='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md plans/approved/x.md"}}'
assert_exit "R2-5: python3 unavailable (PYTHON3_CMD=/nonexistent) -> exit 2 fail-closed" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko PYTHON3_CMD=/nonexistent bash \"$GUARD\" <<'JSON'
${PAYLOAD_R2_5}
JSON
"

# --- Senna round-3: AST walker structural fixes (xfail until implemented) ---

# R3-1: subshell (git mv src plans/approved/x.md) -> exit 2
# CompoundNode uses .list, not .parts — walker must descend .list children.
PAYLOAD_R3_1='{"tool_name":"Bash","tool_input":{"command":"(git mv src plans/approved/x.md)"}}'
assert_exit "R3-1: subshell (git mv src plans/approved/x.md), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_1}
JSON
"

# R3-2: function body f(){ git mv src plans/approved/x.md; };f -> exit 2
# FunctionNode body is a CompoundNode with .list — walker must descend .list.
PAYLOAD_R3_2='{"tool_name":"Bash","tool_input":{"command":"f(){ git mv src plans/approved/x.md; };f"}}'
assert_exit "R3-2: function body (f(){ git mv src plans/approved/x.md; }), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_2}
JSON
"

# R3-3: command substitution $(git mv src plans/approved/x.md) -> exit 2
# WordNode.parts contains CommandsubstitutionNode — walker must walk .parts of words.
PAYLOAD_R3_3='{"tool_name":"Bash","tool_input":{"command":"echo $(git mv src plans/approved/x.md)"}}'
assert_exit "R3-3: command substitution \$(git mv src plans/approved/x.md), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_3}
JSON
"

# R3-4: backtick substitution `git mv src plans/approved/x.md` -> exit 2
# Same CommandsubstitutionNode shape as $(...).
PAYLOAD_R3_4='{"tool_name":"Bash","tool_input":{"command":"echo \`git mv src plans/approved/x.md\`"}}'
assert_exit "R3-4: backtick substitution, ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_4}
JSON
"

# R3-5: eval re-parse -> exit 2
# When verb is eval, re-parse the argument string.
PAYLOAD_R3_5='{"tool_name":"Bash","tool_input":{"command":"eval \"git mv src plans/approved/x.md\""}}'
assert_exit "R3-5: eval re-parse (eval \"git mv src plans/approved/x.md\"), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_5}
JSON
"

# R3-6: bash -c re-parse -> exit 2
# When verb is bash or sh with -c flag, re-parse the argument string.
PAYLOAD_R3_6='{"tool_name":"Bash","tool_input":{"command":"bash -c \"git mv src plans/approved/x.md\""}}'
assert_exit "R3-6: bash -c re-parse (bash -c \"git mv src plans/approved/x.md\"), ekko -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_6}
JSON
"

# R3-7: malformed bash (parse error) -> exit 2 fail-closed, no tokenizer fallback
# Scanner must exit non-zero on parse error; guard must treat non-zero scanner exit as fail-closed.
PAYLOAD_R3_7='{"tool_name":"Bash","tool_input":{"command":"git mv ;;"}}'
assert_exit "R3-7: malformed bash (parse error), ekko -> exit 2 fail-closed" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_7}
JSON
"

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
