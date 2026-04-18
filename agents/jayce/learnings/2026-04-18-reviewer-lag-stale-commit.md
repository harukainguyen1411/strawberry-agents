# Reviewer lag — stale commit in re-review

When a reviewer posts a re-review (R38), they may have opened the PR diff before your latest
push landed in GitHub's UI. Jhin's R38 called the batch cap guard "still open" but was
reviewing 257dcb3; the fix was in f8f1b0f pushed ~minutes earlier.

Pattern: always verify reviewer's quoted SHA against `git log origin/<branch> --oneline -3`
before doing any rework. If the SHA is behind tip, reply with the current guard text and the
tip commit hash rather than re-editing. This avoids an unnecessary extra commit.

Also applies to merge-conflict errors: `git show origin/<branch>:<path>` is authoritative —
run it before touching code when a reviewer claims something is missing.
