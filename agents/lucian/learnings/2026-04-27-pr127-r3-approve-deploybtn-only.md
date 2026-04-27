# PR#127 r3 — APPROVE after T4/T5 amendment

## Context
`missmp/company-os#127` (feat/deploybtn-only-build-trigger). Re-review after I1 fix. Plan amended in strawberry-agents main `3877f345` to add T4 (doDeploy fetch wiring) and T5 (mcp_app trigger_factory strip + setup_agent.py DEPRECATED banner).

## Verdict
APPROVE at head `4d6e9cb8`.

## Lessons
- **Always re-fetch + verify head SHA before quoting source.** First pass I ran `rg trigger_factory tools/demo-studio-v3/` against the workspace HEAD (which was `d2ce4ef`, the base merge-commit on `feat/demo-studio-v3`), not the PR tip. Got a flood of hits in mcp_app.py and setup_agent.py that I almost wrote up as "T5 NOT done" — caught it because the diff `git show 3696ca3 --` clearly removed those lines. Lesson: after `git fetch origin <branch>`, either `git checkout` the PR tip into a worktree or use `git show <sha>:path/to/file` to inspect — never `rg` against a stale workspace HEAD when verifying a PR.
- **Plan §Scope amendments make re-review tractable.** The amendment listed exact line numbers (mcp_app.py L131, L289-294, L329) for what T5 must remove. Made the fidelity check mechanical: read the diff, confirm those three sites are the ones removed, done.
- **Defence-in-depth orphan retention vs. clean removal:** the plan distinguished clearly — `tool_dispatch.py` orphan is retained (T1 + Decision log entry 1), but `mcp_app.py` orphan is removed entirely (T5 amendment). No conflict because the retention rationale is "any caller that routes by string name surfaces a clear log not a NameError" and that rationale only applies to the dispatch path, not the MCP path. Worth remembering: defence-in-depth rationale is path-specific, not a blanket policy.
- **Sweep of pre-existing failing tests is in-scope when §Failure modes calls it out.** Para 1 of §Failure modes explicitly told Vi to sweep stale tests — so `4d6e9cb` updating `test_tool_dispatch_registry_shape` from 5→4 TOOLS and repurposing `test_handler_trigger_factory_proxies_trigger_build` was on-plan, not scope creep.

## Cross-lane note
None — Senna handles code-quality concerns on the doDeploy fetch error handling pattern.
