# Remote-control mode means Slack ping is MORE appropriate, not less

**Session:** c1463e58 (2026-04-25, second post-compact leg)
**Source:** Evelynn FYI inbox + Duong correction

## What I got wrong

I read `/remote-control` as "user is here, so Slack ping is unnecessary." The reasoning was: if Duong is at the session, he'll see the compact message directly.

## Correct understanding

`/remote-control` (or "remote-control mode") means Duong is NOT at the CLI keyboard. He is away from the machine. The session may be running autonomously or semi-autonomously. A Slack ping is MORE appropriate in this state, not less — it's the mechanism by which Duong gets notified that something needs his attention. When he is sitting at the keyboard reading the session, he doesn't need a Slack ping because he's already watching.

## Correct sequence at compact boundary

1. Fire `mcp__slack__notify_duong` (minimal content, no secrets, attention-only signal)
2. Then run `/pre-compact-save` (or the equivalent consolidation sequence)
3. Then `/compact`

## Tags

protocol, slack, remote-control, compact-workflow, hands-off
