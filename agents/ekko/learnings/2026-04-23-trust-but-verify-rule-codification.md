# Learning: trust-but-verify rule codification — 2026-04-23

## Task

Archive Evelynn inbox message `20260423-0932-651000.md` and codify a new
coordinator-level rule in both `agents/evelynn/CLAUDE.md` and
`agents/sona/CLAUDE.md`.

## Key facts

- `agents/*/inbox/` is gitignored — inbox moves and status updates are
  filesystem-only operations; no git staging needed or possible for inbox files.
- The archive directory `agents/evelynn/inbox/archive/2026-04/` already existed.
- Both CLAUDE.md files use `<!-- #rule-<slug> -->` anchor comments before each
  rule block. New rules should follow the same pattern.
- For Evelynn: rule was inserted before `#rule-lean-delegation` (fits thematically
  — verifying before acting, then delegating).
- For Sona: rule was inserted before `#rule-sona-background-subagents` (same
  thematic position in Sona's rules list).
- Commit was `chore:` prefix, direct to main, single commit covering both files.

## Pattern

For inbox archival:
1. Edit frontmatter: `status: pending` → `status: read`, add `read_at:` timestamp.
2. `mv` the file to `agents/<coordinator>/inbox/archive/YYYY-MM/`.
3. No git staging (gitignored).

For CLAUDE.md rule additions:
1. Pick the thematically correct insertion point.
2. Add `<!-- #rule-<slug> -->` anchor comment immediately before the bold rule heading.
3. Stage only the CLAUDE.md files, commit with `chore:` prefix, push to main.
