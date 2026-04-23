# 2026-04-23 — Physical Guard (PR #31) Wiring

## Summary

PR #31 (`34fed4b`) merged the `pretooluse-plan-lifecycle-guard.sh` physical hook.
This session wired it into the local clone.

## What was done

1. `git pull origin main` — fast-forward from `a08e3b0` to `34fed4b`. 17 new files including:
   - `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`
   - `scripts/hooks/_lib_bash_path_scan.py`
   - `scripts/hooks/requirements.txt` (`bashlex>=0.18`)
   - `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh`
   - `scripts/hooks/tests/test-pretooluse-plan-lifecycle-integration.sh`
   - `scripts/orianna-bypass-audit.sh`

2. `bash scripts/install-hooks.sh` — completed cleanly. Listed `pretooluse-plan-lifecycle-guard.sh` in active sub-hooks.

3. `bashlex` version: **0.18** (via `importlib.metadata.version('bashlex')`).
   Note: `bashlex.__version__` attribute does not exist on 0.18 — use `importlib.metadata` to query the version. The `import bashlex` itself succeeds, which is what the guard checks.

4. `.claude/settings.json` confirmed two PreToolUse entries referencing the guard:
   - `matcher: "Bash"` → `bash scripts/hooks/pretooluse-plan-lifecycle-guard.sh`
   - `matcher: "Write|Edit|NotebookEdit"` → `bash scripts/hooks/pretooluse-plan-lifecycle-guard.sh`

## Smoke tests

| Test | Input | Expected | Result |
|------|-------|----------|--------|
| Block plan mv by ekko | `Bash` tool, `git mv plans/proposed/x.md plans/approved/x.md`, `CLAUDE_AGENT_NAME=ekko` | exit 2, rejection message | PASS |
| Allow write to learnings/ | `Write` tool, `agents/ekko/learnings/...` | exit 0 | PASS |
| Allow normal git commit | `Bash` tool, `git add ... && git commit ...` | exit 0 | PASS |
| Allow Edit on proposed/ | `Edit` tool, `plans/proposed/some-plan.md` | exit 0 (proposed is unprotected) | PASS |

## Surprising finding

`bashlex.__version__` does not exist — the module ships 0.18 without a `__version__` attribute.
The install-hooks.sh script calls `pip3 install --user -r scripts/hooks/requirements.txt` (which
installs it), and the guard itself checks `python3 -c "import bashlex"` — that check works fine.
Querying the version requires `importlib.metadata.version('bashlex')`.

## Protection boundary (confirmed from guard source)

Protected (Orianna-only):
- `plans/approved/**`
- `plans/in-progress/**`
- `plans/implemented/**`
- `plans/archived/**`

Unprotected (any agent):
- `plans/proposed/**` and everything outside `plans/`
