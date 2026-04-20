# xfail: §D4.3a — scripts/hooks/pre-commit-agent-shared-rules.sh
# (plans/in-progress/2026-04-20-agent-pair-taxonomy.md §D4.3a)
# Three checks: (1) shared-rules drift, (2) pair-mate symmetry, (3) model-frontmatter convention.
# Tests expected to fail until pre-commit-agent-shared-rules.sh is implemented.
# Run with: bats scripts/__tests__/pre-commit-agent-shared-rules.xfail.bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/pre-commit-agent-shared-rules.sh"
  TMP_DIR="$(mktemp -d)"
  mkdir -p "$TMP_DIR/.claude/agents/_shared"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# Helper: create a minimal agent .md file.
# make_agent <path> <name> [model] [tier] [pair_mate] [role_slot] [concern] [inlined_shared]
make_agent() {
  local path="$1"
  local name="$2"
  local model="${3:-}"
  local tier="${4:-}"
  local pair_mate="${5:-}"
  local role_slot="${6:-}"
  local concern="${7:-}"
  local inlined_shared="${8:-}"

  local frontmatter="---\nname: $name\n"
  [ -n "$model" ]      && frontmatter="${frontmatter}model: $model\n"
  [ -n "$tier" ]       && frontmatter="${frontmatter}tier: $tier\n"
  [ -n "$pair_mate" ]  && frontmatter="${frontmatter}pair_mate: $pair_mate\n"
  [ -n "$role_slot" ]  && frontmatter="${frontmatter}role_slot: $role_slot\n"
  [ -n "$concern" ]    && frontmatter="${frontmatter}concern: $concern\n"
  frontmatter="${frontmatter}---\n"

  printf "%b" "$frontmatter" > "$path"
  printf "\n# About %s\n\nPer-agent intro.\n" "$name" >> "$path"

  if [ -n "$role_slot" ] && [ -z "$concern" ]; then
    printf "\n<!-- include: _shared/%s.md -->\n" "$role_slot" >> "$path"
    if [ -n "$inlined_shared" ]; then
      printf "%s\n" "$inlined_shared" >> "$path"
    fi
  fi
}

# --- Syntax / presence ---

@test "pre-commit-agent-shared-rules.sh: script file exists" {
  [ -f "$HOOK_SCRIPT" ]
}

@test "pre-commit-agent-shared-rules.sh: passes bash -n syntax check" {
  run bash -n "$HOOK_SCRIPT"
  [ "$status" -eq 0 ]
}

# --- No agent files staged → exit 0 fast ---

@test "pre-commit-agent-shared-rules.sh: exits 0 when no .claude/agents files are staged" {
  # With an empty agents dir, no files to check → exit 0
  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
}

# ============================================================
# Check 1: Shared-rules drift
# Use an architect role (Opus slot) to avoid model-convention check 3 conflicts.
# Both pair-mates (swain=complex, azir=normal) are Opus and omit model:.
# ============================================================

@test "check1: exits 0 when inlined content byte-matches canonical shared file" {
  local shared_content="## Shared Architect Rules

- Design for next 2 years
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/architect.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  make_agent "$TMP_DIR/.claude/agents/swain.md" "swain" "" "complex" "azir" "architect" "" "$inlined"
  make_agent "$TMP_DIR/.claude/agents/azir.md"  "azir"  "" "normal"  "swain" "architect" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
}

@test "check1: exits non-zero when inlined content has drifted from canonical shared file" {
  printf "## Shared Architect Rules\n\n- Canonical rule\n" > "$TMP_DIR/.claude/agents/_shared/architect.md"

  # swain has stale inlined content; azir has matching content (only one drifted)
  local canonical_inlined="## Shared Architect Rules

- Canonical rule
"
  make_agent "$TMP_DIR/.claude/agents/swain.md" "swain" "" "complex" "azir"  "architect" "" "## Stale content"
  make_agent "$TMP_DIR/.claude/agents/azir.md"  "azir"  "" "normal"  "swain" "architect" "" "$canonical_inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "sync-shared-rules" ]] || [[ "$output" =~ "drift" ]] || [[ "$output" =~ "mismatch" ]]
}

@test "check1: error message tells user to run sync-shared-rules.sh" {
  printf "## Canonical shared content\n" > "$TMP_DIR/.claude/agents/_shared/architect.md"
  make_agent "$TMP_DIR/.claude/agents/swain.md" "swain" "" "complex" "azir"  "architect" "" "## Stale content"
  make_agent "$TMP_DIR/.claude/agents/azir.md"  "azir"  "" "normal"  "swain" "architect" "" "## Stale content"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "sync-shared-rules.sh" ]]
}

# ============================================================
# Check 2: Pair-mate symmetry
# builder slot: both Viktor (complex) and Jayce (normal) are Sonnet — use model: sonnet.
# ============================================================

@test "check2: exits 0 when pair_mate is symmetric (A→B and B→A)" {
  local shared_content="## Shared Builder Rules

- Build clean code
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/builder.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  make_agent "$TMP_DIR/.claude/agents/jayce.md"  "jayce"  "sonnet" "normal"  "viktor" "builder" "" "$inlined"
  make_agent "$TMP_DIR/.claude/agents/viktor.md" "viktor" "sonnet" "complex" "jayce"  "builder" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
}

@test "check2: exits non-zero when pair_mate is asymmetric (A→B but B points to C)" {
  local shared_content="## Shared

- rule
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/builder.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  make_agent "$TMP_DIR/.claude/agents/jayce.md"  "jayce"  "sonnet" "normal"  "viktor" "builder" "" "$inlined"
  # viktor's pair_mate points to someone else — asymmetric
  make_agent "$TMP_DIR/.claude/agents/viktor.md" "viktor" "sonnet" "complex" "rakan"  "builder" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "symmetry" ]] || [[ "$output" =~ "pair_mate" ]] || [[ "$output" =~ "asymmetric" ]]
}

@test "check2: exits non-zero when pair_mate is missing on one side (A→B but B has no pair_mate)" {
  local shared_content="## Shared

- rule
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/builder.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  make_agent "$TMP_DIR/.claude/agents/jayce.md"  "jayce"  "sonnet" "normal"  "viktor" "builder" "" "$inlined"
  # viktor has no pair_mate declared
  make_agent "$TMP_DIR/.claude/agents/viktor.md" "viktor" "sonnet" "complex" ""       "builder" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -ne 0 ]
}

@test "check2: coordinators with concern: field are exempt from symmetry check" {
  # Coordinators do not carry pair_mate — they must not fail the symmetry check
  make_agent "$TMP_DIR/.claude/agents/evelynn.md" "evelynn" "" "" "" "" "personal" ""
  make_agent "$TMP_DIR/.claude/agents/sona.md"    "sona"    "" "" "" "" "work"     ""

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
}

# ============================================================
# Check 3: Model-frontmatter convention
# Per §D1: builder:normal=Jayce (Sonnet), builder:complex=Viktor (Sonnet),
# architect:normal=Azir (Opus, omit model:), architect:complex=Swain (Opus, omit model:).
# ============================================================

@test "check3: exits 0 when Sonnet agent declares model: sonnet" {
  # builder:normal = Jayce (Sonnet medium) — must declare model: sonnet
  local shared_content="## Shared Builder Rules

- Build clean code
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/builder.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  make_agent "$TMP_DIR/.claude/agents/jayce.md"  "jayce"  "sonnet" "normal"  "viktor" "builder" "" "$inlined"
  make_agent "$TMP_DIR/.claude/agents/viktor.md" "viktor" "sonnet" "complex" "jayce"  "builder" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
}

@test "check3: exits non-zero (error) when Sonnet-role agent is missing model: sonnet" {
  # builder:normal slot (Jayce) without model: declared → error
  local shared_content="## Shared Builder Rules

- Build clean code
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/builder.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  # jayce missing model: — builder:normal is Sonnet
  make_agent "$TMP_DIR/.claude/agents/jayce.md"  "jayce"  ""       "normal"  "viktor" "builder" "" "$inlined"
  make_agent "$TMP_DIR/.claude/agents/viktor.md" "viktor" "sonnet" "complex" "jayce"  "builder" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "model" ]] || [[ "$output" =~ "sonnet" ]]
}

@test "check3: exits 0 (but warns) when Opus agent redundantly declares model: opus" {
  # architect:complex = Swain (Opus xhigh). Declaring model: opus is redundant → warning only, not error.
  local shared_content="## Shared Architect Rules

- Design for next 2 years
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/architect.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  # swain has model: opus declared — redundant but not blocking
  make_agent "$TMP_DIR/.claude/agents/swain.md" "swain" "opus" "complex" "azir"  "architect" "" "$inlined"
  make_agent "$TMP_DIR/.claude/agents/azir.md"  "azir"  ""     "normal"  "swain" "architect" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  # Exit 0 — warning only, not a blocking error
  [ "$status" -eq 0 ]
  [[ "$output" =~ "warn" ]] || [[ "$output" =~ "redundant" ]] || [[ "$output" =~ "omit" ]]
}

@test "check3: exits 0 when Opus agent correctly omits model: field" {
  # architect:complex = Swain (Opus xhigh). Omitting model: is correct.
  local shared_content="## Shared Architect Rules

- Design for next 2 years
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/architect.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  make_agent "$TMP_DIR/.claude/agents/swain.md" "swain" ""  "complex" "azir"  "architect" "" "$inlined"
  make_agent "$TMP_DIR/.claude/agents/azir.md"  "azir"  ""  "normal"  "swain" "architect" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
}

# ============================================================
# Integration: all three checks together on a valid pair
# ============================================================

@test "integration: clean pair passes all three checks" {
  # Use the builder role (both slots are Sonnet per §D1 row 5)
  local shared_content="## Shared Builder Rules

- Build clean code
- Follow patterns
"
  printf "%b" "$shared_content" > "$TMP_DIR/.claude/agents/_shared/builder.md"

  local inlined
  inlined="$(printf '%b' "$shared_content")"
  make_agent "$TMP_DIR/.claude/agents/jayce.md"  "jayce"  "sonnet" "normal"  "viktor" "builder" "" "$inlined"
  make_agent "$TMP_DIR/.claude/agents/viktor.md" "viktor" "sonnet" "complex" "jayce"  "builder" "" "$inlined"

  run bash "$HOOK_SCRIPT" --agents-dir "$TMP_DIR/.claude/agents"
  [ "$status" -eq 0 ]
}
