# Destructive Branch Cleanup

When deleting a locally checked-out branch, git refuses with "Cannot delete branch ... checked out". Fix: checkout main first, then delete.

Order: `checkout main` → `branch -D` → `reset --hard origin/main`.

Also: always check `git rev-parse origin/main` before reset to confirm you know what you're resetting to.
