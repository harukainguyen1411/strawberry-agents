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

### Physical enforcement (PreToolUse hook — sole gate)

`scripts/hooks/pretooluse-plan-lifecycle-guard.sh` is wired into `.claude/settings.json`
as a PreToolUse hook for the `Bash` and `Write|Edit|NotebookEdit` tool matchers. It fires
**before** any tool executes, enforcing the following rules for non-Orianna agents:

**Blocked** (non-Orianna agents):
- `Bash` commands that reference protected paths (git mv, mv, cp, rm, etc.)
- `Write` to a **non-existing** file inside a protected directory (new-file creation)

**Permitted** (non-Orianna agents):
- `Edit` or `NotebookEdit` on an **existing** file in a protected directory — agents
  such as Aphelios and Xayah must be able to append Tasks/Test-plan sections to
  in-progress plans.
- `Write` to an **existing** file in a protected directory (overwrite = edit semantics).

Protected directories:
- `plans/approved/`
- `plans/in-progress/`
- `plans/implemented/`
- `plans/archived/`

Any agent whose `$CLAUDE_AGENT_NAME` / `$STRAWBERRY_AGENT` (case-insensitive) is not
`orianna` is rejected with exit 2 before the tool runs. Fail-closed: if neither env var
is set, the guard rejects access to protected paths.

`plans/proposed/` and its subtrees remain freely writable by any agent (plan authoring).

This is the **only** enforcement layer. The commit-phase guards
(`pre-commit-plan-promote-guard.sh`, `commit-msg-plan-promote-guard.sh`) were archived
to `scripts/hooks/_archive/v2-commit-phase-plan-guards/` by
`plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md` — at the commit
layer, identity is cheaply spoofable (the Ekko incident, 2026-04-23). The physical
layer prevents the move before it ever reaches git.

### Bypass detection (post-hoc, non-blocking)

`scripts/orianna-bypass-audit.sh` walks protected plan directories and checks that each
plan file was last introduced by an Orianna-authored commit. It reports orphan files to
stdout and always exits 0. This is detection only — it does not re-introduce a second
gate. Run locally: `bash scripts/orianna-bypass-audit.sh`.

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
| `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` | PreToolUse physical guard — sole enforcement layer |
| `scripts/orianna-bypass-audit.sh` | Post-hoc bypass detection (non-blocking) |
| `scripts/hooks/_archive/v2-commit-phase-plan-guards/` | Archived v2 commit-phase guards (superseded) |
| `scripts/hooks/_orianna_identity.txt` | Canonical Orianna email for hook check |
| `architecture/archive/v1-orianna-gate/plan-lifecycle.md` | Previous lifecycle doc (v1 regime) |
