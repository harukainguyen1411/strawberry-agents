# Verify fixes after merge

When a PR is merged, don't assume all commits made it in — especially if the merge happened externally or if you pushed fixes late in the review cycle. Always `git checkout main && git pull` and grep for your changes before reporting done.

Learned: 2026-04-03. A follow-up commit on PR #3's feature branch (Caitlyn's QC fixes) wasn't included in the merge to main. Had to create a separate follow-up PR.
