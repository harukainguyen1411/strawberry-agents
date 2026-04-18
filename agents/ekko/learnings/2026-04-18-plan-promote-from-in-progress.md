# Learning: plan-promote.sh only handles plans/proposed/ sources

## Date
2026-04-18

## Context
Task asked to promote two plans from `plans/in-progress/` to `implemented/` using `scripts/plan-promote.sh`.

## Finding
`plan-promote.sh` strictly rejects any source not in `plans/proposed/`. The CLAUDE.md invariant 7 ("use plan-promote.sh instead of raw git mv") applies only to plans leaving `proposed/`. For transitions between other lifecycle stages (e.g. in-progress -> implemented), raw `git mv` is correct.

## Procedure used
1. `git mv plans/in-progress/<file>.md plans/implemented/<file>.md` for each plan
2. `sed -i '' 's/^status: in-progress$/status: implemented/'` to update frontmatter
3. Also update any cross-references (e.g. `parent_adr:` fields) pointing to the old path
4. `git add` specific files, then `git commit -m "chore: promote ..."`

## Also noted
- When amending a local-only commit to remove a Co-Authored-By footer, verify `git log origin/main..HEAD` shows the commit before amending. If already pushed, stop and report.
