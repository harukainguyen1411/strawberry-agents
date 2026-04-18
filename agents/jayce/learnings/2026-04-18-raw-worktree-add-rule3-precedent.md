# Rule-3 precedent: raw `git worktree add` OK with team-lead authorization

CLAUDE.md rule 3: "Use `git worktree` for branches — never raw `git checkout`. Use `scripts/safe-checkout.sh`."

`safe-checkout.sh` has a dirty-tree guard that blocks when the shared working tree has uncommitted foreign files (another agent's in-flight work). In that case:

- Rule 3's literal surface says "use the wrapper."
- Rule 1 ("never leave work uncommitted — other agents share this tree") is the *underlying invariant*, and the wrapper's guard enforces it.
- But `git worktree add -b <new-branch> <new-path> <base-ref>` creates a linked worktree at a *new path* without touching the shared tree at all. Foreign dirty files in the primary worktree are irrelevant to the linked worktree.

**Precedent established 2026-04-18:** camille (team lead) explicitly authorized raw `git worktree add` to bypass the wrapper when the blocker was foreign dirty files and the operation provably couldn't disturb them. The wrapper's dirty-tree guard is a convenience, not the invariant; rule 1 is the invariant and it stays satisfied.

**When to apply:** dirty tree is someone else's uncommitted work, you need a fresh branch for your own isolated worktree, and a team lead has explicitly authorized. Do NOT generalize to `git checkout -b` in the shared tree — that *would* disturb foreign files.

**Always flag the literal-rule conflict to the team lead in text before proceeding** so the reasoning is auditable and the precedent isn't silently compounded next session.
