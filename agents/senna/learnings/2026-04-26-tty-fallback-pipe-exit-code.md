# Learning — `tty | tr ... || echo fallback` doesn't actually fall back

**Date:** 2026-04-26
**Context:** PR #73 monitor-arming gate bugfixes — review found C1 critical bug.

## The pattern

```sh
tty_key="$(tty 2>/dev/null | tr '/' '_' | tr -d '\n' || echo "no-tty-$$")"
```

Author intent: when the process has no controlling tty, `tty` exits 1 → fall back to `no-tty-$$`.

## The bug

The exit status of a pipeline is the exit status of the **last** command. `tty` exits 1, but `tr` exits 0, so the pipeline exits 0, the `||` branch never fires, and `tty_key="not a tty"` (the literal stdout of `tty` when there is no tty, with embedded spaces).

Result: every non-tty session shares the same key → tty-keyed sentinels collide globally, defeating the per-tty isolation the fix was built to achieve.

## Detection signal

Look for `cmd_that_can_fail | filter | filter || fallback` — the fallback is dead code unless `set -o pipefail` is set, and even then only the last command's failure normally drives the substitution. Always test the pattern in a non-tty harness: `( exec </dev/null; bash -c 'the_command_above' )`.

## Better patterns

```sh
if t=$(tty 2>/dev/null) && [ -n "$t" ] && [ "$t" != "not a tty" ]; then
  tty_key="$(printf '%s' "$t" | tr '/' '_')"
else
  tty_key="no-tty-$PPID"
fi
```

Or with `set -o pipefail` plus checking `$?` of `tty` directly before the pipe.

## Bonus bug in same line

`$$` evaluates to the **gate script's own PID**, which is a fresh subshell on every PreToolUse hook invocation. Even if the fallback fired, the resulting key would change every call → every sentinel write would be a fresh file, every sentinel check would miss. Stable per-coordinator keys must come from a parent identifier (`$PPID`, an env var the bootstrap exports, or `CLAUDE_SESSION_ID`).

## Review takeaway

When reviewing shell that uses tty/hostname/uname/etc. as a sharding key, **always run the pipeline in the no-tty / no-hostname / failing-uname case** and inspect the resulting key string. Don't trust the `||` fallback unless you've checked it actually fires.
