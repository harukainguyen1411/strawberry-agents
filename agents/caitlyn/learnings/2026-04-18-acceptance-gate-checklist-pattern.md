# Acceptance-gate checklist pattern (TDD-waived ops)

**Context:** Duong waived formal TDD (xfail-first) for the public-repo migration. The ADR asked for an explicit gate document to replace that discipline.

**Pattern that worked:**

1. **One-liner checkboxes with one-liner verifications.** Every gate is `- [ ] GATE-ID description` followed by a one-line "how to verify" — shell command, API call, file existence check, or URL to load. If a verification can't fit in a single command, split the gate in two.

2. **Gate IDs matter.** Use `P<phase>-G<n>` for phase gates and `M-G<n>` for the final migration-complete block. When a parallel task-breakdown doc (Kayn's) needs to reference gates, stable IDs prevent "gate about the branch protection thing" ambiguity. Always include a copy-paste reference block at the bottom listing all IDs.

3. **Final gate = superset of the plan's §9, not rewrite.** Preserve the source plan's acceptance criteria verbatim as the first subsection; add Caitlyn-proposed rigor (M-G12+) as a second subsection. This makes the delta auditable — Duong can see exactly what the gate doc added over §9.

4. **Verifications reference real artifacts.** `gh` commands, `jq` queries on existing workflow outputs, file-existence checks against known paths. Don't invent new infrastructure in the gate doc — wire gates to what already exists in the codebase.

5. **Placeholders must be named `<placeholder>`.** When a gate depends on a value that must be resolved later (e.g. workflow filename), write `<staging-deploy.yml>` not `staging-deploy.yml`. The reader should see at a glance that this is a TODO, and the parallel task-breakdown should make the resolution a prerequisite.

**When to use this pattern:** any plan where:
- TDD xfail-first doesn't naturally apply (migrations, infra cutovers, one-shot ops).
- There is a §9-equivalent acceptance-criteria list.
- Multiple agents will execute phases in parallel and need a shared "closed" signal.

**Output shape reference:** `assessments/2026-04-18-migration-acceptance-gates.md` — 57 gates, 7 sections, ~300 lines.

**Anti-patterns to avoid:**

- Narrative prose between gate blocks. It dilutes the contract. Keep editorial content to a single "Notes on gate design" block at the end, 6 bullets max.
- Soft verifications ("reviewer confirms X looks right"). Agent judgment is not a verification — only artifact inspection is.
- Unlabeled gates. Every checkbox gets an ID.
- Verification commands that assume local shell state. Always include absolute paths and full `gh --repo <owner>/<name>` invocations so a fresh terminal can run the gate.
