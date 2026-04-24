# PR #35 review — T1 regex bypass on `git -c KEY=VAL commit`

**Date:** 2026-04-24
**PR:** harukainguyen1411/strawberry-agents #35
**Verdict:** REQUEST CHANGES (posted as comment via `scripts/post-reviewer-comment.sh` — T3 wrapper canonical path per caller directive)

## The bug

T1 hook (`scripts/hooks/pretooluse-work-scope-identity.sh`) uses this regex to
detect `git commit`:

    (^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)

The middle group `([[:space:]]+-[^[:space:]]+)*` only accepts tokens that begin
with `-`. Both of these slip through:

- `git -c user.name=Viktor commit` — the `user.name=Viktor` positional is not
  dash-prefixed, so the whole pattern fails to match and T1 exits without
  rewriting config.
- `git -C /path/to/worktree commit` — same reason; `-C` takes a positional.

The plan (T1 detail) *explicitly* mentions `git -c ... commit` as an attack
vector, so this is not just a theoretical gap — it's plan spec not met.

Defence-in-depth T2 catches this on a real commit *only if the pre-commit hook
is installed in the target work-repo*. That install lives in a separate plan
(Sona's lane), so on a fresh work clone the PreToolUse layer is all that
stands.

## Fix shape

Either:

1. Allow non-dash tokens between `git` and `commit`:
   `(^|[[:space:]])git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)`

   — but that's fuzzy (matches `git fetch commit`-style false positives).

2. Better: match against the set of known pre-`commit` option forms:
   `(^|[[:space:]])git([[:space:]]+(-[^[:space:]]+|[^-][^[:space:]]*=[^[:space:]]+|/[^[:space:]]+))*[[:space:]]+commit([[:space:]]|$)`

3. Simpler: just lex the command and look for `commit` as the first non-option
   git subcommand. Python shlex handles this in four lines.

Recommend option 3 — robust against future flag surprises.

## Test-plan gap

INV-1a only probed `git commit -m test`. Add two regression tests:

```bash
# bypass form 1: -c override
payload='{"tool_name":"Bash","tool_input":{"command":"git -c user.name=Viktor commit -m test","cwd":"'$wdir'"}}'
# bypass form 2: -C dir-switch
payload='{"tool_name":"Bash","tool_input":{"command":"git -C '$wdir' commit -m test","cwd":"'$wdir'"}}'
```

Both must assert `user.name` in `--local` is rewritten to `Duongntd` after the
hook runs.

## Other findings (less critical)

- Plan says T1 is fail-closed; implementation is fail-open on missing python3
  / JSON parse / origin-read-fail. Only `git config` write failure blocks.
- Denylist drift risk: `post-reviewer-comment.sh` embeds a Python tuple of
  agent names mirroring `_ANONYMITY_AGENT_NAMES` in the shared library. Plan
  required single source of truth; implementation admits the duplication in a
  comment.
- Test quality generally happy-path; INV-4a greps for substring in combined
  stdout, matching docstring false-positives. Should parse JSON and assert
  `tool_input.env.GIT_AUTHOR_NAME == "Duongntd"`.

## Lessons for future reviews

1. **Always enumerate git invocation forms when auditing commit-interception
   hooks.** `git -c`, `git -C`, `git --git-dir=`, `git --work-tree=` are all
   in the wild. A regex that only handles dash-flags is a partial solution.

2. **Fault-inject against every plan-called-out attack vector.** If the plan
   text mentions "e.g. a scripted commit with `--author=` override" or
   "`git -c ... commit`", those ARE the test cases — don't let them slide off
   the test plan.

3. **"Fail-closed" claims deserve audit.** Re-read every exit-0 path in a
   PreToolUse hook; count how many of them would let a malicious / buggy
   caller slip through. The plan's prose and the code's exit surface should
   match.

4. **Single-source-of-truth denylists are worth enforcing at review time.**
   When a plan explicitly says "single source of truth" and the implementation
   copies the list into a second language file, flag it even if the lists
   happen to match today. Drift is a when, not an if.

5. **The T3 wrapper posts comments, not reviews.** If the user asks for a
   comment via this wrapper, it replaces (does not augment) the formal
   `gh pr review` verdict slot. Re-confirm with caller when the PR is
   personal-scope and the Rule-18 dual-slot discipline would normally apply.
