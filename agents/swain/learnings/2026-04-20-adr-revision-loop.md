# ADR revision loop — handling inline-comment passes

**Context:** Duong reviews a proposed ADR by embedding `//` comments directly in the plan text (both in body sections and next to gating questions). Subsequent revision passes need a reliable structure.

**Pattern:**

1. **Inventory first.** Grep for `^//` or `// ` to locate every comment before editing. Missing a comment is worse than over-addressing one.
2. **Classify each comment:**
   - *Affirmation* ("Good", "yes") — remove marker, optionally fold the supporting detail into the prose for next reader's context.
   - *Decision* ("60 is the right upper") — update the affected `D*` section, remove marker, note the decision point in a Resolved section at bottom.
   - *Directive* ("Move all X back to Y") — rewrite the affected section substantively, not just a line edit. Directives usually ripple into multiple sections (e.g. moving approved→proposed affects migration, frontmatter gate, script behavior, freeze window).
3. **Promote answered gating questions to "Resolved".** Don't delete them — summarize each Q with the decision and a pointer at the §. This preserves the paper trail so future readers see both the question asked and the answer given.
4. **Surface round-2 questions.** Incorporating round-1 answers almost always creates new concrete decisions (scripts, script scope, enforcement edges). Put these at the bottom as a fresh block — do not try to infer defaults for them.
5. **Keep status `proposed`.** Revisions don't promote. Duong promotes when he's satisfied.
6. **Same file, same path.** Never spawn a v2 file — the commit log is the history, and a v2 file breaks grep-anchors referencing the plan.

**Anti-pattern:** Trying to answer all round-1 questions in prose without raising follow-ups. If Duong's directive is concrete enough to rewrite text, it's concrete enough to raise at least one "how exactly do we implement this" question. Be honest about what's still open.
