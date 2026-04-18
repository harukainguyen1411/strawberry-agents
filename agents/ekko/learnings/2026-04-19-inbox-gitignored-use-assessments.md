# agents/evelynn/inbox/ is gitignored — use assessments/ for Duong-facing committed docs

`agents/*/inbox/` is in `.gitignore` (runtime message queue only). Any file meant
to persist for Duong or be referenced across sessions must go somewhere tracked.

For action-item / prerequisite asks directed at Duong, `assessments/YYYY-MM-DD-<slug>.md`
is the right location — it is committed, versioned, and matches the existing pattern
for analysis/action documents in this repo.

Do not attempt `git add agents/evelynn/inbox/<file>` — it will be rejected.
