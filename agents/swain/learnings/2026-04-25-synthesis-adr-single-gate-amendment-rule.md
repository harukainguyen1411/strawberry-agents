# Synthesis ADRs that touch a shared gate must sequence as ONE re-amendment

When N ADRs each amend a shared structural primitive (e.g. the Orianna gate v2 frontmatter contract) within the same window, the synthesis ADR's job is not to reconcile their decisions — each ADR's decisions are independently sound. The synthesis ADR's job is to **sequence them as ONE re-amendment cycle**, not N serial cycles.

Concrete: 2026-04-25 had three independent Orianna gate v2 amendments queued — `priority:` + `last_reviewed:` (parking-lot ADR), `qa_plan:` + `## QA Plan` body (QA pipeline ADR), `## UX Spec` body + path-glob (frontend ADR). Naive sequencing = three serial Orianna re-signs, each invalidating prior body-hash signatures. Right sequencing = ONE merged re-amend in one wave (W2 of the synthesis wave plan), one re-sign cycle.

Generalizable rule: in any synthesis ADR, before authoring the wave plan, scan the source ADRs for shared-primitive-amendments. The shared primitive owns its own re-sign cycle; bundle ALL amendments into one wave for it. Never ship synthesis ADRs that imply N serial re-signs against the same primitive.

Bonus pattern: cite the consolidated wave amendment as a named conflict (this synthesis: Conflict C5) so the resolution is explicit and reviewers (Lucian fidelity, Senna code) can trace the merge.

Related: this pattern mirrors the architecture-consolidation v1 wave-batching (multiple file relocations in one wave to avoid cross-reference churn) — same principle applied to gate-spec amendments instead of file moves.
