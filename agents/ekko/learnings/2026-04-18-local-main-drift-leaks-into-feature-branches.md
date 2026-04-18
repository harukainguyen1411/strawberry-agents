# Local-main drift silently leaks into feature branches

## Symptom

A feature branch's PR diff on GitHub shows files you never touched in your batch. The extra files weren't in your commit; you can't find them in `git log <branch> --author=you`. CI fails mysteriously (xfail-first, E2E, etc.) because the extra content lacks proper pairing.

## Cause

The primary checkout's `main` ref is **ahead of origin/main** — another agent in a parallel session committed directly to local main without pushing (or their push failed / hit a branch-protection retry loop). When you run `git worktree add -b <branch> <path> main`, git uses **your local main**, not origin/main.

Result: your new branch inherits the other agent's unpushed commits. From GitHub's perspective (which only knows origin), the extra commits are novel to your PR.

## Diagnostic

```
git log <your-branch> ^origin/main --oneline
```

Any commit that appears here and isn't yours is drift from the primary checkout's local main.

## Fix (after branch already pushed + PR open)

1. `git reset --hard origin/main`
2. Re-apply your intended changes (fresh edits, fresh lockfile regen).
3. `git push --force-with-lease`
4. If GitHub auto-closes the PR (it often does when the branch's old tip becomes unreachable): `gh pr reopen <number>`.

## Prevention

Before cutting a worktree, always sync with origin first:

```
git fetch origin
git -C <primary-checkout> log main ^origin/main --oneline   # should be empty
# if not empty, either push main (if those commits belong there) or
# point the worktree at origin/main directly:
git worktree add -b deps/<batch>-<date> /path/to/worktree origin/main
```

## Why `main` vs `origin/main` bites cross-session agents

The strawberry project has **multiple concurrent agent sessions sharing one local git checkout**. Any session can advance local main between the moment you clone a worktree and the moment you push. Using `main` as the worktree base trusts that local ref to match origin; `origin/main` is always the authoritative ref.

Rule of thumb: **always use `origin/main` as the worktree base ref in multi-agent environments.**
