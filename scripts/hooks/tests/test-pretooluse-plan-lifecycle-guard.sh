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

# R3-7: malformed bash referencing UNPROTECTED plans path (parse error) -> exit 0
# Updated per plan 2026-04-25-plan-lifecycle-guard-heredoc-fp.md two-stage parse strategy:
# When bashlex exits 3, the conservative fallback runs. The command moves plans/proposed/
# (unprotected) to ;; (no path), so conservative scan finds no protected path — exit 0.
# The must-still-block counterpart for protected paths inside unparseable scripts is B-8.
PAYLOAD_R3_7='{"tool_name":"Bash","tool_input":{"command":"git mv plans/proposed/x.md ;;"}}'
assert_exit "R3-7: malformed bash with unprotected plans path (parse error) -> exit 0 via conservative fallback" 0 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_R3_7}
JSON
"

# --- Verb-allowlist tests: non-mutating verbs must NOT block plan paths (xfail until impl) ---
#
# V1: git add plans/approved/x.md, talon -> exit 0 (read-only git op)
# V2: cat plans/approved/x.md, talon -> exit 0 (read-only)
# V3: ls plans/approved/, talon -> exit 0 (read-only)
# V4: grep foo plans/approved/x.md, talon -> exit 0 (read-only)
# V5: sed -i 's/a/b/' plans/approved/x.md, talon -> exit 2 (in-place edit = mutation)
# V6: touch plans/approved/new.md, talon -> exit 2 (mutation)
# V7: echo foo >plans/approved/x.md, talon -> exit 2 (redirect = write)

PAYLOAD_V1='{"tool_name":"Bash","tool_input":{"command":"git add plans/approved/x.md"}}'
assert_exit "V1: git add plans/approved/x.md, talon -> exit 0 (non-mutating)" 0 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_V1}
JSON
"

PAYLOAD_V2='{"tool_name":"Bash","tool_input":{"command":"cat plans/approved/x.md"}}'
assert_exit "V2: cat plans/approved/x.md, talon -> exit 0 (non-mutating)" 0 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_V2}
JSON
"

PAYLOAD_V3='{"tool_name":"Bash","tool_input":{"command":"ls plans/approved/"}}'
assert_exit "V3: ls plans/approved/, talon -> exit 0 (non-mutating)" 0 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_V3}
JSON
"

PAYLOAD_V4='{"tool_name":"Bash","tool_input":{"command":"grep foo plans/approved/x.md"}}'
assert_exit "V4: grep foo plans/approved/x.md, talon -> exit 0 (non-mutating)" 0 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_V4}
JSON
"

PAYLOAD_V5='{"tool_name":"Bash","tool_input":{"command":"sed -i '"'"'s/a/b/'"'"' plans/approved/x.md"}}'
assert_exit "V5: sed -i s/a/b/ plans/approved/x.md, talon -> exit 2 (in-place edit)" 2 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_V5}
JSON
"

PAYLOAD_V6='{"tool_name":"Bash","tool_input":{"command":"touch plans/approved/new.md"}}'
assert_exit "V6: touch plans/approved/new.md, talon -> exit 2 (mutation)" 2 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_V6}
JSON
"

PAYLOAD_V7='{"tool_name":"Bash","tool_input":{"command":"echo foo >plans/approved/x.md"}}'
assert_exit "V7: echo foo >plans/approved/x.md, talon -> exit 2 (redirect = write)" 2 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_V7}
JSON
"

# --- T1: agent_type identity propagation (xfail until T2 impl lands) ---
# Hook JSON carries agent_type field (set by Claude Code runtime for subagent calls).
# Guard must read .agent_type as first identity source — no env vars needed.
#
# A1: agent_type=orianna, no env vars, git mv proposed->approved -> exit 0 (xfail)
# A2: agent_type=ekko,    no env vars, git mv proposed->approved -> exit 2 (xfail)

PAYLOAD_A1='{"tool_name":"Bash","agent_type":"orianna","tool_input":{"command":"git mv plans/proposed/personal/x.md plans/approved/personal/x.md"}}'
assert_exit "A1: agent_type=orianna, no env vars, git mv -> exit 0" 0 \
  bash -c "unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT; bash \"$GUARD\" <<'JSON'
${PAYLOAD_A1}
JSON
"

PAYLOAD_A2='{"tool_name":"Bash","agent_type":"ekko","tool_input":{"command":"git mv plans/proposed/personal/x.md plans/approved/personal/x.md"}}'
assert_exit "A2: agent_type=ekko, no env vars, git mv -> exit 2" 2 \
  bash -c "unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT; bash \"$GUARD\" <<'JSON'
${PAYLOAD_A2}
JSON
"

# --- Heredoc FP corpus (xfail until two-stage parse lands) ---
# Plan: plans/approved/personal/2026-04-25-plan-lifecycle-guard-heredoc-fp.md §4.1
# Each FP case must exit 0 (allowed). Before the fix, quoted-delimiter heredocs
# cause bashlex to exit 3 and the guard fails closed (exit 2) — these are xfail.

# FP-1: quoted-delimiter heredoc in gh pr review --body $(...) -> exit 0
PAYLOAD_FP1='{"tool_name":"Bash","tool_input":{"command":"gh pr review 47 --body \"$(cat <<'"'"'EOF'"'"'\naddresses plans/approved/personal/foo.md\nEOF\n)\""}}'
assert_exit "FP-1: quoted-heredoc in gh pr review body -> exit 0 (must allow)" 0 \
  bash -c "CLAUDE_AGENT_NAME=lucian bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP1}
JSON
"

# FP-2: bare-delimiter heredoc in gh pr review -> exit 0
PAYLOAD_FP2='{"tool_name":"Bash","tool_input":{"command":"gh pr review 47 --body \"$(cat <<EOF\naddresses plans/in-progress/personal/foo.md\nEOF\n)\""}}'
assert_exit "FP-2: bare-heredoc in gh pr review body -> exit 0 (must allow)" 0 \
  bash -c "CLAUDE_AGENT_NAME=lucian bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP2}
JSON
"

# FP-3: inline string body with plan path -> exit 0
PAYLOAD_FP3='{"tool_name":"Bash","tool_input":{"command":"gh pr comment 47 --body \"Per plans/approved/personal/foo.md, approved\""}}'
assert_exit "FP-3: gh pr comment inline body with plan path -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=senna bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP3}
JSON
"

# FP-4: git commit -m with quoted-delimiter heredoc referencing plan path -> exit 0
PAYLOAD_FP4='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"$(cat <<'"'"'EOF'"'"'\nrefers to plans/implemented/personal/foo.md\nEOF\n)\""}}'
assert_exit "FP-4: git commit -m quoted-heredoc with plan path -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP4}
JSON
"

# FP-5: git commit -m inline with plan path -> exit 0
PAYLOAD_FP5='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix per plans/approved/personal/foo.md\""}}'
assert_exit "FP-5: git commit -m inline body with plan path -> exit 0" 0 \
  bash -c "CLAUDE_AGENT_NAME=talon bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP5}
JSON
"

# FP-6: cat read-only access -> exit 0
PAYLOAD_FP6='{"tool_name":"Bash","tool_input":{"command":"cat plans/approved/personal/foo.md"}}'
assert_exit "FP-6: cat plans/approved/personal/foo.md -> exit 0 (read-only)" 0 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP6}
JSON
"

# FP-7: grep recursive read -> exit 0
PAYLOAD_FP7='{"tool_name":"Bash","tool_input":{"command":"grep -r \"TBD\" plans/approved/"}}'
assert_exit "FP-7: grep -r TBD plans/approved/ -> exit 0 (read-only)" 0 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP7}
JSON
"

# FP-8: ls directory listing -> exit 0
PAYLOAD_FP8='{"tool_name":"Bash","tool_input":{"command":"ls plans/in-progress/personal/"}}'
assert_exit "FP-8: ls plans/in-progress/personal/ -> exit 0 (read-only)" 0 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP8}
JSON
"

# FP-9: printf with format string containing plan path -> exit 0
PAYLOAD_FP9='{"tool_name":"Bash","tool_input":{"command":"printf '"'"'%s\\n'"'"' \"see plans/archived/personal/foo.md\""}}'
assert_exit "FP-9: printf with plan path in format arg -> exit 0 (read-only)" 0 \
  bash -c "CLAUDE_AGENT_NAME=karma bash \"$GUARD\" <<'JSON'
${PAYLOAD_FP9}
JSON
"

# --- Must-still-block corpus after heredoc FP fix (§4.2) ---
# Plan: plans/approved/personal/2026-04-25-plan-lifecycle-guard-heredoc-fp.md §4.2
# Each violation must remain exit 2 (blocked), even after the conservative fallback.

# B-1: direct mv -> exit 2 (already passing, regression guard)
PAYLOAD_B1='{"tool_name":"Bash","tool_input":{"command":"mv plans/approved/personal/foo.md plans/in-progress/personal/foo.md"}}'
assert_exit "B-1: direct mv plans/approved -> plans/in-progress -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B1}
JSON
"

# B-2: cp -> exit 2
PAYLOAD_B2='{"tool_name":"Bash","tool_input":{"command":"cp plans/approved/personal/foo.md plans/archived/personal/foo.md"}}'
assert_exit "B-2: cp plans/approved -> plans/archived -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B2}
JSON
"

# B-3: rm plans path -> exit 2
PAYLOAD_B3='{"tool_name":"Bash","tool_input":{"command":"rm plans/in-progress/personal/foo.md"}}'
assert_exit "B-3: rm plans/in-progress/personal/foo.md -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B3}
JSON
"

# B-4: git mv -> exit 2
PAYLOAD_B4='{"tool_name":"Bash","tool_input":{"command":"git mv plans/approved/personal/foo.md plans/in-progress/personal/foo.md"}}'
assert_exit "B-4: git mv plans/approved -> plans/in-progress -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B4}
JSON
"

# B-5: redirect creating new file -> exit 2
PAYLOAD_B5='{"tool_name":"Bash","tool_input":{"command":"echo x > plans/approved/personal/new.md"}}'
assert_exit "B-5: echo x > plans/approved/personal/new.md -> exit 2 (redirect)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B5}
JSON
"

# B-6: tee write -> exit 2
PAYLOAD_B6='{"tool_name":"Bash","tool_input":{"command":"tee plans/approved/personal/new.md <<<x"}}'
assert_exit "B-6: tee plans/approved/personal/new.md -> exit 2 (tee write)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B6}
JSON
"

# B-7: touch -> exit 2
PAYLOAD_B7='{"tool_name":"Bash","tool_input":{"command":"touch plans/in-progress/personal/new.md"}}'
assert_exit "B-7: touch plans/in-progress/personal/new.md -> exit 2 (mutation)" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B7}
JSON
"

# B-8: conservative fallback must block mv inside heredoc-wrapped (unparseable) script -> exit 2
# The outer heredoc prefix makes bashlex fail with exit 3; conservative scan must still
# detect the mv and block.
PAYLOAD_B8='{"tool_name":"Bash","tool_input":{"command":"bash <<'"'"'SCRIPT'"'"'\nmv plans/approved/personal/foo.md plans/archived/personal/foo.md\nSCRIPT"}}'
assert_exit "B-8: mv inside heredoc script (bashlex exits 3), conservative fallback blocks -> exit 2" 2 \
  bash -c "CLAUDE_AGENT_NAME=ekko bash \"$GUARD\" <<'JSON'
${PAYLOAD_B8}
JSON
"

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
