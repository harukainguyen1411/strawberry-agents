---
date: 2026-04-26
agent: senna
topic: PR #70 assessments Phase C review — shebang/POSIX bashisms + dry-run capture bug
---

# PR #70 — assessments Phase C review

## Top finding (replay-worthy)

**Tests pass via `bash <script>` masking `#!/bin/sh` + bashism mismatch.** Three new scripts (`index-gen.sh`, `migration-link-fix.sh`, `pre-commit-assessments-index-gen.sh`) declare `#!/bin/sh` but use `local` (~30 callsites) and `[ "$a" \> "$b" ]` (POSIX `[` does not specify string `>`/`<` — that's a `[[ ]]` extension). Test scripts invoke them as `bash <script>` so the shebang is never honored, and macOS `/bin/sh` is bash-in-posix-mode which tolerates both extensions. The pre-commit dispatcher re-execs by shebang, so the hook breaks the moment a contributor on Linux/Git-Bash/Windows runs it.

**Pattern to replay:** when a Bash-style script declares `#!/bin/sh`, search for `local`, `[[ `, `==`, string `\<`/`\>`, `(( ))`, `${arr[@]}`, `<(...)`, `>(...)`. If any present and tests pass on macOS only — flag as critical portability bug. Rule 10 says "POSIX-portable bash" not "strict POSIX sh"; the correct fix is `#!/usr/bin/env bash`, not removing the bashisms.

## Second finding — function-output-capture-conflated-with-stdout

`migration-link-fix.sh:rewrite_file` writes both dry-run advisory lines AND a trailing count via `printf '%d'`, then caller does `n="$(rewrite_file ...)"`. In dry-run mode `n` becomes a multi-line string; `[ "$n" -gt 0 ]` errors but is masked by `if`-context (`set -e` doesn't fire in conditionals). Result: dry-run summary always reports `0 file(s) with 0 reference(s)` even when many advisory lines printed.

**Pattern to replay:** any function that mixes "informational output" with "computed return value" via stdout capture is a bug. The fix is always: send informational output to stderr (`>&2`), reserve stdout for the captured value. Or use a different return channel.

## Third finding — `for x in $(find ...)` word-splitting

`for f in $files` where `files="$(find ...)"` breaks on whitespace in filenames. Common, silently dangerous. Always flag in code review.

## Verdict

`REQUEST_CHANGES` posted as `strawberry-reviewers-2`. PR URL: https://github.com/harukainguyen1411/strawberry-agents/pull/70

## Operational note

- Inbox-watch hook PreToolUse warning fired persistently throughout session despite arming the watcher in background twice (both exited 143). The session prompt said "use Monitor" — I do not have a Monitor tool exposed; the warning is best-effort and non-blocking (Bash calls still executed).
