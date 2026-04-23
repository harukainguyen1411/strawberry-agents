# PR #33 round-3 APPROVE — bash-script delegation as clean bypass pattern

Date: 2026-04-23
PR: harukainguyen1411/strawberry-agents#33 (feat/inbox-write-guard)
Verdict: APPROVED at commit 83104b0

## Resolution of prior CHANGES_REQUESTED

Round 2 flagged `STRAWBERRY_SKILL=agent-ops` env-var bypass as non-plumbed at runtime
(no hook payload field, no env propagation across tool boundaries, set nowhere in prod
code). Round 3 removed the env-var entirely and instead added `scripts/agent-ops/send.sh`
which is invoked from the SKILL via the Bash tool. Because the guard matcher is
`Write|Edit` only, Bash writes structurally cannot trigger it — no signal plumbing needed.

This matches the "delegate to a bash script" pattern I recommended in the prior review.
It's the right answer for hook-bypass problems where the hook only matches specific tools:
don't try to authenticate the skill through the hook; just use a different tool that the
hook doesn't watch.

## Pattern: "how to ship a privileged operation a guard blocks"

Three options in rough order of preference:

1. **Delegate to a bash script invoked via Bash tool** — sidesteps Write/Edit/NotebookEdit
   matchers entirely. Clean, no env plumbing, testable at the script boundary. Mirrors
   the existing `list` / `new` patterns, so the skill stays internally consistent.
2. **Path-and-content pattern match** — recognize the sanctioned operation by its file
   path shape + content shape. Uses info the hook actually receives. Larger attack surface.
3. **Env-var gate** — looks tidy; almost always wrong, because skill context is not
   propagated across tool boundaries in Claude Code. Only works if the invoking tool
   is Bash and the guard inherits the shell env — which it does not for Write/Edit.

## Verification checklist I ran

1. Tests green: 13/13 on fresh worktree.
2. File mode: `send.sh` is 0755, matches sibling `list-agents.sh` / `new-agent.sh`.
3. Schema parity: end-to-end smoke produced a file with identical frontmatter to the
   documented schema (from/to/priority/timestamp/status + `---` delimiters).
4. No lingering signal refs: `git grep STRAWBERRY_SKILL` on the branch returns only
   two test-comment mentions explaining round-3 case removal.
5. Shell-metachar injection on positional arg: rejected as unknown agent (quoted
   arg, no command substitution surface).
6. Traversal via agent name: `../agents/X` resolves back into the same subtree, not
   a privilege escalation, but cosmetic weakness worth flagging as low-sev.

## Residuals flagged non-blocking

- `send.sh` accepts `../` in agent name (cosmetic; resolves back into agents/ subtree).
- ISO-8601 check is glob-loose — shape-only. Fine for intent.
- Inherent: Bash `cat > agents/X/inbox/Y.md` bypasses the guard. Known structural
  limitation of tool-boundary hooks; out of scope.

## Review URL

https://github.com/harukainguyen1411/strawberry-agents/pull/33 — state APPROVED at
2026-04-23T10:01:48Z as `strawberry-reviewers-2`.
