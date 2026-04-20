# 2026-04-20 Agent pair taxonomy — sync-shared-rules.sh + pre-commit hook

## Context

Built two shell scripts per plan §D4.3 and §D4.3a of `plans/in-progress/2026-04-20-agent-pair-taxonomy.md`.

## Key learnings

### 1. awk `-v` for passing shell variables into awk programs

When using awk inside a bash function with single-quoted program text, shell variables are NOT expanded inside the awk program. To pass a shell variable (like `field="role_slot"`) into awk, use `-v field="$field"`. Forgetting this causes silent `field == ""` in awk with no match.

```bash
# WRONG — field is not an awk variable, it's uninitialized
awk '... $0 ~ "^" field ": " ...' "$file"

# CORRECT
awk -v field="$field" '... $0 ~ "^" field ": " ...' "$file"
```

This bug caused check 2 (pair-mate symmetry) and check 3 (model convention) to silently pass incorrect cases because `get_frontmatter_field` always returned empty.

### 2. Test fixture design for multi-check hooks

When a hook runs multiple checks (check 1: drift, check 2: pair-mate, check 3: model), each test must provide a _fully valid fixture_ unless it's specifically testing one check's failure path. Providing only one side of a pair or missing the model: field will cause other checks to fire and fail the test for the wrong reason.

Pattern: use a role slot where BOTH pair-mates have the same model family (e.g., builder: both Viktor+Jayce are Sonnet) to simplify fixtures. For Opus-only tests, use architect (both Swain+Azir are Opus, omit model:).

### 3. Builder slots — both tracks are Sonnet (not Opus)

Common misconception: complex-track = Opus. For the feature-builder role (§D1 row 5), BOTH slots are Sonnet:
- Viktor (complex) = Sonnet high
- Jayce (normal) = Sonnet medium

Only Architect (row 1), Breakdown (row 2), Test-plan (row 3), Frontend-design (row 6), and AI-specialist complex (row 8) are Opus. Check the §D1 matrix carefully before assuming a complex slot is Opus.

### 4. Dispatcher auto-discovery — no changes to install-hooks.sh needed

`install-hooks.sh` uses a glob `pre-commit-*.sh` to auto-discover hooks at dispatch time. Any new `scripts/hooks/pre-commit-*.sh` file is automatically wired in without editing install-hooks.sh. The task mentioned "wire into install-hooks.sh" but the globbing makes it automatic. Updated `test-hooks.sh` presence check list instead.

### 5. Sync script idempotency via diff

The sync script only overwrites the agent file if content actually changed (`diff -q`). This avoids spurious mtime updates on idempotent runs, which is important because mtime changes can trigger unnecessary git status noise.

### 6. `set -euo pipefail` with heredoc-fed while loops

Using a heredoc to feed a while loop (`while read; done <<EOF ... EOF`) works correctly with `set -e` because the heredoc substitution happens before the loop. The `agent_files` variable is captured once and fed as a heredoc three times (once per check). This pattern works but is less composable than piping. If `agent_files` is empty, the heredoc creates an empty string which the while loop handles cleanly.
