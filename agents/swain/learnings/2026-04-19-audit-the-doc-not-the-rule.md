# Audit the doc, not just the rule — stale enforcement claims are the worst class of governance drift

**Context:** Rules-to-hooks audit of CLAUDE.md Universal Invariants 1-18. Rule 5 (conventional commit prefix) explicitly states "the pre-push hook enforces diff-scope ↔ commit-type." Grepped `scripts/hooks/*` — no such hook. Rule 14 makes a similar claim that is actually backed by `pre-commit-unit-tests.sh`.

**Lesson:** Governance docs that describe enforcement are a three-way cross-reference problem. The rule text, the actual hook/CI artifact, and the agent's mental model must all agree. When the doc overstates enforcement, agents and reviewers plan around protection that isn't there — it's worse than a purely written rule, because nobody double-checks.

**Pattern for future audits:**

1. Don't trust the rule text. For every "enforced by X" claim, grep for X and verify it fires on the failure mode the rule describes.
2. Classify enforcement on a concrete scale (HARD / SOFT / CI-ONLY / WRITTEN-ONLY / PARTIAL) so the gap is legible — "partially enforced" is a useful category because most hooks have failure modes they don't cover (e.g. pre-commit vs pre-push vs PR-time).
3. Flag stale claims explicitly. A stale claim is worse than no claim.
4. Sort migrations by (drift risk × blast radius) / effort. Every-commit rules (like commit-prefix) beat once-a-month rules (like plan-promote) on the risk axis.

**Related learning:** `agents/evelynn/learnings/2026-04-11-rules-need-hooks.md` (written rules aren't enforcement) and `agents/evelynn/learnings/2026-04-19-hooks-cannot-invoke-tools.md` (Claude Code hook ceiling is `additionalContext`, not forced tool calls). This session builds on both: rules need hooks, AND hooks have a ceiling — so some rules correctly stay as rules.
