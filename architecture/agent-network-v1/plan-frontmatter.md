---
Supersedes: archive/v1-orianna-gate/plan-frontmatter.md
---

# Plan Frontmatter — v2 contract

Reference for the YAML frontmatter fields used in plan files under `plans/`. These fields are read by the **Orianna agent** (`.claude/agents/orianna.md`) when evaluating plan lifecycle transitions.

The v1 Orianna-gate fields (`orianna_gate_version`, `orianna_signature_<phase>`) are retired. See `archive/v1-orianna-gate/plan-frontmatter.md` for the prior regime.

Plan lifecycle ownership is governed by Orianna (Rule 7 / Rule 19). See `plan-lifecycle.md` for the full lifecycle flow.

---

## Required fields

### `status`

| Attribute | Value |
|---|---|
| Type | string |
| Allowed values | `proposed`, `approved`, `in-progress`, `implemented`, `archived` |

Current lifecycle stage of the plan. Orianna rewrites this field at each approved transition. Do not set manually — Orianna owns this value after the first promotion.

---

### `concern`

| Attribute | Value |
|---|---|
| Type | string |
| Allowed values | `personal`, `work` |

Routes the plan into the correct subdirectory tree (`plans/<stage>/personal/` or `plans/<stage>/work/`). Set at plan creation; never changed after promotion.

---

### `owner`

| Attribute | Value |
|---|---|
| Type | string |
| Allowed values | any agent name (lowercase) or `duong` |

The agent responsible for driving this plan to completion. Orianna uses this field to verify the requesting agent at gate checks. Evelynn or Sona may override for coordinator-owned plans.

---

### `created`

| Attribute | Value |
|---|---|
| Type | ISO-8601 date string (`YYYY-MM-DD`) |

Date the plan was first written. Set at creation; never changed.

---

### `tests_required`

| Attribute | Value |
|---|---|
| Type | boolean |
| Allowed values | `true`, `false` |
| Default | `true` (implicit when field is absent) |

When `true` (or absent), Orianna requires at least one task with `kind: test` or a title matching `^(write|add) .* test` (case-insensitive) before approving the `approved → in-progress` transition. Also requires a `## Test plan` section (at that transition) and a `## Test results` section (at `in-progress → implemented`).

Setting `false` explicitly opts the plan out of all test-related gate checks. A justification must appear in the plan body alongside this field.

Enforcing gate: `approved → in-progress` and `in-progress → implemented`.

---

## Conditional fields

### `architecture_changes`

| Attribute | Value |
|---|---|
| Type | YAML sequence of strings |
| Allowed values | one or more paths under `architecture/` |
| Default | absent |

Lists the `architecture/` paths that this plan modifies. Orianna verifies each listed path exists AND was modified since the plan's approval date.

```yaml
architecture_changes:
  - architecture/agent-network-v1/taxonomy.md
  - architecture/agent-network-v1/key-scripts.md
```

Exactly one of `architecture_changes` or `architecture_impact` must be declared. Declaring both is a malformed plan.

Enforcing gate: `in-progress → implemented`.

---

### `architecture_impact`

| Attribute | Value |
|---|---|
| Type | string literal |
| Allowed values | `none`, `refactor` |
| Default | absent |

Alternative to `architecture_changes`. `none` declares no architectural impact. `refactor` declares that architecture docs were changed structurally (layout moves, consolidation) without introducing new behavioral claims. Must be paired with a `## Architecture impact` section in the plan body with at least one line of justification.

`architecture_impact: none` and `architecture_changes:` are mutually exclusive.

Enforcing gate: `in-progress → implemented`.

---

## Optional fields

### `complexity`

| Attribute | Value |
|---|---|
| Type | string |
| Allowed values | `trivial`, `simple`, `moderate`, `complex` |

Guides the coordinator on which track (quick/normal/complex) and agent tier to route to. Not read by Orianna; advisory only.

---

### `tags`

| Attribute | Value |
|---|---|
| Type | YAML sequence of strings |

Free-form tags for search and filtering. Example: `[architecture, tdd, hooks]`.

---

### `related`

| Attribute | Value |
|---|---|
| Type | YAML sequence of strings |

Paths to related plans, architecture docs, or assessments. Example: `[plans/in-progress/personal/2026-04-25-related.md]`.

---

## Quick reference

| Field | Type | Required | Enforcing gate |
|---|---|---|---|
| `status` | string | yes | all (Orianna-managed) |
| `concern` | string | yes | all |
| `owner` | string | yes | gate checks |
| `created` | date | yes | none |
| `tests_required` | boolean | no (default `true`) | `approved → in-progress`, `in-progress → implemented` |
| `architecture_changes` | string list | conditional | `in-progress → implemented` |
| `architecture_impact` | string | conditional | `in-progress → implemented` |
| `complexity` | string | no | advisory |
| `tags` | string list | no | none |
| `related` | string list | no | none |

## Example plan frontmatter

```yaml
---
status: proposed
concern: personal
owner: jayce
created: 2026-04-25
tests_required: false
complexity: simple
tags: [scripts, hooks]
architecture_impact: none
---
```

## Related

- `plan-lifecycle.md` — full lifecycle flow with per-stage gate descriptions (Rule 7 / Rule 19)
- `CLAUDE.md` Rule 7 (`#rule-orianna-promotes-plans`) — Orianna is the only agent that may move plans out of `proposed/`
- `CLAUDE.md` Rule 19 (`#rule-orianna-callable-agent`) — plan promotions are gated by the Orianna agent
- `archive/v1-orianna-gate/plan-frontmatter.md` — the prior v1 regime with `orianna_signature_<phase>` and `orianna_gate_version` fields
