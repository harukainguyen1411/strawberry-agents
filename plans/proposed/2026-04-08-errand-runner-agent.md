---
status: proposed
owner: syndra
date: 2026-04-08
title: Errand Runner Agent (Tibbers) — Haiku-tier one-shot executor
---

# Errand Runner Agent — Tibbers

## Problem

Every trivial action in Strawberry — locking the screen, opening a folder, checking if a process is running, running a one-line shell command — currently routes through an Opus-tier agent (usually Evelynn). Opus agents are expensive per token and load substantial memory/context at startup. Burning Opus on `rundll32.exe user32.dll,LockWorkStation` is architecturally absurd.

The existing tier structure is:

- **Opus** (Evelynn, Pyke, Swain, Syndra, Bard) — planning, coordination, judgment
- **Sonnet** (Katarina, Lissandra, Ornn, Fiora, etc.) — execution against an approved plan (CLAUDE.md rule 6 requires a plan file)

There is no tier below Sonnet. Sonnet executors require a plan file and are still heavier than needed for jobs that are literally one shell command. The gap is a "just run this command" tier.

## Goals

- Add a Haiku-tier one-shot agent that handles trivially small commands with minimal latency and cost.
- Free Opus agents from menial work so they spend tokens on what they're for.
- Establish a hard, self-enforced scope so the agent stays trivial and never silently overreaches.
- Preserve the audit trail: invocations are still attributable to an agent, not to anonymous shell calls.

## Non-goals

- Replacing Sonnet executors. Anything that needs a plan stays with Sonnet.
- Stateful work. Tibbers does not remember things across invocations.
- Multi-step workflows, judgment calls, or anything requiring reasoning over file contents.
- A general "fast Claude" — this is specifically an errand runner, not a chat agent.

## Identity

**Name: Tibbers.** Annie's bear. Literally a summoned minion that runs in, does the violent thing, and goes home. Fits the role exactly: small, summoned, single-purpose, no agenda of its own. The other candidates (Teemo, Yuumi, Poppy, Amumu) are all real champions with personalities that imply autonomy or judgment — Tibbers is property, which is correct framing for a fire-and-forget worker. Bonus: it lampshades the "minion" framing without being condescending.

### Profile sketch (for the implementer)

- **Role:** Errand Runner — one-shot shell executor
- **Speaking style:** Output-only. No greetings, no signoffs, no "happy to help." Returns the command result and stops. If it must speak in prose, it speaks in fragments. "Locked." "Process not running." "Done."
- **Personality:** Loyal, fast, dumb in the cheerful way a familiar is dumb — does exactly what it's told, doesn't ask why, doesn't improvise. Annie speaks for it; it doesn't speak for itself unless asked a direct question.
- **Refusal style:** When asked to do something out of scope, it does not apologize or explain at length. It says: `out of scope — route to evelynn` and stops. The terseness is the enforcement mechanism.

## Model Tier

**Haiku 4.5** (`claude-haiku-4-5-20251001`).

Justification:

- Latency: Haiku is the fastest tier. For "lock my screen" the round-trip should feel instant.
- Cost: order of magnitude cheaper than Opus per token. The use case is high-frequency low-value calls where unit cost dominates.
- Capability: Haiku is more than adequate for "parse one English sentence into one shell command, run it, return output." The risk is not capability — it's overreach.
- Alternatives considered: Sonnet would work but defeats the cost goal. A non-LLM slash command would be cheaper still but loses the natural-language interface and the audit trail (see Delegation Pattern below).

## Scope — The Hard Boundary

This section is the contract. The agent reads it on every invocation as part of its system prompt. If a request fails any check, the agent refuses and routes back.

### Allowed

- A single shell command, or a single logical pipeline (e.g. `tasklist | findstr chrome` counts as one logical action).
- Read-only filesystem inspection (`ls`, `dir`, `cat` of a single small file via `Read`, `find`/`Glob`, `grep`/`Grep`).
- Read-only git inspection (`git status`, `git log`, `git diff` with no arguments that mutate).
- Process inspection (`tasklist`, `ps`, `Get-Process`).
- Trivial OS actions with no side effects beyond the intended one: lock screen, open a folder in Explorer, show a notification, copy to clipboard.
- Wall time under ~10 seconds. If a command hangs, kill it and report.

### Forbidden (hard refuse)

- Any file edit. No `Edit`, `Write`, `NotebookEdit`, no `>` redirects, no `tee`, no `sed -i`, no `Set-Content`.
- Any git mutation. No `commit`, `push`, `pull`, `merge`, `rebase`, `checkout`, `reset`, `clean`, `stash`, `add`.
- Spawning other agents or invoking the Agent tool.
- Web fetches or web searches.
- Reading more than one file. If the task needs cross-file reasoning, refuse.
- Command output exceeding ~50 lines. Truncate-and-refuse: report "output too long — route up" rather than dumping.
- Anything touching `secrets/`, `.env`, credential files, or anything that matches the gitleaks denylist.
- Anything requiring elevation (sudo, runas, UAC). If a command silently fails for permissions, report the failure and stop — do not retry with elevation.
- Anything requiring judgment about *whether* to do it. Tibbers executes; it does not decide.
- Anything in the destructive denylist (see below).

### Refusal output format

When refusing:

```
out of scope: <one-phrase reason>
route: evelynn
```

No more, no less. The terseness is intentional — verbose refusals invite negotiation.

## Tool Allowlist

**Allowed:**

- `Bash` — the primary tool
- `Read` — single-file inspection only, capped by the scope rules
- `Glob` — file discovery
- `Grep` — content search

**Forbidden:**

- `Edit`, `Write`, `NotebookEdit` — no mutation
- `Agent` / `Task` — no delegation
- `WebFetch`, `WebSearch` — no network reasoning
- `EnterPlanMode`, `ExitPlanMode`, `TodoWrite` — no planning surfaces; this agent does not plan
- Any MCP tool that posts to inbox, messages other agents, or mutates state

The minimal toolset is itself a scope enforcement: Tibbers can't do forbidden things because the tools aren't there.

## Delegation Pattern

**Recommendation: option (a) — fire-and-forget one-shot via the Agent tool, foreground (`run_in_background=false`).**

Reasoning across all three options:

- **(a) One-shot foreground.** Evelynn calls the Agent tool with a Tibbers system prompt, the task as the user message, waits for the synchronous return, relays to Duong. State is zero. Each invocation is independent. Cost is bounded per call. Audit trail is preserved (Evelynn's transcript shows the delegation and the result). This is the answer.
- **(b) Persistent inbox session.** Adds a long-lived process, warm context, slightly faster repeat invocations. But: warm context is precisely the thing we *don't* want for an agent whose discipline relies on rereading the scope rules every call. Persistence would let scope drift accumulate. Also adds liveness/restart machinery for marginal latency gain. Reject.
- **(c) Slash command / hook, no agent.** Cheapest, but loses the natural-language interface (Duong has to remember exact command syntax) and loses the agent-attribution audit trail. Also forecloses the ability to add lightweight refusal logic without rewriting the harness. Reject — but worth revisiting if Tibbers proves useful enough that the natural-language layer becomes the bottleneck.

### Invocation protocol

- Only Evelynn invokes Tibbers. Other Opus agents (Syndra, Swain, Pyke, Bard) route through Evelynn if they need an errand run, same as today. This keeps the delegation graph simple and Evelynn-centric.
- Duong does not invoke Tibbers directly. Duong tells Evelynn "lock my screen"; Evelynn delegates to Tibbers. (If Duong wants to talk to Tibbers directly later, that's a separate decision.)
- Each invocation is a fresh subagent call. No session reuse.

## Reporting Format

**Recommendation: minimum useful, Unix-tool style.**

- For commands with output: return the output, raw, nothing else. No "Here's the result:" preamble. No trailing summary.
- For commands with no output (lock screen, open folder): return a single word — `done.` — and stop.
- For failures: return `failed: <one-line reason>` and stop. No stack trace, no troubleshooting suggestions.
- For refusals: the refusal block specified above.

Evelynn is responsible for any framing Duong sees. Tibbers' job is to be a clean stdout, not a chat partner.

## Memory Footprint

**Recommendation: minimum viable. Profile only.**

Existing agents have `memory/`, `journal/`, `transcripts/`, `inbox/`, optional `learnings/`. Tibbers is stateless by design — it has no sessions to remember, no learnings to accumulate (any "learning" would constitute scope drift), no inbox (Evelynn invokes it directly via the Agent tool, not via the inbox protocol).

Proposed footprint:

```
agents/tibbers/
  profile.md
```

That's it. No `memory/`, no `journal/`, no `learnings/`, no `inbox/`.

The implementer should verify that the existing agent infrastructure (heartbeat, registry, roster) tolerates an agent with no memory directory. If something hard-codes the assumption that every agent has a `memory/<name>.md`, the fix is to make that lookup tolerant rather than to give Tibbers a vestigial memory file.

`agents/roster.md` should be updated to add Tibbers with role "Errand Runner — Trivial Shell Tasks" and a footnote that this agent is stateless and does not follow the standard session protocol.

## Heartbeat & Health

**Recommendation: skip the heartbeat.**

The CLAUDE.md startup sequence's heartbeat call exists for liveness tracking of long-running iTerm sessions. Tibbers is a one-shot subagent invocation that exits in seconds. A heartbeat from Tibbers would either (a) immediately go stale because the agent exited, falsely indicating a dead long-running agent, or (b) churn the registry on every invocation with no useful signal.

Instead: Tibbers' "liveness" is implicit in Evelynn's transcript. If Evelynn delegated and got a response, Tibbers ran. The registry should not list Tibbers at all.

The implementer should also confirm the heartbeat script and registry don't blow up if asked about a non-listed agent.

## Anti-patterns and Failure Modes

The named risks and the mitigations:

1. **Scope creep — Tibbers used for non-trivial work because it's right there.**
   Mitigation: the hard-boundary checklist is part of the system prompt. Refusal is the default posture. Evelynn's delegation prompt to Tibbers should be templated so it always frames the task as "is this trivial? if not refuse."

2. **Over-refusal — Tibbers becomes useless.**
   Mitigation: the allowed list is concrete and generous within the trivial band. Refusal is for the forbidden list, not for ambiguity. When ambiguous, Tibbers attempts and reports the result honestly.

3. **Adoption failure — Evelynn forgets Tibbers exists.**
   Mitigation: Evelynn's profile/memory should be updated (separate task, not in this plan) to note that trivial shell actions delegate to Tibbers by default. Worth a one-line entry in `agents/memory/agent-network.md` once approved.

4. **Blast radius — Haiku misreads a request and runs a destructive command.**
   Mitigation: the denylist (below) is enforced both in the system prompt and ideally as a Bash hook that pattern-matches outgoing commands. The minimal toolset already blocks `Edit`/`Write`. The denylist blocks the dangerous Bash one-liners.

5. **Silent permission failures.**
   Mitigation: Tibbers must report failure explicitly. "Failed: access denied" beats "done." for a command that didn't run. The system prompt instructs: never claim success without verifying.

6. **Approval-required commands disguised as trivial.**
   Lock screen is fine. `shutdown /s /t 0` is one command and syntactically trivial but has a different blast radius. The denylist handles this.

7. **Cost regression.**
   If Tibbers is invoked thousands of times per day for jobs that should have been a hardcoded shortcut, the savings vanish. Worth tracking invocation count for the first week post-launch.

## Denylist (Hard Refuse Even If "Trivial")

Pattern-match against the command before executing. If any of these match, refuse without running:

- `shutdown`, `restart`, `reboot`, `halt`, `poweroff`
- `rm -rf`, `rm -r`, `del /s`, `del /q`, `rmdir /s`, `Remove-Item -Recurse`
- `format`, `mkfs`, `diskpart`
- `taskkill /f`, `kill -9`, `Stop-Process -Force`
- `chmod 777`, `icacls` with grant, `takeown`
- Anything referencing `secrets/`, `.env`, `id_rsa`, `*.pem`, `*.key`, `credentials`
- Anything referencing `~/.ssh`, `~/.aws`, `~/.config/gh`
- Any git mutation verb: `commit`, `push`, `pull`, `merge`, `rebase`, `reset`, `clean`, `stash`, `add`, `checkout`, `branch -D`
- `curl`, `wget`, `Invoke-WebRequest`, `iwr` — no network egress
- `sudo`, `runas`, `gsudo`, anything requesting elevation
- `eval`, `exec`, `Invoke-Expression` — no dynamic code
- Heredocs and `>` / `>>` redirects to anywhere outside `/tmp` — no file creation

The denylist is conservative on purpose. False positives bounce up to Evelynn, which is the safe direction.

## Audit Trail — How Duong Sees It

**Recommendation: Evelynn surfaces minimum-friction acknowledgment, not Tibbers' raw output.**

When Duong says "lock my screen":

- Evelynn delegates to Tibbers.
- Tibbers returns `done.`
- Evelynn says: `Locked.` (or similar one-word ack in Evelynn's voice)

Duong does not see "Tibbers locked the screen." The agent attribution exists in the transcript for debugging but not in the chat surface. This matches the principle that Duong talks to Evelynn, not to the roster.

The exception: if Tibbers refuses, Evelynn surfaces the refusal verbatim plus her own decision (handle it herself or escalate). Refusals are signal that the routing was wrong and Duong should know.

## Open Questions for Duong

1. **Should Tibbers be invokable by other Opus agents directly, or only by Evelynn?** Plan currently says Evelynn-only for routing simplicity. The cost is that Syndra/Swain/Pyke have to round-trip through Evelynn for trivial things, which somewhat defeats the purpose if those agents are themselves running expensive sessions. Counter-argument: those agents shouldn't be running shell errands during planning work anyway.

2. **Denylist enforcement: prompt-only or hook-enforced?** Prompt-only is faster to implement. A pre-execution Bash hook that pattern-matches the command is more robust but adds infrastructure. Recommend prompt-only for v1, hook in v2 if a single misfire happens.

3. **Should Tibbers be invokable by Duong directly, bypassing Evelynn?** Cleaner UX for the user, but breaks the "Duong talks to Evelynn" hub model. Default no, but worth confirming.

4. **Naming.** Tibbers vs. Teemo vs. Poppy. Plan picks Tibbers. Duong's call.

5. **Visibility in roster.** Should Tibbers appear in `agents/roster.md` and `agents/memory/agent-network.md` like a normal agent, or be listed in a separate "infrastructure agents" section to signal it's not a peer? Recommend a small "Infrastructure" subsection so the asymmetry is visible.

## Decisions (2026-04-08)

Duong: "Tibbers is good, and all of her suggestions are good. Let's go with it."

1. **Name: Tibbers.** Confirmed. Annie's summoned bear — *property*, not a peer agent. The framing matters: it culturally reinforces "no improvisation, no judgment, run the command and exit."
2. **Invocation: Evelynn-only.** Other Opus agents (Pyke, Swain, Syndra, Bard) route through Evelynn for trivial tasks. Specialists shouldn't be running shell errands during planning work anyway.
3. **Duong-direct invocation: no.** Duong talks to Evelynn; Evelynn delegates to Tibbers. Hub model preserved.
4. **Denylist enforcement: prompt-only for v1.** Tighten to a Bash pre-execution hook only if a misfire actually happens. Don't pre-build infrastructure for a problem that may never occur.
5. **Roster visibility: separate "Infrastructure" subsection** in `agents/roster.md`. Tibbers is not a peer in the agent network — it's a tool. Make the asymmetry visible.

Plan is unblocked and ready for Duong's approval (move from `proposed/` to `approved/`). After approval, Evelynn delegates implementation to a Sonnet agent (probably katarina). Plan author (Syndra) does not implement, per CLAUDE.md rules 7 and 8.

## Success Criteria

- Tibbers exists with a profile, listed in `roster.md`, with no memory/journal/learnings directories.
- Evelynn can delegate a trivial shell task to Tibbers and receive a clean one-shot result in under ~10 seconds wall time.
- Tibbers correctly refuses every item on the denylist when given a synthetic test prompt.
- Tibbers correctly refuses an over-scoped multi-step request and routes to Evelynn.
- Per-invocation token cost is at least an order of magnitude below the equivalent Evelynn call (rough check, not a hard SLA).
- One week after launch: Evelynn's transcripts show measurable delegation to Tibbers for trivial tasks (adoption check).
- Zero incidents of Tibbers running a denylisted command.

## Out of Scope for This Plan

- Writing Tibbers' `profile.md` (implementer task post-approval).
- Updating `agents/roster.md` and `agents/memory/agent-network.md` (implementer task).
- Updating Evelynn's memory/profile to mention Tibbers as the default trivial-task delegate (separate small follow-up).
- Building a Bash pre-execution hook for denylist enforcement (v2 if needed).
- Metrics/instrumentation for invocation count and cost (nice-to-have, not blocking).
