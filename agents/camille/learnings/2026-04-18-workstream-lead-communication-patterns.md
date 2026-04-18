---
name: workstream-lead-communication-patterns
description: Communication failure modes observed running a 6-agent parallel workstream — message-crossing, stale state accusations, single-account reviewer constraints, and when the team lead is the one creating thrash
type: feedback
---

# Workstream lead communication patterns (2026-04-18 dependabot workstream)

Running a 6-agent workstream in parallel surfaces communication failure modes that don't appear in pair work. Captured for future lead sessions.

## Stale state is often mutual, not the teammate's fault

When a teammate reports PR state that conflicts with what I see, the correction impulse is to flag "your status is wrong." In today's session, several of those cases were me working from a stale `gh pr view` snapshot while accusing the teammate of working from stale local state. Both directions of error happened, sometimes in the same message.

**Rule:** before correcting a status report, re-query ground truth yourself. If the mismatch persists after fresh queries, frame it as "can you re-verify, I'm seeing X" rather than "you're wrong, it's X."

## Prescriptive "scope violation" framing hurts trust

Called ekko's B11a PR "scope-contaminated" and told her the learning+memory files she had in the diff were "smuggled" or "didn't belong." They were genuinely there at query time — but she hadn't put them there intentionally. The root cause was a local-main drift bug where her primary checkout had an unpushed commit that rode along into her worktree at creation time.

**Rule:** lead with diagnostic framing ("something unexpected is in the diff, can we figure out why?") instead of prescriptive fix-lists ("strip these files"). The diagnostic frame preserves trust if you turn out to be wrong, and produces better forensics either way.

## Messages crossing is a structural failure mode, not teammate inattention

I re-flagged "B11 supersede approach approved" four or five times across adjacent messages because each of ekko's follow-ups didn't reference my prior approval. She was responding in parallel with my approvals, so her messages were composed before mine landed in her inbox. Neither of us had failed to read the other — the latency between message send and delivery mattered.

**Rule:** don't re-iterate an answer more than twice in adjacent messages. If it keeps not sticking, the failure is delivery timing (messages crossing) not attention; wait for explicit acknowledgment before re-stating.

## Shared GitHub identity breaks invariant #18 for agent-authored PRs

All agents run under `harukainguyen1411`. GitHub enforces author!=reviewer at the identity level. Consequences:
- **Dependabot-authored PRs**: letter-compliant (author is bot, ekko+camille reviews show as non-author reviewer) — fine to merge on two agent reviews, subject to spirit interpretation.
- **Agent-authored PRs**: structurally unapprovable by another agent without a second human account. Must route through team-lead rollup to Duong.

**Rule:** at workstream start, classify PRs by author type. Dependabot-authored: full agent review chain works. Agent-authored: plan for human-reviewer rollup from the beginning, don't discover it mid-workstream.

## Escalate, don't unilaterally surgery teammates' branches

When ekko session-closed with PRs in broken state, my instinct was to fix them as workstream lead. Team-lead authorized that authority — but it was the right call to escalate first. "Destructive operation on another agent's in-flight work" is exactly the reversibility/blast-radius situation that warrants explicit sign-off regardless of hierarchy.

**Rule:** workstream-lead authority over teammate feature branches is real but not default — escalate for explicit authorization when you're about to force-push, rebase, or merge into someone else's branch. The cost of pausing to ask is low.
