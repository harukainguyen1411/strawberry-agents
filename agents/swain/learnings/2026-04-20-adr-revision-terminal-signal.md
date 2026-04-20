# ADR revision rounds: when to stop iterating

Signal that an ADR is ready for promotion (not another revision round):

1. The open-gating-questions block at the bottom of the ADR is empty, or every question in it is flagged "polish-level, does not block current state."
2. All prior rounds' gating questions have been moved to "Resolved gating questions (round N)" sections, each with a one-liner decision + § pointer into the body.
3. Internal cross-references (e.g. "see §D4.3a check #2") all point at sections that exist in the current file — no stale pointers to sections that were renumbered or removed.
4. No structural (architecture-level) question surfaced in the latest round — only polish (wording, examples, adding an exemption to an existing rule).

When any of these fail, keep iterating. When all four hold, the ADR is ready for Orianna fact-check + `scripts/plan-promote.sh proposed → approved`.

Heuristic cost control: if an ADR is on round 5+, audit whether the accumulated revision notes have displaced structural reasoning. The purpose of the ADR is the decision, not the decision trail — a long "Resolved gating questions" tail is a smell that the decision surface was never fully explored in round 1. Future first-round drafts should spend more budget on the upfront decision matrix and less on hedging via open questions.

Applied to the agent-pair taxonomy ADR: 5 revision rounds, terminated when round 3 raised only Q8/Q9/Q10 (all polish), and round 4 (this session) resolved all three without surfacing structural follow-ups. The taxonomy ADR is now at terminal state.
