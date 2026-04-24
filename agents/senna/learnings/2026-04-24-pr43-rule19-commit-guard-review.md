---
date: 2026-04-24
topic: PR #43 Rule 19 pre-commit plan-lifecycle guard — env-leaky test
verdict: CHANGES_REQUESTED
---

## PR
`harukainguyen1411/strawberry-agents#43` — `talon/rule-19-guard-hole` — author Talon.

Adds `scripts/hooks/pre-commit-plan-lifecycle-guard.sh` as commit-phase defence-in-depth
for Rule 19. The PreToolUse `pretooluse-plan-lifecycle-guard.sh` remains primary
enforcement; this new hook closes the gap where a plan-file move was pre-staged by an
earlier tool call, so the subsequent `git commit` carried the move without PreToolUse
ever observing a protected path.

## Finding that mattered — env-leaky Case 3

The test file's admin-path case (no agent env vars → should permit) invokes the hook via:

```
env GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" "$@" bash "$HOOK"
```

without `-i` or explicit `-u` unsets. The positional args in Case 3 are empty, so the
invocation inherits whatever `CLAUDE_AGENT_NAME` / `STRAWBERRY_AGENT` /
`STRAWBERRY_AGENT_MODE` the parent shell has set. In GitHub Actions these are unset
(Case 3 passes green in CI), but any agent's Claude-Code session running the test
locally has `CLAUDE_AGENT_NAME` set and Case 3 falsely FAILs — the hook correctly
treats the run as an agent (not admin) and blocks the rename.

Reproduced with:
```
CLAUDE_AGENT_NAME=kayn STRAWBERRY_AGENT_MODE=agent \
  bash scripts/hooks/tests/test-pre-commit-plan-lifecycle-guard.sh
# → Case 3 FAIL
```

Fix suggested: `env -u CLAUDE_AGENT_NAME -u STRAWBERRY_AGENT -u STRAWBERRY_AGENT_MODE`
in `invoke_hook_directly` so every case starts from a known env baseline.

## Pattern — test-harness env hygiene

For any hook whose behavior depends on "is env var X set?" versus "is env var X
equal to Y?", test scaffolds must explicitly `-u` the variables they care about
rather than relying on "pass nothing → nothing is set". The observed-nothing
model breaks the moment the test is run from an agent session (or any CI matrix
that happens to export agent-identity vars). Bake the unsets into the invocation
helper, not into individual test cases.

## Other checks that were clean

- Protected-path glob pattern matches sibling PreToolUse guard verbatim — no drift.
- `git diff --cached --name-status -M --diff-filter=ACDRM` covers A/C/D/R/M. T
  (typechange) is excluded — harmless in practice.
- Pure M on existing protected file → permitted (Aphelios/Xayah edit-in-place OK).
- `STRAWBERRY_AGENT_MODE=agent` + empty identity → blocked fail-closed (verified).
- Rename within `plans/proposed/` only (not touching a protected root) → permitted.
- Rename within same protected root (slug edit) → blocked for non-Orianna (correct).
- POSIX portability fine (no bash-4-only `${var,,}`, just `tr`).

## Residual-risk note for the next reviewer

The `env -i git commit` bypass from inside a non-Orianna agent's Bash call still
exists — PreToolUse doesn't see protected paths in a bare `git commit` AST, and
the new pre-commit hook sees an empty env and classifies it as admin. This is
not a regression introduced by PR #43 and is acknowledged in plan-lifecycle.md
as the reason PreToolUse is primary. Worth a comment in the hook header saying
so, but not blocking.

## Workflow note

`gh pr diff` + a local clone of the branch + direct `bash scripts/hooks/tests/…`
execution turned up the env-leak bug immediately. Running the test suite from an
agent session (vs assuming "CI is green therefore fine") is the check that
surfaces harness env-hygiene bugs.
