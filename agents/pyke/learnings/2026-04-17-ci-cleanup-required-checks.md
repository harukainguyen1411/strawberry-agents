# CI test removal must preserve required status checks

**Date:** 2026-04-17

When planning removal of legacy tests from a subtree, the required status checks configured in branch protection are the hard constraint — not the tests themselves. A removal plan must:

1. Enumerate required checks (read `plans/approved/*branch-protection*`).
2. For each, trace which workflow/job produces the check name.
3. Ensure each workflow still has a non-myapps target after cleanup, or the check will fail on "no tests found" / missing job.
4. Require the implementer to verify green on a no-op branch before merging.

Deleting a workflow file that emits a required check name = instantly-broken main. Safer: prune matrix entries, don't delete whole workflows, unless the workflow is 100% scoped to the dead subtree.
