# `effort:` is a ceiling-plus-tendency, not a floor

Per Anthropic's adaptive-thinking docs (https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking), the `effort:` dial on Sonnet 4.6 and Opus 4.7 bounds how much reasoning the model is willing to spend; it does not mandate how much it must spend on every turn.

Practical consequences for agent-definition writing:

- `effort: low` does NOT mean "never think." The model may still reach for structured reasoning if the task genuinely warrants it.
- `effort: high` does NOT mean "always think hard." On a trivial sub-task, the model can skip thinking entirely under `high` without violating the dial.
- `effort: medium` is the common case: skip thinking on trivial sub-tasks, moderate depth on normal ones, adapt upward when ambiguity demands it.

This matters when selecting a tier. Don't conflate "this role does careful reasoning" with "this role needs effort: high." If the role's task shape is mostly mechanical with occasional hard spots, `effort: medium` with adaptive thinking gives you the depth you need without paying for it on every invocation.

Opus 4.7 has adaptive thinking as the ONLY mode (automatic, non-configurable at the model level); Sonnet 4.6 has it opt-in, but roster-wide adoption unifies the semantics across families. The `effort:` dial means the same thing on both.

Corollary: when reviewing cost estimates, multiply tier-family cost × effort-tier cost, but remember that actual burn is adaptive — an `effort: high` agent handed a simple task won't burn the full high-effort budget. The multiplier is a worst-case, not an expected-case, figure.
