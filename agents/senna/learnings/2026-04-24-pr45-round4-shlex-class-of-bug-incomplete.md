# PR #45 round 4 — shlex tokenizer pivot closes round-3 but leaves class-of-bug open

Date: 2026-04-24
PR: harukainguyen1411/strawberry-agents#45 (branch: talon/subagent-git-identity-as-duong)
Verdict: CHANGES_REQUESTED
Review URL: https://github.com/harukainguyen1411/strawberry-agents/pull/45#pullrequestreview-stored-at-PRR_kwDOSGFeXc74kT6J

## Round-4 pivot summary

Round 3 recommendation: replace regex-on-raw-string with `shlex.split()` tokenizer.
Round 4 delivered: python scanner in tempfile, command via `SHLEX_CMD` env var,
word-boundary regex against clean token values. All round-1/2/3 canonicals
(BP-1/2/3, NEW-BP-1/2/3) now block. 38/38 suite passes.

## Why I still blocked merge

The pivot fixes the *syntactic* form of the bypass (quotes, leading space, multi-word
values) but introduces a symmetric weakness: **shlex is lexical only**. It does not
expand command substitutions, variable references, backticks, or handle bash
line-continuation the way bash does at execve. Any attack that hides the persona
string behind a shell expansion evades the token-level regex.

I found and live-verified 9 new bypasses (NEW-BP-4 through NEW-BP-12):

| Tag | Attack shape | Why shlex misses |
|-----|-------------|------------------|
| 4 | `GIT_AUTHOR_NAME=Viktor \<newline>git commit` | `\n` glued to `git` token → tok != 'git' |
| 5 | `` GIT_AUTHOR_NAME=`echo Viktor` git commit `` | backtick is literal; splits on space inside |
| 6 | `GIT_AUTHOR_NAME="$(printf Vik; printf tor)"` | cmdsub kept as single token; no literal match |
| 7 | `eval "GIT_AUTHOR_NAME=Viktor git commit"` | eval is token[0]; git hidden in arg |
| 8 | `V=Viktor; GIT_AUTHOR_NAME=$V git commit` | `$V` kept literal |
| 9 | `GIT_AUTHOR_NAME=$(cat /file) git commit` | file read at runtime only |
| 10 | `git commit-tree` plumbing | scanner wants `tok == 'commit'` exact |
| 11 | `sh -c "GIT_AUTHOR_NAME=Viktor git commit"` | argument is one token |
| 12 | `bash -c "..."` | same |

End-to-end live-tested: each produces `Viktor <viktor@strawberry.local>` as commit author.

## Key insight for the review

**You cannot solve "is this command going to produce a persona commit?" at the
PreToolUse layer by scanning unexecuted shell source.** Bash expansion semantics
are runtime. Shlex is the closest thing to "what bash will execute" at lex time,
but cmdsub/backtick/var-expand/line-continuation/nested-shell all push work to
runtime. Every regex-on-tokens fix just forces another indirection level.

## Recommended path forward (written into review)

**Option A (structural fix):** Move enforcement to `pre-commit` hook that reads
`git var GIT_AUTHOR_IDENT` — git has already resolved the final identity at that
point (env + config + --author + -c all applied). Plus a `pre-push` / `pre-receive`
hook checking `git cat-file commit <sha>` to close the `commit-tree` plumbing
escape hatch.

**Option B (defense-in-depth at PreToolUse):** Replace value regex with an
**allowlist assertion** — identity-relevant tokens (env var values, `-c user.*=`
values, `--author` values) must be EXACTLY the literal neutral identity string.
Non-literal values (contain `$`, backtick, `$(`) fail the allowlist → block.
Doesn't catch `eval`/`sh -c`/`bash -c`/`commit-tree` but closes 6 of 9.

**Option C (minimal patch):** normalize whitespace on 'git' equality check; reject
substitution chars in identity tokens; extend commit-class to include `commit-tree`.

## Process observations

- Talon's commits followed Rule 12 correctly: xfail (502180f2) before impl (6dad4f45).
- 38/38 test suite on the branch is honest and reproducible.
- The structural pivot Senna recommended (round 3) was implemented cleanly — no
  complaint about execution, only that the approach has a ceiling.
- My probe harness had an early bug (shell arg passing) that caused a false
  negative report on `env`/`cd &&`/`true &&` cases — those DID block correctly.
  Lesson: when probing bypasses, always verify the harness itself against a
  known-good case before trusting negative results. I re-ran with a cleaner
  harness and got accurate results.

## What to do next time

1. For identity/auth/security hooks, look for runtime-vs-lex-time gap early. Ask:
   "what does the runtime actually see?" If the hook scans source text and the
   runtime sees expanded values, there is an entire class of bypass inherent to
   the architecture. Flag this as a class-of-bug concern, not a patch-level bug.
2. Build a reproducible probe harness with a verification step that re-runs the
   exact attack through `bash -c` and confirms the commit produced really does
   have persona identity. Don't rely on hook-exit-code alone — that tells you
   what the hook *thinks*, not what actually happens.
3. When recommending structural fixes, be explicit that the fix has a ceiling.
   The "shlex pivot" was my round-3 recommendation and it was the right *next*
   step, but it was not the *final* step. I should have flagged the runtime-
   expansion gap in round 3 so Talon could pick Option A upfront instead of
   doing Option C twice.

## File paths

- Hook under review: `/tmp/pr45-review/scripts/hooks/pretooluse-subagent-identity.sh`
- Test suite: `/tmp/pr45-review/scripts/hooks/tests/test-identity-leak-fix.sh`
- Review body: `/tmp/senna-round4-review.md`
