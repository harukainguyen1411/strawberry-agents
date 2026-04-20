# Demo Factory Improvement Patterns

When designing a continuous improvement roadmap for an LLM-driven pipeline:

1. **Separate signal from action.** Feedback (Slack reactions, replies) is raw signal. Structured extraction (LLM call to categorize issues) bridges signal to actionable data. Auto-adjustments should be bounded and reversible.

2. **Skills are code, not configuration.** Treat skill markdown files like source code: version them, PR-review changes, never auto-update from agent output. Agents write learnings; humans approve skill changes.

3. **Template libraries have two layers.** Line-level templates (pet, motor, health) are structural. Market-level templates are refinements. Start with line-level; add market layer only when structural differences are observed empirically.

4. **Memory hygiene is architectural.** Append-only learnings with explicit supersession, archive policies for old run records, and quarterly reviews prevent gradual quality degradation from stale context injection.

5. **Baselines before targets.** For a new system, set target metrics but note that baselines must be established from first N live runs. Avoid invented baselines.
