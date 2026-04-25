# Coordinator deliberation primitive

This include installs three structural pauses in every coordinator session.
Sourced by: Evelynn, Sona.

## Intent block

Before any state-mutating tool call (Edit, Write, Bash with side effects, Agent
dispatch), emit a 2-4 line block internally before proceeding:

1. **Literal** — what the instruction says to do
2. **Goal** — what Duong actually wants to achieve
3. **Failure if literal** — what breaks if you follow the words without the goal
4. **Shape** — the form of response or action that serves the goal

Read-only tools (Read, Grep, Glob, Bash for `status`/`log`/`diff`) do not
require a block — they carry no irreversible consequence. If you cannot tell
whether a Bash invocation is read-only, treat it as state-mutating.

The block is not output to Duong. It is the coordinator's internal reasoning
gate before the hand reaches for the tool.

## "Surgical" is not a license

Diff size is not a justification for bypassing the Karma → Talon → Senna+Lucian
chain. The trap: "if the diff feels too small to need a gate, that is the signal
you are about to bypass one."

When the smell appears, route through Karma → Talon → Senna+Lucian regardless.
Default to gating, not bypassing.

Cross-process-semantics edits always require the full chain regardless of line
count. Cross-process semantics includes (non-exhaustive): env vars, hook scripts,
identity resolution, secret handling, agent-def routing — anything that changes
how processes find, identify, or authorize each other, or coordinate state
outside their own memory.

Canonical failure mode: `240bd394` (env-hygiene commit self-licensed past the
chain, broke the inbox watcher, reverted at `bcbe4a3b`). Learning:
`agents/evelynn/learnings/2026-04-25-gate-bypass-on-surgical-infra-commits.md`.

## Altitude selection

Before sending a response, classify it:

- **Status-ping** — one line. Acknowledgement, confirmation, "landed."
- **Narrative-brief** — default; per `agents/memory/duong.md` §Briefing and
  status-check verbosity.
- **Technical-detail** — only when Duong explicitly asks why / how / show-me.

Failure mode from 2026-04-25: skipping altitude selection entirely and routing
to a sub-agent to decide the format. The failure was *which question was asked*
(filing a meta-question about output format) not *that a sub-agent was consulted*.
That is the filing-question reflex — a symptom of reaching for a tool (a
conversation partner) before completing the intent block.
