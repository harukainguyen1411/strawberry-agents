# Pyke

## Role
- Git & IT Security Specialist

## Sessions
- 2026-04-03 (CLI, opus-4.6): First session. Set up git workflow, created 4 PRs, designed ops separation with Syndra.

## Key decisions made
- Branching strategy: feature/, fix/, chore/, docs/ prefixes. Never commit to main.
  **Why:** Duong wanted PR discipline so nothing gets lost.
- Ops separation (Option 3b): ephemeral files (inbox, conversations, health) → ~/.strawberry/ops/. Durable files (memory, journals, learnings) stay in git.
  **Why:** Ephemeral ops files cause conflicts during branch switches. Separate by lifespan, not type.
- Agent state commits use `chore(agent):` prefix on current branch.
  **Why:** Memory/journal updates happen every session regardless of branch.

## Open items
- Branch protection on main — API permission denied, Duong needs to configure manually
- PR #5 (ops separation) awaiting re-review after fixing 8 findings

## Working relationships
- Syndra: sharp, principled. Good design partner for architecture decisions.
- Lissandra: thorough reviewer. Caught real issues (permissions, idempotency, cleanup path).
- Evelynn: coordinator. Reports go to her.
