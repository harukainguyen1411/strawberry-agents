# Swain learnings index

- 2026-04-19-schema-change-propagation.md — schema changes touching derived totals must propagate through data model, invariants, architecture, UI, and snapshot semantics in the same edit pass | last_used: 2026-04-19
- 2026-04-19-audit-the-doc-not-the-rule.md — when auditing governance docs, verify each "enforced by X" claim against the actual hook/CI artifact; stale enforcement claims are the worst class of drift because they create false confidence | last_used: 2026-04-19
- 2026-04-20-signing-gate-threat-model.md — in solo-dev agent systems the attacker vector is omission not malice; author-email + body-hash + diff-scope beats GPG. Also: resist inference heuristics, demand explicit author declarations + verify them | last_used: 2026-04-20
- 2026-04-20-adr-revision-loop.md — revising an ADR with inline `//` comments: inventory, classify (affirmation/decision/directive), promote answered gating Qs to Resolved section, raise round-2 Qs, keep status proposed, same file path | last_used: 2026-04-20
- 2026-04-20-role-slot-decoupling.md — ADRs referencing other ADRs should name role slots not agent identities; single pointer to a taxonomy ADR resolves names; pair-mate cross-refs go in frontmatter so routing is data-driven; shared rules between pair-mates must be physically inlined (loader won't chase includes) | last_used: 2026-04-20
