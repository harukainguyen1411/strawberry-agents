#!/bin/sh
# xfail: T14 — index-gen.sh does not exist yet
# Plan: plans/approved/personal/2026-04-25-assessments-folder-structure.md §Tasks Phase C T14
# Tasks: T14 impl gates on this xfail passing
#
# Run: bash scripts/assessments/test-index-gen.sh
#
# Tests that scripts/assessments/index-gen.sh:
#   C1  — emits a Markdown table with columns status/title/owner/date/path per §7 INDEX contract
#   C2  — writes "no entries yet" (or equivalent empty-sentinel) for an empty category dir
#   C3  — rejects (errors on) malformed frontmatter and names the offending file
#   C4  — is idempotent: running twice produces identical output
#   C5  — runs from repo root without arguments and produces 9 INDEX.md files (8 per-category + 1 top)
#          on a tree that has all 8 canonical categories populated

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX_GEN="$SCRIPT_DIR/index-gen.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------
# XFAIL guard — index-gen.sh must not exist yet
# -----------------------------------------------------------------------
if [ ! -f "$INDEX_GEN" ]; then
  printf 'XFAIL (expected — missing: scripts/assessments/index-gen.sh)\n'
  for c in \
    C1_OUTPUT_TABLE_COLUMNS \
    C2_EMPTY_CATEGORY_SENTINEL \
    C3_MALFORMED_FRONTMATTER_ERROR \
    C4_IDEMPOTENT \
    C5_NINE_INDEX_FILES_FULL_TREE
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 5 xfail (expected — T14 index-gen.sh not yet implemented)\n'
  exit 0
fi

# -----------------------------------------------------------------------
# Fixture helpers
# -----------------------------------------------------------------------

# Build a minimal assessments category tree under a temp dir.
# $1 = base dir; populates base/assessments/research/ with 2 valid files.
make_fixture_tree() {
  local base="$1"
  local cat_dir="$base/assessments"
  for cat in research qa-reports audits reviews retrospectives runbooks advisories artifacts; do
    mkdir -p "$cat_dir/$cat"
    touch "$cat_dir/$cat/.gitkeep"
  done

  # valid file 1 — active, research category
  cat > "$cat_dir/research/2026-04-10-tooling-survey.md" <<'FM'
---
date: 2026-04-10
author: lux
category: research
concern: personal
target: annual tooling survey
state: active
owner: lux
session: none
---

# Tooling survey

Body text here.
FM

  # valid file 2 — living, research category
  cat > "$cat_dir/research/2026-03-01-personal-ai-stack.md" <<'FM'
---
date: 2026-03-01
author: lux
category: research
concern: personal
target: personal AI stack overview
state: living
owner: lux
session: none
---

# Personal AI stack

Evergreen reference.
FM
}

# -----------------------------------------------------------------------
# C1 — output Markdown table contains columns: status/title/owner/date/path
# -----------------------------------------------------------------------
TMP_C1="$(mktemp -d)"
make_fixture_tree "$TMP_C1"

set +e
out_c1="$(bash "$INDEX_GEN" --category research --root "$TMP_C1/assessments" 2>&1)"
rc_c1=$?
set -e

# The generated output must contain a markdown table header with the four columns.
# Acceptable both pipe-delimited table and list forms as long as all four labels appear.
if [ "$rc_c1" -eq 0 ] && \
   printf '%s' "$out_c1" | grep -qi "status\|state" && \
   printf '%s' "$out_c1" | grep -qi "title\|target" && \
   printf '%s' "$out_c1" | grep -qi "owner" && \
   printf '%s' "$out_c1" | grep -qi "date" && \
   printf '%s' "$out_c1" | grep -qi "path\|file"; then
  pass "C1_OUTPUT_TABLE_COLUMNS"
else
  fail "C1_OUTPUT_TABLE_COLUMNS" "expected table with status/title/owner/date/path columns; rc=$rc_c1; output: $(printf '%s' "$out_c1" | head -10)"
fi
rm -rf "$TMP_C1"

# -----------------------------------------------------------------------
# C2 — empty category → "no entries yet" sentinel (or equivalent)
# -----------------------------------------------------------------------
TMP_C2="$(mktemp -d)"
mkdir -p "$TMP_C2/assessments/runbooks"
touch "$TMP_C2/assessments/runbooks/.gitkeep"

set +e
out_c2="$(bash "$INDEX_GEN" --category runbooks --root "$TMP_C2/assessments" 2>&1)"
rc_c2=$?
set -e

# Script must exit 0 and write some empty-sentinel into the INDEX content.
# Accept any of: "no entries yet", "empty", "none", "no files"
if [ "$rc_c2" -eq 0 ] && \
   printf '%s' "$out_c2" | grep -qi "no entries yet\|no entries\|empty\|none yet\|no files"; then
  pass "C2_EMPTY_CATEGORY_SENTINEL"
else
  fail "C2_EMPTY_CATEGORY_SENTINEL" "expected empty-sentinel text; rc=$rc_c2; output: $(printf '%s' "$out_c2" | head -5)"
fi
rm -rf "$TMP_C2"

# -----------------------------------------------------------------------
# C3 — malformed frontmatter → non-zero exit, names the offending file
# -----------------------------------------------------------------------
TMP_C3="$(mktemp -d)"
mkdir -p "$TMP_C3/assessments/audits"

# File missing 3 of the 8 mandatory fields (author, state, owner)
cat > "$TMP_C3/assessments/audits/2026-04-15-bad-frontmatter.md" <<'BAD'
---
date: 2026-04-15
category: audits
concern: personal
target: broken file missing required fields
session: none
---

# This file has malformed frontmatter (missing author, state, owner)
BAD

set +e
out_c3="$(bash "$INDEX_GEN" --category audits --root "$TMP_C3/assessments" 2>&1)"
rc_c3=$?
set -e

# Must exit non-zero and mention the filename in the error output.
if [ "$rc_c3" -ne 0 ] && \
   printf '%s' "$out_c3" | grep -q "2026-04-15-bad-frontmatter"; then
  pass "C3_MALFORMED_FRONTMATTER_ERROR"
else
  fail "C3_MALFORMED_FRONTMATTER_ERROR" "expected non-zero exit naming bad file; rc=$rc_c3; output: $(printf '%s' "$out_c3" | head -5)"
fi
rm -rf "$TMP_C3"

# -----------------------------------------------------------------------
# C4 — idempotent: running twice yields identical INDEX.md content
# -----------------------------------------------------------------------
TMP_C4="$(mktemp -d)"
make_fixture_tree "$TMP_C4"
OUT_INDEX="$TMP_C4/assessments/research/INDEX.md"

set +e
bash "$INDEX_GEN" --category research --root "$TMP_C4/assessments" --out "$OUT_INDEX" 2>/dev/null
rc_first=$?
first_sum="$(cksum "$OUT_INDEX" 2>/dev/null | awk '{print $1}')"
bash "$INDEX_GEN" --category research --root "$TMP_C4/assessments" --out "$OUT_INDEX" 2>/dev/null
rc_second=$?
second_sum="$(cksum "$OUT_INDEX" 2>/dev/null | awk '{print $1}')"
set -e

if [ "$rc_first" -eq 0 ] && [ "$rc_second" -eq 0 ] && [ "$first_sum" = "$second_sum" ]; then
  pass "C4_IDEMPOTENT"
else
  fail "C4_IDEMPOTENT" "two runs differ or failed; rc1=$rc_first rc2=$rc_second checksum1=$first_sum checksum2=$second_sum"
fi
rm -rf "$TMP_C4"

# -----------------------------------------------------------------------
# C5 — full tree: running without --category generates 9 INDEX.md files
# -----------------------------------------------------------------------
TMP_C5="$(mktemp -d)"
# Populate all 8 canonical categories with at least one valid file each
for cat in research qa-reports audits reviews retrospectives runbooks advisories artifacts; do
  mkdir -p "$TMP_C5/assessments/$cat"
  # Write a minimal valid assessment file in each category
  cat > "$TMP_C5/assessments/$cat/2026-04-01-sample.md" <<SAMPLE
---
date: 2026-04-01
author: lux
category: $cat
concern: personal
target: sample entry for $cat
state: active
owner: lux
session: none
---

# Sample $cat entry
SAMPLE
done

set +e
bash "$INDEX_GEN" --root "$TMP_C5/assessments" 2>/dev/null
rc_c5=$?
set -e

# Count INDEX.md files produced: 8 per-category + 1 top-level = 9
index_count=0
for cat in research qa-reports audits reviews retrospectives runbooks advisories artifacts; do
  [ -f "$TMP_C5/assessments/$cat/INDEX.md" ] && index_count=$((index_count + 1))
done
[ -f "$TMP_C5/assessments/INDEX.md" ] && index_count=$((index_count + 1))

if [ "$rc_c5" -eq 0 ] && [ "$index_count" -eq 9 ]; then
  pass "C5_NINE_INDEX_FILES_FULL_TREE"
else
  fail "C5_NINE_INDEX_FILES_FULL_TREE" "expected 9 INDEX.md files, found $index_count (rc=$rc_c5)"
fi
rm -rf "$TMP_C5"

# -----------------------------------------------------------------------
printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
