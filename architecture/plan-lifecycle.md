# Plan Lifecycle — Phases and Promotion

This document describes how a plan moves through the lifecycle and how the Orianna
agent gates each transition.

---

## Phases

A plan moves through five sequential phases. The directory name reflects the current phase:

| Phase | Directory | Status value |
|-------|-----------|--------------|
| Authoring | `plans/proposed/` | `proposed` |
| Approved | `plans/approved/` | `approved` |
| In progress | `plans/in-progress/` | `in-progress` |
| Implemented | `plans/implemented/` | `implemented` |
| Archived | `plans/archived/` | `archived` |

---

## How to promote a plan

Invoke the Orianna agent with the plan path and target stage:

```
Agent: .claude/agents/orianna.md
Input:
  PLAN_PATH: plans/proposed/personal/2026-04-22-foo.md
  TARGET_STAGE: approved
```

Orianna will:
1. Read the plan.
2. Render **APPROVE** or **REJECT** with rationale.
3. On APPROVE: append a cosmetic `## Orianna approval` block, update `status:`, `git mv`
   the file to the target stage directory, commit with `Promoted-By: Orianna` trailer,
   and push.
4. On REJECT: return the rejection rationale. No file is moved.

---

## Authorization

The `scripts/hooks/pre-commit-plan-promote-guard.sh` hook enforces:

- **Promotion commits** (moving a file out of `plans/proposed/`): require the commit
  author email to match `scripts/hooks/_orianna_identity.txt` **AND** the commit
  message to carry a `Promoted-By: Orianna` trailer.
- **Trailer forgery** blocked: a non-Orianna author with `Promoted-By: Orianna` is
  rejected.
- **Direct creation** in non-proposed stage directories (approved, in-progress,
  implemented, archived) by a non-Orianna, non-admin author is rejected.
- **Admin bypass**: Duong's admin identity (`harukainguyen1411@gmail.com`) may promote
  or create in any stage without the trailer.
- **Admin-only paths**: `.claude/agents/orianna.md` and
  `scripts/hooks/_orianna_identity.txt` may only be modified by the admin identity.

---

## Approval block format

On APPROVE, Orianna appends to the plan:

```markdown
## Orianna approval

- **Date:** YYYY-MM-DD
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** <2-5 sentence rationale>
```

No body-hash signatures. No fact-check artifacts. The approval is captured in the
commit message body and the cosmetic block.

---

## Authoring

Use `plans/_template.md` for new plans. Required frontmatter:

- `status:` — `proposed`
- `concern:` — `personal` or `work`
- `owner:` — your agent name or `duong`
- `created:` — `YYYY-MM-DD`
- `tests_required:` — `true` or `false`

Plans with `tests_required: true` must include a non-empty `## Test plan` section.

---

## Pre-commit structural lint

`scripts/hooks/pre-commit-zz-plan-structure.sh` runs on every staged `plans/**/*.md`
and enforces five rules (see inline comments in the script). Plans under
`plans/archived/**` and `plans/_template.md` are exempt.

---

## Related

| Item | Purpose |
|------|---------|
| `.claude/agents/orianna.md` | Orianna's callable agent definition |
| `agents/orianna/memory/git-identity.sh` | Sets Orianna's git identity on session start |
| `scripts/hooks/pre-commit-plan-promote-guard.sh` | Hook enforcing promotion authorization |
| `scripts/hooks/_orianna_identity.txt` | Canonical Orianna email for hook check |
| `architecture/archive/v1-orianna-gate/plan-lifecycle.md` | Previous lifecycle doc (v1 regime) |
