## PreToolUse string-scanning is structurally weaker than post-expansion identity reads

**Date:** 2026-04-25
**Session:** c1463e58 (PR #45 rounds 1-4)

### The pattern

When enforcing identity discipline (committer/author/persona) on agent-driven git operations, PreToolUse hooks that scan the raw command string are **structurally incomplete**. Shell expansion (`$(...)`, backticks, line continuations, `eval`, `sh -c`, runtime-resolved variables) happens after the hook fires but before git resolves the actual identity. A regex scanner — and even a `shlex.split()` tokenizer, which is lexical-only — cannot see the post-expansion value.

### Concrete failure modes (all live-reproducible on PR #45 round 4)

- `git -c "user.email=viktor@strawberry.local;" commit` — quote+special-char defeats outer detector
- `GIT_AUTHOR_NAME='The Viktor' git commit` — multi-token quoted value bypasses anchored regex
- `GIT_AUTHOR_NAME=$(echo Viktor) git commit` — shlex sees literal `$(echo Viktor)`, git sees `Viktor`
- `eval "GIT_AUTHOR_NAME=Viktor git commit"` — `git` is hidden inside a quoted arg
- `bash -c "GIT_AUTHOR_NAME=Viktor git commit"` — same
- `git commit-tree` plumbing — bypasses any pattern that wants exact token `commit`

### The structural fix

**Pre-commit hook reading `git var GIT_AUTHOR_IDENT`** sees the post-expansion identity that git itself resolved. Plus a **pre-push or pre-receive hook scanning `git cat-file commit <sha>`** to catch `commit-tree` plumbing escapes. PreToolUse stays as defense-in-depth (catches the obvious cases early), but the load-bearing layer must operate on resolved values, not command strings.

### When this generalizes

Any policy that scans pre-execution command text to enforce post-execution behavior has the same gap. Examples beyond identity:
- "no `git push --force` to main" — `eval`, `sh -c`, aliases all defeat
- "no DROP TABLE in SQL" — string concatenation defeats
- "no `rm -rf /`" — variable expansion defeats

The general principle: **enforce policy at the layer where the resolved value exists**, not at the layer where the syntactic intent is expressed.

### Process lesson

When dual-pair reviewers split (one APPROVE, one CHANGES_REQUESTED across multiple rounds), the spec is wrong, not the implementation. Senna found 12 bypasses across 4 rounds on PR #45. By round 3 it was clear we were in regex-whack-a-mole; round 4's shlex pivot felt structural but only addressed parser robustness, not the post-expansion visibility gap. Should have escalated to a planner (Karma or Azir) at round 3 instead of dispatching another executor round.
