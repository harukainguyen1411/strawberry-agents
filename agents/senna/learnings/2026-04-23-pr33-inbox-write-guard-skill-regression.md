# PR #33 — inbox-write-guard skill regression & body-smuggling

## Verdict
CHANGES_REQUESTED.

## Key findings

1. **Skill self-inflicted block.** The guard blocks the very path `/agent-ops send` uses (Write on `agents/*/inbox/*.md`), and skills run in the calling agent's context — so the guard's "admin bypass" only whitelists human admins, not the sanctioned skill itself. The plan's invariant #1 ("/agent-ops send is the only sanctioned path for non-admin identities") is therefore violated by the implementation. Land this and no non-admin agent can send inbox messages through any sanctioned path.

   Watch for this pattern generally: a PreToolUse guard that blocks a tool-call pattern must have a **caller-scoped** bypass if a sanctioned skill uses that same tool-call pattern. Env-signal bypass (e.g. `AGENT_OPS_SEND=1`) is the usual escape hatch; absence of such a signal is a red flag.

2. **Substring-based allow-rules are smuggleable.** `old_string CONTAINS 'status: pending' AND new_string CONTAINS 'status: read'` passes a trivially forged Edit that rewrites the whole body while wrapping the status transition. Lesson: any allow-predicate based on `CONTAINS` of a two-string transition needs a "nothing else changed" clause. Either exact-equality on the changed line, or a diff-line-count assertion.

3. **Repo-root prefix-strip for absolute paths is literal-byte.** Symlinks (`/tmp` → `/private/tmp` on macOS), worktrees, or alternative mount paths let abs-path payloads bypass the guard. Pattern mirrors plan-lifecycle guard's known limitation — inherited, not introduced, but worth flagging in reviews of guard-family PRs.

4. **MultiEdit in matcher without MultiEdit-aware payload parsing.** If the matcher includes a tool, the payload-parsing logic must handle that tool's schema. Otherwise legitimate calls fail closed and the matcher is effectively "block all." No test case caught this.

## Process notes

- Ran tests against a clone layout in `/tmp/inbox-test/` rather than the repo (the test file path-resolves `SCRIPT_DIR/../`, so dropping it into a fresh layout proves the 6 cases pass independent of repo state). All 6 pass.
- Edge-case probes used hand-crafted JSON on stdin with `env -i` to strip agent identity, and targeted env overrides for admin bypass cases.
- Lucian approved on plan fidelity before I reviewed; findings 1 and 2 are out-of-scope for Lucian (they're correctness/security, not ADR fidelity) so the split-lane review caught something the fidelity pass could not.

## Review URL
Posted via `scripts/reviewer-auth.sh --lane senna gh pr review 33 --request-changes`. State: CHANGES_REQUESTED.
