# Always Check Branch Before Committing

In sessions where git operations involve stash/checkout/pop or working across multiple branches, it's easy to end up on the wrong branch without noticing.

## What happened
Committed to feature/telegram-relay and feature/shared-task-board instead of main — twice in one session. Both required reset --soft, stash, checkout main, stash pop, recommit.

## Rule
Before any `git add && git commit`, run `git branch --show-current` to confirm you're on the right branch.

## Even better
When needing to commit Tier 2 changes to main while a feature branch is checked out: use `git worktree` or stash + checkout main + pop + commit rather than assuming you know which branch is active.
