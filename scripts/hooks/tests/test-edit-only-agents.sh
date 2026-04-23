#!/usr/bin/env bash
# Tests INV-2/INV-3 for plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md
# INV-2: Write is absent from the tools block of aphelios/kayn/xayah/caitlyn agent defs.
# INV-3: each def declares default_isolation: worktree in its frontmatter.
set -eu

REPO_ROOT="$(git rev-parse --show-toplevel)"
PASS=0
FAIL=0

fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }

for agent in aphelios kayn xayah caitlyn; do
  def="$REPO_ROOT/.claude/agents/$agent.md"
  if [ ! -f "$def" ]; then
    fail "$agent — def file missing: $def"
    continue
  fi

  # Extract frontmatter (between first two --- lines).
  fm="$(awk 'BEGIN{in_fm=0;count=0} /^---[[:space:]]*$/{count++; if(count==1){in_fm=1; next} else if(count==2){in_fm=0}} in_fm{print}' "$def")"

  # INV-2: no "- Write" line inside tools block within frontmatter.
  if echo "$fm" | grep -Eq '^[[:space:]]*-[[:space:]]*Write[[:space:]]*$'; then
    fail "$agent — INV-2 — 'Write' still present in tools list"
  else
    pass "$agent — INV-2 — 'Write' absent from tools list"
  fi

  # INV-3: default_isolation: worktree declared.
  if echo "$fm" | grep -Eq '^[[:space:]]*default_isolation:[[:space:]]*worktree[[:space:]]*$'; then
    pass "$agent — INV-3 — default_isolation: worktree declared"
  else
    fail "$agent — INV-3 — missing 'default_isolation: worktree' in frontmatter"
  fi
done

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
