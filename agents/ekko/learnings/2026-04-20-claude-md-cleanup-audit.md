# 2026-04-20 — CLAUDE.md cleanup post-Lux audit

## Context

Executed Lux's system audit remediation (assessments/2026-04-21-system-audit-post-foundational-ADRs.md)
Items 1-5: CLAUDE.md rule fixes, skill frontmatter fix, anchor additions, Drive-mirror straggler removal, end-session Sona-default fix.

## Key Learnings

### Concurrent session contention on staged files

When using `git rm` to delete files and then `git add` a separate file before committing, a concurrent session can pick up ALL staged changes (including the git rm staging) and commit them before you. Always check `git diff --cached --name-only` immediately before committing to confirm only your files are staged.

### item 4 absorbed by concurrent session

The git rm of plan-fetch.sh and google-oauth-bootstrap.sh, plus the architecture/platform-parity.md row removal, were all staged but then picked up by a concurrent Lux/other-agent commit (cf2b5f2). The deletions landed correctly but under a different commit SHA than planned.

### plan-fetch.sh decision

Deleted: it was purely a Drive doc fetch helper. No other script called it. `_lib_gdoc.sh` was KEPT because `plan-promote.sh` sources it for frontmatter helpers (gdoc::frontmatter_get, gdoc::frontmatter_set, etc.) — the Drive credential functions in _lib_gdoc.sh are now dead code but removing them would require refactoring plan-promote.sh.

### end-session SKILL.md had two disable-model-invocation occurrences

The skill frontmatter had `false` in the YAML header (line 4) and a prose note at the bottom also saying `false (changed 2026-04-18)`. Edit tool needed extra context to target the frontmatter occurrence specifically.

### CLAUDE.md rules 12-18 already had anchors in strawberry-agents

Only rule 19 was missing its anchor. The strawberry (archive) CLAUDE.md was already fully up-to-date with all anchors — the strawberry-agents CLAUDE.md was the target.
