# Git commit intercept regex: allow any non-separator token

**Date:** 2026-04-24
**Context:** PR#35 — subagent identity-leak fix, Senna REQUEST CHANGES C1

## Lesson

When writing a regex to detect `git commit` subcommand invocations, "allow any
non-separator token between `git` and `commit`" is safer than "allow only dash-prefixed
flags". The old pattern `([[:space:]]+-[^[:space:]]+)*` misses:
- `git -c KEY=VAL commit` — positional arg after `-c` has no dash prefix
- `git -C /path commit` — path arg after `-C` has no dash prefix

Correct pattern:
```
(^|[[:space:];|&])git([[:space:]]+[^;|&[:space:]]+)*[[:space:]]+commit([[:space:]]|$)
```

This accepts any non-shell-separator token between `git` and `commit`. False positives
(e.g. `git log --format=commit`) are tolerable — the hook then checks work-scope origin and
writes config, which is a no-op for false positives.

## Denylist unification via env var

When a shell lib defines a list (e.g. `_ANONYMITY_AGENT_NAMES`) and a Python script needs
the same list, the cleanest bridge is: `export _ANONYMITY_AGENT_NAMES` in the shell wrapper
before calling `python3`. The Python script reads `os.environ.get("_ANONYMITY_AGENT_NAMES")`.
No duplication, no drift risk.

## Fail-closed on JSON parse

PreToolUse hooks that require JSON parsing must block (exit 2 + block JSON) on parse failure,
not silently exit 0. Missing python3 and malformed input are both failure modes that should
block rather than allow a potentially-malicious commit through. Check every exit-0 path.
