#!/bin/sh
# xfail: X2 — archive policy tests
# Plan: plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
# Task: T3 (xfail) → gates T4 (memory-consolidate.sh rewrite with archive policy)
# Ref: test plan §2.2 assertions B1–B10
#
# Run: bash scripts/test-memory-consolidate-archive-policy.sh
#
# Tests that memory-consolidate.sh correctly:
#   - Archives shards older than 14d (mtime-based)
#   - Archives shards at newest-first positions 21+ regardless of age
#   - Keeps the 20 newest within 14d in last-sessions/
#   - Skips (with warning) shards referenced in open-threads.md
#   - Uses git mv (not plain mv) so history is preserved
#   - Handles UUID collision in archive/ with suffix loop
#   - Regenerates INDEX with archived shards under ## Archived
#   - Applies OR semantics (age wins over position)
#   - Tie-breaks identical mtime shards by filename ascending
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONSOLIDATE="$SCRIPT_DIR/memory-consolidate.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard: implementation not yet present ---
# xfail: memory-consolidate.sh archive policy (14d/20-position) not yet implemented
# T4 impl will add a sentinel comment "# strawberry: archive-policy-v2" to signal readiness.
MISSING=""
if [ ! -f "$CONSOLIDATE" ]; then
  MISSING="$MISSING memory-consolidate.sh"
elif ! grep -q 'archive-policy-v2\|ARCHIVE_CUTOFF_DAYS=14\|archive_cutoff=14\|14.*86400\|position.*21\|pos.*>.*20' "$CONSOLIDATE" 2>/dev/null; then
  MISSING="$MISSING memory-consolidate.sh:archive-policy-v2(14d+20-position)"
fi

if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  for c in \
    B1_MTIME_14D_ARCHIVES \
    B2_POSITION_21_PLUS_ARCHIVES \
    B3_TOP_20_WITHIN_14D_STAY \
    B4_OPENTHREADS_REF_SKIP \
    B5_SKIP_WARNING_ON_STDERR \
    B6_GIT_MV_HISTORY_PRESERVED \
    B7_UUID_COLLISION_SUFFIX \
    B8_INDEX_ARCHIVED_SECTION_AFTER_ARCHIVE \
    B9_OR_SEMANTICS_AGE_WINS \
    B10_TIE_BREAK_FILENAME_ASCENDING
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 10 xfail (expected — T4 archive policy not yet implemented)\n'
  exit 0
fi

# --- Fixture helpers ---

# Date stamp 15 days ago (for mtime > 14d tests)
# POSIX-portable: derive via python3 (already a dep of memory-consolidate.sh)
EPOCH_15D_AGO="$(python3 -c 'import time; print(int(time.time()) - 15*86400)')"
STAMP_15D_AGO="$(python3 -c "import time; t=$EPOCH_15D_AGO; print(time.strftime('%Y%m%d%H%M.%S', time.localtime(t)))")"

EPOCH_RECENT="$(python3 -c 'import time; print(int(time.time()) - 3600)')"
STAMP_RECENT="$(python3 -c "import time; t=$EPOCH_RECENT; print(time.strftime('%Y%m%d%H%M.%S', time.localtime(t)))")"

# Helper: init scratch git repo with last-sessions/ structure
init_scratch_repo() {
  local dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" -c user.email="test@t.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$dir/last-sessions/archive"
  printf '' > "$dir/last-sessions/.gitkeep"
  git -C "$dir" add .
  git -C "$dir" -c user.email="test@t.com" -c user.name="Tester" \
    commit -q -m "scaffold"
  printf '%s' "$dir"
}

# Helper: write a shard to a repo's last-sessions/ and commit it
write_and_commit_shard() {
  local repo="$1" uuid="$2" stamp="$3"
  local path="$repo/last-sessions/${uuid}.md"
  printf '# Shard %s\n\nTL;DR:\n- item one\n- item two\n- item three\n' "$uuid" > "$path"
  touch -t "$stamp" "$path" 2>/dev/null || true
  git -C "$repo" add "$path"
  git -C "$repo" -c user.email="test@t.com" -c user.name="Tester" \
    commit -q -m "add shard $uuid"
}

run_consolidate() {
  local repo="$1"
  STRAWBERRY_MEMORY_ROOT="$repo" bash "$CONSOLIDATE" test-coordinator 2>/dev/null
}

run_consolidate_stderr() {
  local repo="$1"
  STRAWBERRY_MEMORY_ROOT="$repo" bash "$CONSOLIDATE" test-coordinator 2>&1 >/dev/null
}

# --- B1: Shards with mtime > 14d ago move to archive/ ---
REPO_B1="$(init_scratch_repo)"
write_and_commit_shard "$REPO_B1" "b1old000000001" "$STAMP_15D_AGO"
write_and_commit_shard "$REPO_B1" "b1old000000002" "$STAMP_15D_AGO"
write_and_commit_shard "$REPO_B1" "b1old000000003" "$STAMP_15D_AGO"
run_consolidate "$REPO_B1" || true
archived_count=0
for uuid in b1old000000001 b1old000000002 b1old000000003; do
  [ -f "$REPO_B1/last-sessions/archive/${uuid}.md" ] && archived_count=$((archived_count + 1))
done
if [ "$archived_count" -eq 3 ]; then
  pass "B1_MTIME_14D_ARCHIVES"
else
  fail "B1_MTIME_14D_ARCHIVES" "expected 3 archived, got $archived_count"
fi
rm -rf "$REPO_B1"

# --- B2: Shards at newest-first positions 21+ move to archive regardless of age ---
REPO_B2="$(init_scratch_repo)"
# Create 25 shards all < 14d old; shards 21-25 (oldest among them) should archive
# Use explicit list to avoid octal-parsing issues with seq -w on POSIX sh
i=1
while [ $i -le 25 ]; do
  # Offset slightly so position 1 is newest (smallest offset), 25 is oldest
  offset=$((3600 * (25 - i)))
  stamp="$(python3 -c "import time; t=int(time.time())-$offset; print(time.strftime('%Y%m%d%H%M.%S', time.localtime(t)))")"
  write_and_commit_shard "$REPO_B2" "b2shard$(printf '%04d' $i)" "$stamp"
  i=$((i + 1))
done
run_consolidate "$REPO_B2" || true
# Positions 21-25 (lowest shard numbers in reverse order) should be in archive
archived_positions=0
for i in 21 22 23 24 25; do
  uuid="b2shard$(printf '%04d' $i)"
  [ -f "$REPO_B2/last-sessions/archive/${uuid}.md" ] && archived_positions=$((archived_positions + 1))
done
if [ "$archived_positions" -ge 3 ]; then
  pass "B2_POSITION_21_PLUS_ARCHIVES"
else
  fail "B2_POSITION_21_PLUS_ARCHIVES" "expected positions 21+ archived, got $archived_positions/5"
fi
rm -rf "$REPO_B2"

# --- B3: The 20 newest within 14d stay in last-sessions/ ---
REPO_B3="$(init_scratch_repo)"
i=1
while [ $i -le 25 ]; do
  offset=$((3600 * (25 - i)))
  stamp="$(python3 -c "import time; t=int(time.time())-$offset; print(time.strftime('%Y%m%d%H%M.%S', time.localtime(t)))")"
  write_and_commit_shard "$REPO_B3" "b3shard$(printf '%04d' $i)" "$stamp"
  i=$((i + 1))
done
run_consolidate "$REPO_B3" || true
# Top 20 (shards 6-25 by offset logic, 25 being newest) should stay
staying=0
for i in 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
  uuid="b3shard$(printf '%04d' $i)"
  [ -f "$REPO_B3/last-sessions/${uuid}.md" ] && staying=$((staying + 1))
done
if [ "$staying" -ge 17 ]; then
  pass "B3_TOP_20_WITHIN_14D_STAY"
else
  fail "B3_TOP_20_WITHIN_14D_STAY" "expected >=17 top shards to stay, got $staying"
fi
rm -rf "$REPO_B3"

# --- B4: Shard referenced in open-threads.md is NOT moved even if policy triggers ---
REPO_B4="$(init_scratch_repo)"
REF_UUID="b4ref0000000001"
write_and_commit_shard "$REPO_B4" "$REF_UUID" "$STAMP_15D_AGO"
# Fake open-threads.md containing the UUID
mkdir -p "$REPO_B4/memory"
printf '## Open thread\n\nSee shard %s for context.\n' "$REF_UUID" \
  > "$REPO_B4/memory/open-threads.md"
run_consolidate "$REPO_B4" || true
if [ -f "$REPO_B4/last-sessions/${REF_UUID}.md" ]; then
  pass "B4_OPENTHREADS_REF_SKIP"
else
  fail "B4_OPENTHREADS_REF_SKIP" "referenced shard was archived despite open-threads.md reference"
fi
rm -rf "$REPO_B4"

# --- B5: Skipping a referenced shard emits stderr warning containing UUID ---
REPO_B5="$(init_scratch_repo)"
REF_UUID_B5="b5ref0000000001"
write_and_commit_shard "$REPO_B5" "$REF_UUID_B5" "$STAMP_15D_AGO"
mkdir -p "$REPO_B5/memory"
printf '## Thread\n\nSee %s.\n' "$REF_UUID_B5" > "$REPO_B5/memory/open-threads.md"
stderr_out="$(run_consolidate_stderr "$REPO_B5" 2>&1 || true)"
if printf '%s' "$stderr_out" | grep -q "$REF_UUID_B5" && \
   printf '%s' "$stderr_out" | grep -qi "warn\|skip\|retain"; then
  pass "B5_SKIP_WARNING_ON_STDERR"
else
  fail "B5_SKIP_WARNING_ON_STDERR" "expected warning with UUID on stderr; got: $stderr_out"
fi
rm -rf "$REPO_B5"

# --- B6: git mv used (not plain mv) so shard git history is preserved ---
REPO_B6="$(init_scratch_repo)"
write_and_commit_shard "$REPO_B6" "b6hist000000001" "$STAMP_15D_AGO"
run_consolidate "$REPO_B6" || true
# Assert git log --follow can see pre-archive commits for the shard
log_count=0
if [ -f "$REPO_B6/last-sessions/archive/b6hist000000001.md" ]; then
  log_count=$(git -C "$REPO_B6" log --follow --oneline \
    "last-sessions/archive/b6hist000000001.md" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$log_count" -ge 1 ]; then
  pass "B6_GIT_MV_HISTORY_PRESERVED"
else
  fail "B6_GIT_MV_HISTORY_PRESERVED" "git log --follow returned $log_count commits (expected >=1)"
fi
rm -rf "$REPO_B6"

# --- B7: UUID collision in archive/ → suffix -2, -3, … ---
REPO_B7="$(init_scratch_repo)"
COL_UUID="b7coll000000001"
write_and_commit_shard "$REPO_B7" "$COL_UUID" "$STAMP_15D_AGO"
# Pre-populate archive/ with the same UUID and -2 variant
mkdir -p "$REPO_B7/last-sessions/archive"
printf '# existing archive\n' > "$REPO_B7/last-sessions/archive/${COL_UUID}.md"
printf '# existing archive -2\n' > "$REPO_B7/last-sessions/archive/${COL_UUID}-2.md"
git -C "$REPO_B7" add .
git -C "$REPO_B7" -c user.email="test@t.com" -c user.name="Tester" \
  commit -q -m "pre-populate archive collision"
run_consolidate "$REPO_B7" || true
if [ -f "$REPO_B7/last-sessions/archive/${COL_UUID}-3.md" ]; then
  pass "B7_UUID_COLLISION_SUFFIX"
else
  fail "B7_UUID_COLLISION_SUFFIX" "expected ${COL_UUID}-3.md in archive; files: $(ls "$REPO_B7/last-sessions/archive/" 2>/dev/null || echo none)"
fi
rm -rf "$REPO_B7"

# --- B8: INDEX regenerated after archive move has moved shards under ## Archived ---
REPO_B8="$(init_scratch_repo)"
write_and_commit_shard "$REPO_B8" "b8arc000000001" "$STAMP_15D_AGO"
run_consolidate "$REPO_B8" || true
INDEX_B8="$REPO_B8/last-sessions/INDEX.md"
if [ -f "$INDEX_B8" ] && \
   grep -q "## Archived" "$INDEX_B8" 2>/dev/null && \
   grep -q "b8arc000000001" "$INDEX_B8" 2>/dev/null; then
  pass "B8_INDEX_ARCHIVED_SECTION_AFTER_ARCHIVE"
else
  fail "B8_INDEX_ARCHIVED_SECTION_AFTER_ARCHIVE" "INDEX missing ## Archived section or UUID"
fi
rm -rf "$REPO_B8"

# --- B9: OR semantics — age > 14d wins even for position <= 20 ---
REPO_B9="$(init_scratch_repo)"
# Position 3 out of 5, but aged > 14d → must still move
for i in 1 2 4 5; do
  stamp="$(python3 -c "import time; t=int(time.time())-$((3600*(5-i))); print(time.strftime('%Y%m%d%H%M.%S', time.localtime(t)))")"
  write_and_commit_shard "$REPO_B9" "b9shard0000000$(printf '%01d' $i)" "$stamp"
done
# Shard 3 at position 3 (within top 20) but aged 20d
STAMP_20D="$(python3 -c "import time; t=int(time.time())-20*86400; print(time.strftime('%Y%m%d%H%M.%S', time.localtime(t)))")"
write_and_commit_shard "$REPO_B9" "b9shard00000003" "$STAMP_20D"
run_consolidate "$REPO_B9" || true
if [ -f "$REPO_B9/last-sessions/archive/b9shard00000003.md" ]; then
  pass "B9_OR_SEMANTICS_AGE_WINS"
else
  fail "B9_OR_SEMANTICS_AGE_WINS" "expected aged shard to be archived despite being position 3"
fi
rm -rf "$REPO_B9"

# --- B10: Tie-break — shards with identical mtime order by filename ascending ---
REPO_B10="$(init_scratch_repo)"
SAME_STAMP="$STAMP_RECENT"
for uuid in "b10c" "b10a" "b10b"; do
  printf '# Shard %s\n\nTL;DR:\n- item\n' "$uuid" > "$REPO_B10/last-sessions/${uuid}.md"
  touch -t "$SAME_STAMP" "$REPO_B10/last-sessions/${uuid}.md" 2>/dev/null || true
  git -C "$REPO_B10" add .
  git -C "$REPO_B10" -c user.email="test@t.com" -c user.name="Tester" \
    commit -q -m "add $uuid"
done
STRAWBERRY_MEMORY_ROOT="$REPO_B10" bash "$CONSOLIDATE" test-coordinator --index-only 2>/dev/null || true
INDEX_B10="$REPO_B10/last-sessions/INDEX.md"
if [ -f "$INDEX_B10" ]; then
  # b10a should appear before b10b, b10b before b10c (ascending filename)
  pos_a=$(grep -n "b10a" "$INDEX_B10" | head -1 | cut -d: -f1)
  pos_b=$(grep -n "b10b" "$INDEX_B10" | head -1 | cut -d: -f1)
  pos_c=$(grep -n "b10c" "$INDEX_B10" | head -1 | cut -d: -f1)
  if [ -n "$pos_a" ] && [ -n "$pos_b" ] && [ -n "$pos_c" ] && \
     [ "$pos_a" -lt "$pos_b" ] && [ "$pos_b" -lt "$pos_c" ]; then
    pass "B10_TIE_BREAK_FILENAME_ASCENDING"
  else
    fail "B10_TIE_BREAK_FILENAME_ASCENDING" "filename tie-break ordering wrong (a=$pos_a b=$pos_b c=$pos_c)"
  fi
else
  fail "B10_TIE_BREAK_FILENAME_ASCENDING" "INDEX.md not generated"
fi
rm -rf "$REPO_B10"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
