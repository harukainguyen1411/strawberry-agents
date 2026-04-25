# 2026-04-25 — PR #33 C1 Blocker: STRAWBERRY_AGENTS path-arithmetic fix

## Context

missmp/mcps PR #33 — T-new-D canonical start.sh for Slack MCP.
Senna REQUEST_CHANGES: C1 blocker — `STRAWBERRY_AGENTS` computed via
`REPO_ROOT="$(cd "$MCP_DIR/../../.." && pwd)"` resolves to the wrong directory.

The mcps repo lives at `~/Documents/Work/mmp/workspace/mcps/`, so three levels
up yields `~/Documents/Work/mmp/`, not the Personal/ tree where strawberry-agents
lives.  From a `/tmp` worktree it resolved to `/private/strawberry-agents`.

## Fix applied

Replaced:
```bash
REPO_ROOT="$(cd "$MCP_DIR/../../.." && pwd)"
STRAWBERRY_AGENTS="$REPO_ROOT/strawberry-agents"
```

With:
```bash
STRAWBERRY_AGENTS="${STRAWBERRY_AGENTS:-$HOME/Documents/Personal/strawberry-agents}"
[[ -d "$STRAWBERRY_AGENTS" ]] || { echo "start.sh: STRAWBERRY_AGENTS path '$STRAWBERRY_AGENTS' does not exist" >&2; exit 1; }
```

## Smoke test extension

Added assertion 7 to `scripts/test-t-new-d-slack-start-sh.sh`:
- Extracts variable-assignment lines from start.sh via awk (up to and
  including `STRAWBERRY_AGENTS=`)
- Evals them in a subshell with correct `MCP_DIR` anchoring
- Asserts the resulting path exists on disk
- This class of test catches path-arithmetic bugs that grep-only tests miss

### Test confirms XFAIL before fix / PASS after fix:
- Before fix: `STRAWBERRY_AGENTS='///strawberry-agents'` — dir does not exist → FAIL
- After fix: `STRAWBERRY_AGENTS='/Users/duongntd99/Documents/Personal/strawberry-agents'` → PASS

## TDD sequence

1. Commit `4d8ba87` — smoke test extension (XFAIL on broken impl)
2. Commit `18841cd` — start.sh fix (smoke test now passes)

## Learnings

- **Path arithmetic from arbitrary worktree locations is always wrong** for
  cross-repo references.  Use env-overridable defaults pointing at the canonical
  absolute path.
- **Grep-only smoke tests are blind to runtime path resolution**.  Add a subshell
  eval assertion whenever a script computes a path that must exist at runtime.
- **awk snippet extraction + bash -c eval** is the lightweight pattern for testing
  shell variable assignments without running the full script (which would exec).
- Plan paths in commit messages trigger the plan-lifecycle PreToolUse guard even
  in non-strawberry-agents repos (global hooksPath).  Strip them from messages.
- This pattern (env-overridable default + sanity check) should be used for all
  future start.sh templates (fathom, postgres, etc.) per Senna's lesson #2.
