# plan-promote.sh is proposed-only — other transitions are manual

Date: 2026-04-20

`scripts/plan-promote.sh` only accepts source files in `plans/proposed/`. It refuses
with an error if you pass any other path (e.g. `plans/approved/...`).

For the `approved → in-progress` transition (and any post-proposed transition), the
correct procedure is:
1. `git mv plans/<source-dir>/<file> plans/<target-dir>/<file>`
2. Edit the frontmatter `status:` field to match the new directory name
3. `git add` the destination file and commit with `chore:` prefix

The script's guard is intentional — it exists to ensure Drive doc unpublishing is
never skipped on proposed-exit. Post-proposed plans have no Drive doc, so there is
nothing to unpublish and no script gate.
