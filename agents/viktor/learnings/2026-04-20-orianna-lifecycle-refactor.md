# 2026-04-20 — Orianna gated plan lifecycle refactor (T7.1, T3.1, T6.3, T10.1, T10.2)

## Context

Executed the parallel-safe REFACTOR queue from ADR
`plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md`.

## Key learnings

### T7.1 — Identity-gated bypass in pre-commit hooks

When adding an identity restriction to an existing bypass mechanism:

1. The hook must resolve the current author email **before** the staged diff
   loop runs. Use `$GIT_AUTHOR_EMAIL` (env var set by git when running hooks)
   with a fallback to `git config user.email`.

2. Test scripts that test bypass paths must explicitly set
   `GIT_AUTHOR_EMAIL=<identity>` via env var injection when calling the hook.
   Without this, the test inherits the session's git config email and the
   identity check fires unexpectedly (TEST 3 failure pattern in this session).

3. When updating an existing test that previously tested "bypass allowed", you
   need to decide: does the test now test "admin bypass allowed" (update the
   test to pass admin email) or do you add a separate test? In this case
   TEST 3 was updated (admin bypass) and new TEST 4 (agent bypass blocked) /
   TEST 5 (admin bypass allowed) were added.

### T6.3 — flock + mkdir portable advisory lock

Pattern for POSIX-portable advisory locking (CLAUDE.md rule 10):

```sh
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if flock -n 9; then
    printf '%s\n' "$$" >&9
    LOCK_ACQUIRED=1
  else
    _pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    printf 'already running (pid %s)\n' "${_pid:-unknown}" >&2; exit 1
  fi
else
  _lock_dir="${LOCK_FILE}.dir"
  if mkdir "$_lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" > "$_lock_dir/pid"; LOCK_ACQUIRED=1
  else
    _pid="$(cat "$_lock_dir/pid" 2>/dev/null || true)"
    printf 'already running (pid %s)\n' "${_pid:-unknown}" >&2; exit 1
  fi
fi
```

Key details:
- `exec 9>FILE` + `flock -n 9` is non-blocking; the FD stays open until exit
  (flock releases with the FD), so PID must be written into the file (not FD).
- `mkdir` is atomic on POSIX filesystems; use as fallback.
- Always pair with a `trap 'unlock' EXIT INT TERM` — overriding the function
  body for the fallback path is a clean way to share the trap.

### Staging gotcha — parallel file creation

When staging a specific file (`git add scripts/plan-promote.sh`), any untracked
file that was staged in a prior partial operation can be committed instead if the
index is in an unexpected state. Always check `git diff --cached --stat` before
committing to confirm exactly which files are staged.

In this session: `scripts/orianna-hash-body.sh` (Jayce's parallel T1.1 work)
was already staged when I ran `git add scripts/plan-promote.sh` and committed —
the pre-commit hook's staging modification swapped the staged set. Required a
follow-up commit to land `plan-promote.sh`.

Mitigation: run `git diff --cached --stat` after every `git add` and before
every `git commit`.

### T3.1 — Extending a prompt file without losing v1 behaviour

Pattern used: organize checks into named Steps (A, B, C, D). Step C was v1
unchanged. Steps A, B, D are additions. Each step gets a `### Step X` heading
with clear scope. The "Scope guardrails" section was updated to list per-step
scope so Orianna doesn't over-apply each check.

Report format: add a `check_version:` frontmatter field (2 for extended) and
use step-prefixed finding entries so the report reader can see which step
produced each block.

### T10.1/T10.2 — Architecture docs for inbound scripts

When documenting scripts that don't exist yet (inbound from parallel agent):
- Mark them clearly as "inbound" with the responsible agent/task reference.
- Document per the plan spec (§D7), not from the actual file.
- Exit codes in particular are load-bearing for callers — document all of them.
