# Amend-exception: recovering from tool-error partial commits

## Rule

Strawberry's git-hygiene convention is **"prefer new commit over amend"** — amends rewrite history, lose PR review context, and violate invariant #1's spirit of not silently changing what's been shared.

## The exception

**Recovering from an Edit-tool swallow that produced an incomplete commit IS a legitimate amend case.** Confirmed by camille on 2026-04-18.

## When it applies

- A sequence of `Edit` tool calls partially succeeds: some apply, some fail with `File has not been read yet` or similar.
- You commit and push what you believe is complete.
- You later discover one of the staged edits never landed (the file on disk reverted, or was never modified because the Edit errored).
- The commit is a **factually incomplete representation** of the intended change, not a scope-change or rework.

In this case, `git commit --amend` + `git push --force-with-lease` is correct because:
1. The prior commit's intent is unchanged (the commit message still describes the right thing).
2. You're not adding new scope — you're repairing a tool-level failure that produced a factual gap.
3. `--force-with-lease` (not raw `--force`) protects against overwriting anyone else's push.
4. The alternative (a follow-up commit "chore: fix missing package.json change") creates log noise for a mechanical error no reader cares about.

## When it does NOT apply

- You want to change the scope of an already-pushed commit. → **Amend no, new commit yes.**
- The branch is `main` or another shared-ref. → **Amend no; force-push to main is forbidden (invariant #18 + branch protection).**
- PR reviews already happened against the prior commit. → **Amend no; reviewers expected an immutable diff.**
- You want to amend someone else's commit. → **Never.**

## Example from 2026-04-18 session

B11b PR #171: first commit pushed contained the 4 `version.ts` edits but was missing the `marked: ^18.0.0` package.json bump (Edit tool swallowed the edit after parallel Edit calls hit "File has not been read yet" errors). Amended + `--force-with-lease`d; force-push landed cleanly on the feature branch. No reviews had posted yet. Clean recovery.
