# ADR consolidation — separate commits for heterogeneous revisions

When a single consolidation session applies decisions across multiple independent surfaces (two ADRs + a memory-file fix, or an ADR + a hook change), **split commits by surface type**, even if the wall-clock cost is small. The bundling temptation is strong — "it's all one session, one chore: commit" — but it buries unrelated changes in a single diff that's hard to bisect or revert.

**Heuristic:** if two changes would each make sense as a standalone explanation to a reviewer, they deserve separate commits. Two ADR revisions driven by the same consolidation pass share a reviewer frame ("Duong's round-2 answers"); a memory-file drift fix does not.

**Concrete example — 2026-04-20 consolidation session:**

- Commit 1: both ADRs + swain memory (all flow from Duong's consolidated decision document).
- Commit 2: Evelynn's stale-memory line fix (a drift discovered during the session, unrelated to the ADR answers).

Duong explicitly called out "separate commit" for the Evelynn fix. The right default going forward is to split proactively and let the caller bundle if they prefer — "too few commits" is harder to fix retroactively than "too many" because the bundle-time information (why A and B went together) is lost.

**Corollary — commit message anchors decisions, not surfaces:** commit 1's message summarizes the decisions applied (Q9/Q10/Q11 resolutions, Lux retiering, model convention) rather than listing file paths. Decisions are the durable record; file paths are how the decisions landed. Future `git log --grep` for a decision finds the commit; `git log --stat` for a path shows the diff. Both work because the subject line leads with decisions.
