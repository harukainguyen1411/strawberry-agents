# Plan Frontmatter Fields

Reference for the five YAML frontmatter fields introduced or formalized by the
Orianna gate v2 ADR (`plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md`).
These fields are read by `scripts/plan-promote.sh`, `scripts/orianna-sign.sh`,
and `scripts/orianna-verify-signature.sh`.

## Field reference

### `orianna_gate_version`

| Attribute | Value |
|-----------|-------|
| Type | integer literal |
| Allowed values | `2` |
| Default | absent (grandfathered v1 behavior) |

Declares that the plan opts into the v2 gating regime. When absent,
`plan-promote.sh` logs a warning (`"grandfathered plan; gate-v1 rules applied"`)
and falls back to the existing single-phase fact-check behavior. When present
and equal to `2`, the full §D2 phase-specific Orianna checks are enforced at
every transition.

New plans created after the Orianna gate v2 ADR lands MUST include this field.
A pre-commit hook for plan creation will enforce this (tracked as a follow-up
in §D8 of the ADR).

Defined in: ADR §D8.

---

### `orianna_signature_<phase>`

| Attribute | Value |
|-----------|-------|
| Type | string |
| Allowed values | `"sha256:<hex-digest>:<iso-8601-utc>"` |
| Default | absent (no signature issued yet for that phase) |

A phase signature appended to frontmatter by `scripts/orianna-sign.sh`. One
field per phase transition:

```yaml
orianna_signature_approved:    "sha256:<hash>:<iso-timestamp>"
orianna_signature_in_progress: "sha256:<hash>:<iso-timestamp>"
orianna_signature_implemented:  "sha256:<hash>:<iso-timestamp>"
```

The `<hash>` is the SHA-256 of the plan file's body (content after the second
`---`) at signing time, normalized by `scripts/orianna-hash-body.sh` (line
endings → `\n`, trailing whitespace stripped). The `<iso-timestamp>` is UTC
ISO-8601.

Tamper-evidence relies on git commit authorship. `scripts/orianna-verify-signature.sh`
walks `git log` to find the commit that introduced each signature line and
verifies:

1. Commit author email is `orianna@agents.strawberry.local`.
2. Commit carries `Signed-by: Orianna`, `Signed-phase: <phase>`, and
   `Signed-hash: sha256:<hash>` trailers that match the frontmatter value.
3. Commit diff is scoped to exactly one file — the plan being signed.
4. Body hash recomputed from the current file matches the stored hash.

`plan-promote.sh` requires the relevant `orianna_signature_<phase>` field to be
present and pass all four checks before allowing a transition. It also enforces
carry-forward: a transition to `in-progress` requires a valid
`orianna_signature_approved`; a transition to `implemented` requires both prior
signatures to be valid.

Enforcing gate:
- `orianna_signature_approved` — `proposed → approved` gate (ADR §D2.1)
- `orianna_signature_in_progress` — `approved → in-progress` gate (ADR §D2.2)
- `orianna_signature_implemented` — `in-progress → implemented` gate (ADR §D2.3)

The `implemented → archived` transition carries no gate and does not issue a new
signature; existing signatures are preserved in the archived file.

Defined in: ADR §D1, §D1.1, §D2.

---

### `tests_required`

| Attribute | Value |
|-----------|-------|
| Type | boolean |
| Allowed values | `true`, `false` |
| Default | `true` (implicit when field is absent) |

Informs the `approved → in-progress` gate whether `kind: test` tasks must be
present in the plan's `## Tasks` section. When `true` (or absent), Orianna
requires at least one task with `kind: test` or a title matching
`^(write|add) .* test` (case-insensitive), and also requires a `## Test plan`
section and a `## Test results` section (the latter at the `in-progress →
implemented` gate).

Setting `false` explicitly opts the plan out of all test-related gate checks.
A justification for opting out should appear in the plan body alongside the
field.

```yaml
tests_required: false
```

Enforcing gate: `approved → in-progress` (ADR §D2.2) and `in-progress →
implemented` (ADR §D2.3).

Defined in: ADR §D2.2.

---

### `architecture_changes`

| Attribute | Value |
|-----------|-------|
| Type | YAML sequence of strings |
| Allowed values | one or more paths under `architecture/` |
| Default | absent |

Lists the `architecture/` file paths that this plan modifies. Must be paired
with actual edits to those files: Orianna verifies each listed path exists AND
has a `git log` entry modifying it within the window
`[approved_signature_timestamp, now]`. A listed path that was never touched
since approval is a blocking finding.

```yaml
architecture_changes:
  - architecture/agent-system.md
  - architecture/key-scripts.md
```

Exactly one of `architecture_changes` or `architecture_impact: none` must be
declared. A plan arriving at the `in-progress → implemented` gate with neither
field present is blocked. Orianna's error message points the author at ADR §D5
with a summary of both options.

Enforcing gate: `in-progress → implemented` (ADR §D2.3, §D5).

Defined in: ADR §D5.

---

### `architecture_impact`

| Attribute | Value |
|-----------|-------|
| Type | string literal |
| Allowed values | `none` |
| Default | absent |

Alternative to `architecture_changes`. Declares that this plan has no
architectural impact and therefore no `architecture/` files need to be
updated. Must be paired with a `## Architecture impact` section in the plan
body containing at least one line of justification.

```yaml
architecture_impact: none
```

```markdown
## Architecture impact

None. This plan migrates one script's error messages; no documented component
or interface changes.
```

Orianna verifies: the frontmatter value is present and equals `none`, the
`## Architecture impact` heading exists (exact heading text required), and the
section body is non-empty.

`architecture_impact: none` and `architecture_changes:` are mutually
exclusive — declaring both is a malformed plan.

Enforcing gate: `in-progress → implemented` (ADR §D2.3, §D5).

Defined in: ADR §D5.

---

## Quick reference

| Field | Type | Default | Enforcing gate |
|-------|------|---------|----------------|
| `orianna_gate_version` | integer | absent = v1 grandfathered | all gates (opt-in) |
| `orianna_signature_<phase>` | string | absent = unsigned | per-phase: approved / in-progress / implemented |
| `tests_required` | boolean | `true` | approved → in-progress, in-progress → implemented |
| `architecture_changes` | string list | absent | in-progress → implemented |
| `architecture_impact` | string (`none`) | absent | in-progress → implemented |

## Related scripts

| Script | Role |
|--------|------|
| `scripts/plan-promote.sh` | Reads all five fields; enforces gate checks before moving a plan file |
| `scripts/orianna-sign.sh` | Writes `orianna_signature_<phase>` after running the phase-appropriate check |
| `scripts/orianna-verify-signature.sh` | Validates a signature field against git history and current body hash |
| `scripts/orianna-hash-body.sh` | Normalizes plan body and emits SHA-256; sourced by sign and verify scripts |

See `architecture/key-scripts.md` for the full script table.
