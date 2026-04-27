---
date: 2026-04-27
topic: sync→verify hooks must use symmetric depth-2 expansion
---

## Lesson

When a hook verifies that inlined content matches a canonical source file, both sides
of the comparison must use the same expansion logic that the writer (sync-shared-rules.sh)
used. A raw `cat` of the source file is wrong when the source contains depth-2
`<!-- include: -->` markers — sync strips those markers and inlines the nested content,
so the canonical side must do the same.

## Pattern

```bash
# Wrong — raw cat sees the marker line, inlined has nested content
canonical="$(cat "$shared_file")"

# Right — mirror sync's resolve_shared_content() depth-2 expansion
canonical="$(resolve_canonical "$shared_file")"
```

`resolve_canonical()` loops the shared file, and for any depth-2 `<!-- include: -->` line:
- reads the nested file
- cats it in place (no marker emitted)
- warns on missing nested file, errors on depth-3

## Where this matters

Any hook that compares against `.claude/agents/_shared/*.md` files. Currently 10 of 16
shared files end with a depth-2 include (feedback-trigger.md). Without symmetric expansion,
all agents whose primary shared file is one of those 10 get a false-positive drift error.

## Ref

PR #97, merge commit c3d7f05f — pre-commit-agent-shared-rules.sh Fix.
