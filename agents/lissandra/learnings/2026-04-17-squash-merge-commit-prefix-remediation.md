# Squash-Merge as Valid Commit Prefix Remediation

When a branch has a non-compliant commit prefix (e.g. `feat:` instead of `chore:`), amending branch history is not the only valid fix.

Squash-merge with a compliant `chore:` title is acceptable because:
- CLAUDE.md rule 5 enforces `chore:`/`ops:` prefix on main, not on branch history.
- The pre-push hook runs at merge time against the squashed commit title, which lands on main.
- Amending published commits creates coordination risk (force-push needed, conflicts for anyone who pulled).

**When to accept squash-merge approach:** Branch has a follow-on `chore:` remediation commit AND the merge will be squash-merged with a compliant title confirmed in advance.

**When to still require amendment:** If the team merges via merge commit (not squash), the non-compliant commit would land on main verbatim — in that case, amendment or rebase is required.
