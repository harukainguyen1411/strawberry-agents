#!/bin/sh
# xfail: T15 — migration-link-fix.sh does not exist yet
# Plan: plans/approved/personal/2026-04-25-assessments-folder-structure.md §Tasks Phase C T15
# Tasks: T15 impl gates on this xfail passing
#
# Run: bash scripts/assessments/test-migration-link-fix.sh
#
# Tests that scripts/assessments/migration-link-fix.sh:
#   M1  — rewrites `assessments/foo.md` → `assessments/<category>/foo.md` in a plan file,
#          using the mv-map.json artifact as the rewrite map
#   M2  — rewrites old-path references found in agent def files (.claude/agents/)
#   M3  — rewrites old-path references found in other assessments files
#   M4  — dry-run mode (default) does NOT write to disk
#   M5  — --apply mode writes rewrites to disk
#   M6  — idempotent: running --apply twice leaves files unchanged on the second run

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINK_FIX="$SCRIPT_DIR/migration-link-fix.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------
# XFAIL guard — migration-link-fix.sh must not exist yet
# -----------------------------------------------------------------------
if [ ! -f "$LINK_FIX" ]; then
  printf 'XFAIL (expected — missing: scripts/assessments/migration-link-fix.sh)\n'
  for c in \
    M1_REWRITES_PLAN_FILE \
    M2_REWRITES_AGENT_DEF \
    M3_REWRITES_OTHER_ASSESSMENT \
    M4_DRY_RUN_NO_DISK_WRITE \
    M5_APPLY_WRITES_DISK \
    M6_IDEMPOTENT
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 6 xfail (expected — T15 migration-link-fix.sh not yet implemented)\n'
  exit 0
fi

# -----------------------------------------------------------------------
# Fixture helpers
# -----------------------------------------------------------------------

# Write a minimal mv-map.json mapping old root paths to new category paths.
make_mv_map() {
  local dest="$1"
  cat > "$dest" <<'JSON'
{
  "assessments/gemini-pro-ecosystem-assessment.md": "assessments/research/2026-04-21-gemini-pro-ecosystem-assessment.md",
  "assessments/agent-system-assessment.md": "assessments/audits/personal/2026-04-10-agent-system-assessment.md",
  "assessments/orianna-prompt-audit-2026-04-21.md": "assessments/audits/personal/2026-04-21-orianna-prompt-audit.md"
}
JSON
}

# -----------------------------------------------------------------------
# M1 — rewrites old-path reference in a plan file (plans/**/*.md)
# -----------------------------------------------------------------------
TMP_M1="$(mktemp -d)"
MAP_M1="$TMP_M1/mv-map.json"
make_mv_map "$MAP_M1"

PLAN_FILE="$TMP_M1/plans/approved/personal/2026-04-25-test-plan.md"
mkdir -p "$(dirname "$PLAN_FILE")"
cat > "$PLAN_FILE" <<'PLAN'
---
status: approved
---
# Test plan

See assessments/gemini-pro-ecosystem-assessment.md for context.
Also references assessments/agent-system-assessment.md.
PLAN

set +e
bash "$LINK_FIX" --map "$MAP_M1" --apply --scan-dir "$TMP_M1" 2>/dev/null
rc_m1=$?
set -e

rewritten_count=0
grep -q "assessments/research/2026-04-21-gemini-pro-ecosystem-assessment.md" "$PLAN_FILE" 2>/dev/null \
  && rewritten_count=$((rewritten_count + 1))
grep -q "assessments/audits/personal/2026-04-10-agent-system-assessment.md" "$PLAN_FILE" 2>/dev/null \
  && rewritten_count=$((rewritten_count + 1))

if [ "$rc_m1" -eq 0 ] && [ "$rewritten_count" -eq 2 ]; then
  pass "M1_REWRITES_PLAN_FILE"
else
  fail "M1_REWRITES_PLAN_FILE" "expected 2 rewrites in plan file; got $rewritten_count (rc=$rc_m1)"
fi
rm -rf "$TMP_M1"

# -----------------------------------------------------------------------
# M2 — rewrites old-path reference in an agent def file (.claude/agents/)
# -----------------------------------------------------------------------
TMP_M2="$(mktemp -d)"
MAP_M2="$TMP_M2/mv-map.json"
make_mv_map "$MAP_M2"

AGENT_DEF="$TMP_M2/.claude/agents/lux.md"
mkdir -p "$(dirname "$AGENT_DEF")"
cat > "$AGENT_DEF" <<'AGENTDEF'
---
name: lux
model: sonnet
---
# Lux

For tooling research see assessments/gemini-pro-ecosystem-assessment.md.
For prompt audits see assessments/orianna-prompt-audit-2026-04-21.md.
AGENTDEF

set +e
bash "$LINK_FIX" --map "$MAP_M2" --apply --scan-dir "$TMP_M2" 2>/dev/null
rc_m2=$?
set -e

rewritten_m2=0
grep -q "assessments/research/2026-04-21-gemini-pro-ecosystem-assessment.md" "$AGENT_DEF" 2>/dev/null \
  && rewritten_m2=$((rewritten_m2 + 1))
grep -q "assessments/audits/personal/2026-04-21-orianna-prompt-audit.md" "$AGENT_DEF" 2>/dev/null \
  && rewritten_m2=$((rewritten_m2 + 1))

if [ "$rc_m2" -eq 0 ] && [ "$rewritten_m2" -eq 2 ]; then
  pass "M2_REWRITES_AGENT_DEF"
else
  fail "M2_REWRITES_AGENT_DEF" "expected 2 rewrites in agent def; got $rewritten_m2 (rc=$rc_m2)"
fi
rm -rf "$TMP_M2"

# -----------------------------------------------------------------------
# M3 — rewrites old-path reference within another assessment file
# -----------------------------------------------------------------------
TMP_M3="$(mktemp -d)"
MAP_M3="$TMP_M3/mv-map.json"
make_mv_map "$MAP_M3"

ASSESSMENT="$TMP_M3/assessments/research/2026-04-20-related-research.md"
mkdir -p "$(dirname "$ASSESSMENT")"
cat > "$ASSESSMENT" <<'ASS'
---
date: 2026-04-20
author: lux
category: research
concern: personal
target: related research entry
state: active
owner: lux
session: none
related:
  - assessments/agent-system-assessment.md
---

# Related research

Cross-reference: assessments/agent-system-assessment.md
ASS

set +e
bash "$LINK_FIX" --map "$MAP_M3" --apply --scan-dir "$TMP_M3" 2>/dev/null
rc_m3=$?
set -e

rewritten_m3=0
grep -q "assessments/audits/personal/2026-04-10-agent-system-assessment.md" "$ASSESSMENT" 2>/dev/null \
  && rewritten_m3=$((rewritten_m3 + 1))
# Both the frontmatter related: entry and the body reference should be rewritten
body_hits=$(grep -c "assessments/audits/personal/2026-04-10-agent-system-assessment.md" "$ASSESSMENT" 2>/dev/null || echo 0)

if [ "$rc_m3" -eq 0 ] && [ "$rewritten_m3" -ge 1 ]; then
  pass "M3_REWRITES_OTHER_ASSESSMENT"
else
  fail "M3_REWRITES_OTHER_ASSESSMENT" "expected at least 1 rewrite in assessment file; rc=$rc_m3 body_hits=$body_hits"
fi
rm -rf "$TMP_M3"

# -----------------------------------------------------------------------
# M4 — dry-run mode (default: no --apply) does NOT modify any file on disk
# -----------------------------------------------------------------------
TMP_M4="$(mktemp -d)"
MAP_M4="$TMP_M4/mv-map.json"
make_mv_map "$MAP_M4"

PLAN_M4="$TMP_M4/plans/approved/personal/2026-04-25-dryrun-test.md"
mkdir -p "$(dirname "$PLAN_M4")"
cat > "$PLAN_M4" <<'P'
---
status: approved
---
See assessments/gemini-pro-ecosystem-assessment.md.
P

original_content="$(cat "$PLAN_M4")"

set +e
# No --apply flag → dry-run mode
bash "$LINK_FIX" --map "$MAP_M4" --scan-dir "$TMP_M4" 2>/dev/null
rc_m4=$?
set -e

current_content="$(cat "$PLAN_M4")"
if [ "$rc_m4" -eq 0 ] && [ "$current_content" = "$original_content" ]; then
  pass "M4_DRY_RUN_NO_DISK_WRITE"
else
  fail "M4_DRY_RUN_NO_DISK_WRITE" "dry-run modified file on disk (rc=$rc_m4); original vs current differ: $(diff <(printf '%s' "$original_content") <(printf '%s' "$current_content") | head -5 || true)"
fi
rm -rf "$TMP_M4"

# -----------------------------------------------------------------------
# M5 — --apply mode actually writes rewrites to disk
# -----------------------------------------------------------------------
TMP_M5="$(mktemp -d)"
MAP_M5="$TMP_M5/mv-map.json"
make_mv_map "$MAP_M5"

PLAN_M5="$TMP_M5/plans/approved/personal/2026-04-25-apply-test.md"
mkdir -p "$(dirname "$PLAN_M5")"
cat > "$PLAN_M5" <<'P'
---
status: approved
---
See assessments/gemini-pro-ecosystem-assessment.md.
P

set +e
bash "$LINK_FIX" --map "$MAP_M5" --apply --scan-dir "$TMP_M5" 2>/dev/null
rc_m5=$?
set -e

if [ "$rc_m5" -eq 0 ] && \
   grep -q "assessments/research/2026-04-21-gemini-pro-ecosystem-assessment.md" "$PLAN_M5" 2>/dev/null; then
  pass "M5_APPLY_WRITES_DISK"
else
  fail "M5_APPLY_WRITES_DISK" "expected rewrite to disk after --apply; rc=$rc_m5; file content: $(cat "$PLAN_M5" | head -5 || echo missing)"
fi
rm -rf "$TMP_M5"

# -----------------------------------------------------------------------
# M6 — idempotent: running --apply twice leaves files unchanged on second run
# -----------------------------------------------------------------------
TMP_M6="$(mktemp -d)"
MAP_M6="$TMP_M6/mv-map.json"
make_mv_map "$MAP_M6"

PLAN_M6="$TMP_M6/plans/approved/personal/2026-04-25-idem-test.md"
mkdir -p "$(dirname "$PLAN_M6")"
cat > "$PLAN_M6" <<'P'
---
status: approved
---
See assessments/gemini-pro-ecosystem-assessment.md and assessments/agent-system-assessment.md.
P

set +e
bash "$LINK_FIX" --map "$MAP_M6" --apply --scan-dir "$TMP_M6" 2>/dev/null
content_after_first="$(cat "$PLAN_M6")"
bash "$LINK_FIX" --map "$MAP_M6" --apply --scan-dir "$TMP_M6" 2>/dev/null
rc_m6=$?
content_after_second="$(cat "$PLAN_M6")"
set -e

if [ "$rc_m6" -eq 0 ] && [ "$content_after_first" = "$content_after_second" ]; then
  pass "M6_IDEMPOTENT"
else
  fail "M6_IDEMPOTENT" "second --apply changed file (rc=$rc_m6); diff: $(diff <(printf '%s' "$content_after_first") <(printf '%s' "$content_after_second") | head -5 || true)"
fi
rm -rf "$TMP_M6"

# -----------------------------------------------------------------------
printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
