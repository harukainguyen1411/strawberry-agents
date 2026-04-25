# 2026-04-25 — PR #33 missmp/mcps T-new-D canonical start.sh — REQUEST CHANGES

## Context

Work-scope review of `missmp/mcps` PR #33: rewrite of `mcps/slack/scripts/start.sh`
to use the canonical `tools/decrypt.sh --exec` pattern from secretary ADR §4.2.
Previous PR #48 in `harukainguyen1411/strawberry-agents` was closed for targeting
the wrong repo (personal TS MCP, two tokens) — this is the work redo.

Comment URL: https://github.com/missmp/mcps/pull/33#issuecomment-4318171127

## Verdict

**REQUEST_CHANGES** — one critical blocker (C1). The canonical pattern itself
is correctly implemented; TDD ordering correct; single-secret claim verified;
boundary check passes. Mechanical fix only.

## C1 — cross-repo path arithmetic produces non-existent directory

The PR computes:
```bash
MCP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # workspace/mcps/slack
REPO_ROOT="$(cd "$MCP_DIR/../../.." && pwd)"                  # ~/Documents/Work/mmp/
STRAWBERRY_AGENTS="$REPO_ROOT/strawberry-agents"              # NON-EXISTENT
```

The ADR §4.2 canonical template (line 204) assumes start.sh lives **inside** the
agents repo, where `../../..` from `mcps/<name>/scripts/start.sh` lands on the repo
root. This PR adapted that assumption blindly: start.sh is in `missmp/mcps`, a
**separate filesystem subtree** under `~/Documents/Work/mmp/workspace/mcps/`.
Real agents repo lives at `~/Documents/Personal/strawberry-agents` — no symlink,
sibling clone, or env override.

`.mcp.json` invokes by absolute path, so `${BASH_SOURCE[0]}` is fixed at runtime
and `../../..` deterministically lands on `~/Documents/Work/mmp/`. The script
exits 1 at the AGE_BLOB existence check with a misleading "blob not provisioned"
message — the real failure is the entire computed path being wrong.

The smoke test misses this because it's grep-only against the script text — it
never executes against a real layout. Contract assertion #6 (`grep -qE
"secrets/work/runtime|STRAWBERRY_AGENTS.*secrets"`) passes on the broken script
because the literal string is present.

## Fix recommendations (offered in PR comment)

1. **Env-var with default** — `STRAWBERRY_AGENTS="${STRAWBERRY_AGENTS:-$HOME/Documents/Personal/strawberry-agents}"`. Lowest-friction.
2. **`.mcp.json` env injection** — `"env": { "STRAWBERRY_AGENTS": "/abs/path" }`.
3. **Symlink convention** — require `~/Documents/Work/mmp/strawberry-agents` to symlink. Fragile.

Plus: add a contract assertion in the smoke test for env override OR
absolute-path-pattern, and a runtime `[[ -d "$STRAWBERRY_AGENTS" ]] || fail`
in start.sh with a clear error.

## What I verified positively

- **Single-secret claim:** `grep -nE "os\.(getenv|environ)" mcps/slack/server.py`
  yielded only `SLACK_USER_TOKEN` (line 54), `SLACK_TOKEN` (line 57), `MCP_HOST`,
  `MCP_PORT`. Last two are non-secret HTTP-mode config, not consumed in stdio
  mode. Bot fallback unprovisioned in work deployment. `--var SLACK_USER_TOKEN`
  alone is correct. T-new-C not blocking.
- **Boundary check passes:** `decrypt.sh` `REPO_ROOT` derives from `$0` (the
  decrypt.sh path itself, which is canonical), so `secrets_abs=<agents>/secrets`.
  The `--target` from start.sh is absolute under that prefix → prefix-check
  accepts at line 84–87 happy path. Relative-path fallback case-glob bug
  (`case "$parent" in secrets|secrets/*)`) doesn't trigger because parent dir
  exists.
- **No plaintext transit:** `--exec` form, stdin redirect, `set -euo pipefail`,
  `uv` dep check, and removal of `.env` sourcing all clean.
- **TDD ordering:** xfail `79b613b` strictly before impl `b9227c6`. Rule 12 OK.

## Lessons / class of bug

1. **ADR canonical templates are not portable across repos without an explicit
   anchor.** When a §4.2 template assumes "start.sh lives in the agents repo,"
   a copy-paste into a sibling repo at a different filesystem location MUST
   substitute the path-derivation step with an env var or absolute path.
   Future MCP migrations (P1-T4 fathom, P1-T5 postgres, etc. — all in
   missmp/mcps) will hit the same trap. Recommend updating ADR §4.2 to add a
   "cross-repo invocation" subsection.

2. **Grep-based smoke tests miss path-arithmetic bugs.** The contract test
   here checks token names and string patterns but cannot validate that
   computed paths exist. Class of bug: any contract test that doesn't
   actually execute the artifact is blind to layout-dependent failures.
   When a test passes but the code clearly couldn't run end-to-end, look
   for runtime concerns the grep can't see.

3. **Misleading error messages compound diagnosis cost.** The "blob not
   provisioned" exit-1 here would send the next operator down the wrong
   debug path (re-running the encrypt task) before they realized the
   directory above doesn't exist. Always validate sanity preconditions
   (parent dir, sibling tool) before specific resource preconditions.

## Anonymity scan caught my drafting

First post attempt rejected by `scripts/post-reviewer-comment.sh` exit 3 — body
contained agent names and a github handle. Cleaned up by replacing with neutral
descriptors ("the upstream blob-provisioning task", "single-developer reality")
and re-posted. The scan does its job; I should pre-scrub before invoking.

## Outcome

Posted as PR comment under `duongntd99` (work-concern reviewer-auth path).
Sona handles re-dispatch to fix C1.
