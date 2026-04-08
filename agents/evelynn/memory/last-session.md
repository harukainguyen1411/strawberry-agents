# Last Session — 2026-04-08 (Direct mode, architectural session)

**Previous handoff (Windows Mode build) is superseded by this one.** That work shipped (commit `a161190`) and Windows Mode is operational — this entire session ran on it. If you need that history, see the git log.

**Mode:** Direct. Duong active throughout. Long, productive, many decisions.

## Session arc

Started small (lock screen, prevent sleep) and grew into a full architectural session. By the end:
- 6 plans drafted, all in `plans/proposed/`, none yet executed
- Designed three new minions (Yuumi, Tibbers, Poppy) — but **Tibbers is being superseded into a `/run` skill** per the skills-integration finding
- The "Evelynn delegates everything" rule was reinforced **three times**, each escalation stricter
- Discovered Claude Skills exist and how they fit (subagents don't inherit; must be preloaded explicitly)
- Found bugs in existing rules (CLAUDE.md duplicate rule numbers, two roster files drifting)

## CRITICAL — read these memories first thing next session

The two feedback memories that govern Evelynn's behavior have been significantly expanded. **They are now strict, not aspirational.**

1. `~/.claude/projects/C--Users-AD-Duong-strawberry/memory/feedback_evelynn_delegation.md` — has THREE escalation sections from this session. End-state: **Evelynn does no direct file touches.** No Read, no Edit, no Write, no Glob, no Grep. Pure orchestration only. Allowed: conversational replies, Agent spawns, minimal orchestration Bash (`git status`, `git add/commit`, agent spawning), memory writes to her own dir.
2. `~/.claude/projects/C--Users-AD-Duong-strawberry/memory/feedback_secrets_handling.md` — secrets via `secrets/` files, never in chat.

**Interim allowance:** Until Poppy (edit minion) and Yuumi (read minion) actually exist as agents, Evelynn may do minimal direct reads/edits when no other path exists, but must explicitly acknowledge the rule gap and prefer delegation. Don't lean on this — it's the exception, not the workflow.

## Plans currently in `plans/proposed/` (6 of them)

| Plan | Author | Status | Next action |
|---|---|---|---|
| `2026-04-08-encrypted-secrets.md` | Evelynn drafted + Pyke reviewed | Has `## Pyke Review` section appended — 8 required edits | Pyke's edits need to be applied + decisions recorded. Substantial work, needs katarina with the plan as input. |
| `2026-04-08-plan-gdoc-mirror.md` | Swain | Has `## Decisions` section, fully unblocked | Sequenced after encrypted-secrets. `git mv` to `approved/` once secrets lands. |
| `2026-04-08-errand-runner-agent.md` (Tibbers) | Syndra | Has `## Decisions` section | **Being superseded.** Skills-integration plan recommends Tibbers becomes the `/run` skill. Move to `archived/` with supersession note. |
| `2026-04-08-rules-restructure.md` | Syndra-1 | No decisions section yet | 6 open questions. **Caveat:** Evelynn only knows the text of Q1, Q3, Q4, Q5 (from Syndra's report). **Q2 and Q6 are unknown to Evelynn.** Decision-recording must instruct katarina to pause and report back if she encounters open questions Evelynn's pre-fills don't cover. |
| `2026-04-08-skills-integration.md` | Syndra-2 | No decisions section yet | 7 open questions, all approved by Duong with Evelynn's pre-fills. Ready to record. |
| `2026-04-08-minion-layer-expansion.md` | Syndra-3 | No decisions section yet | 3 open questions, all approved. Ready to record. |

**Decision recording is pending across the four un-recorded plans.** Duong gave blanket "all good, proceed as proposed" approval at end of session. Next session should spawn katarina (or Poppy if she exists by then) to record decisions across all four in one batch — with the rules-restructure caveat above.

## The skills-vs-subagents synthesis (resolved end of session)

| Minion | Final form | Why |
|---|---|---|
| **Tibbers** | `/run` skill (replacing the agent design) | Subagent overhead dominates Haiku savings for one-shot shell calls. Skill body in Evelynn's context is cheaper, same discipline. Reversibility baked in. |
| **Yuumi** | Sonnet subagent | Synthesis wants real model invocation. Reads need context isolation to keep raw content out of Evelynn's window — a skill would defeat that. |
| **Poppy** | Haiku subagent | The whole point is keeping `Edit` tool out of Evelynn's hands. A skill would teach Evelynn the procedure but Evelynn would still hold the tool. Subagent is correct shape. |

**Duong approved this synthesis.** The Tibbers agent plan must be archived; the `/run` skill in skills-integration replaces it.

## Pyke's encrypted-secrets review — 8 required edits

In the `## Pyke Review` section of the plan. Summary so the next session doesn't have to re-read:

1. **Bootstrap discipline** — never `cat` private keys over remote-control session; use `age-keygen -y` to re-derive pubkeys from private file
2. **Compromise ≠ rotation** — real rotation = regenerate the value at the provider (Telegram, GitHub, Anthropic). Re-encrypting the file is theater because git history is forever
3. **Replace `secret-use.sh @SECRET@` placeholder** with `exec env KEY=val -- "$@"` (env-var-into-child-process-only). Argv substitution leaks via `Get-Process` and has injection risks
4. **Gitleaks allowlist** for `.age` files, `recipients.txt`, `tools/encrypt.html` — otherwise gitleaks blocks every commit to `secrets/encrypted/`
5. **Windows ACLs** — `chmod 600` is no-op on Windows under git-bash; use `icacls /inheritance:r` + explicit grant
6. **git-bash CRLF caveat** — ASCII-armored age is line-sensitive; need `core.autocrlf false` repo-wide. (Already seeing CRLF warnings in commits this session — confirmed real)
7. **Phone encryptor** — SHA256 sidecar + vendored (not CDN) JS for tamper detection
8. **Pre-commit hook** to scan staged files for known decrypted values + ban raw `age -d` outside the helper

These are **substantial implementation work**, not just decision-recording. Needs a Sonnet executor with the plan file as input. Don't bundle into the decision-recording katarina batch — they're different scopes.

## Duong's answers to Pyke's 4 open questions (recorded in chat, NOT yet in plan)

- **Q1 (transport):** Claude Desktop. Plus Tailscale installed on Mac. Implication: chat-mediated, cloud-routed via Anthropic infrastructure. **Bootstrap rule: never `cat` private keys in any Claude Code session because output flows through chat.** Tailscale provides a non-chat side channel for any operation that needs to bypass Claude Desktop's path.
- **Q2 (CLAUDE.md rule banning raw `age -d`):** Yes, approved.
- **Q3 (rotation cadence):** Build a scalable rotation system. Don't just pick a cadence — build the mechanism.
- **Q4 (admin/BitLocker):** Admin confirmed. Not yet a threat. Flag for future hardening (separate followup or `architecture/security-debt.md` note).

**⚠ Still unresolved:** The exact Claude Desktop ↔ Claude Code bridge — Duong said "It's Claude Desktop" but didn't elaborate on which MCP server / bridge mediates the connection. Evelynn asked multiple times for the MCP server list from Claude Desktop's settings; Duong never answered. This question blocks Pyke from finalizing the bootstrap discipline section, AND blocks the cafe-from-home plan that hasn't been written yet.

## Open threads not yet planned

1. **Cafe-from-home setup plan** — Duong wants to take Mac to a cafe and leave Windows at home. Discussed conversationally but **no plan written**. Should be **Pyke** (security focus on remote access) once the bridge clarification is in. Duong rejected Tailscale (work Mac, can't install personal VPN). Alternatives are ZeroTier, Cloudflare Tunnel, or "use the existing Claude Desktop bridge" (most likely already works over the public internet).
2. **Remote restart capability** — `/clear` works remotely already (it's just text). Full process restart needs a Windows-side wrapper service. Should be part of the cafe-from-home plan.
3. **Tibbers archival** — simplest next action. `git mv plans/proposed/2026-04-08-errand-runner-agent.md plans/archived/` with a supersession note added to the file referencing skills-integration.

## Memory updates made this session (all committed)

In `~/.claude/projects/C--Users-AD-Duong-strawberry/memory/`:
- `feedback_secrets_handling.md` — created
- `feedback_evelynn_delegation.md` — created, then expanded twice with escalation sections
- `MEMORY.md` — index updated

In agent memory (committed to repo):
- `agents/syndra/memory/syndra.md` — S14 (rules), S15 (skills), S16 (minion-layer)
- `agents/swain/memory/swain.md` — plan-gdoc-mirror session
- `agents/pyke/memory/pyke.md` — encrypted secrets review session
- `agents/evelynn/memory/last-session.md` — this file (replacing previous Windows Mode handoff)

**Evelynn's main memory file (`agents/evelynn/memory/evelynn.md` if it exists) was NOT updated this session.** Next session might want to add an entry summarizing the architectural decisions if there isn't one.

## Most important things for the next session

1. **Read both feedback memories first.** Evelynn's behavior has materially changed.
2. **The blocking question for Duong** is still: what's in his Claude Desktop MCP server list? Get that answer first thing — it unblocks two plans.
3. **Decision recording across 4 plans** is the biggest pending operational task. Should be a single katarina batch with the rules-restructure caveat about Q2/Q6.
4. **Tibbers archival** is the simplest next step — one `git mv`.
5. **The cafe-from-home plan does not exist yet.** Spawn Pyke for it as soon as the bridge clarification is in.

## Things Evelynn must NOT do next session

- Do not draft plans inline. Spawn the right specialist.
- Do not Read/Edit/Write/Glob/Grep directly. Spawn Yuumi (when she exists) or harness Explore (now). Use Poppy (when she exists) or katarina for edits.
- Do not "let me think about this" reasoning chains in chat text. Spawn a specialist.
- Do not assume Duong has read the plan files himself. Surface decisions and questions in chat.
- Do not respawn the three Syndras unless something genuinely new comes up — their work is done.

## Final session state

- All background agents finished. No in-flight subagents.
- Repo is in a consistent state. All memory updates committed.
- 6 plans in `proposed/`, 0 in `in-progress/`, none being actively worked.
- Duong went to test the session-restart flow. He'll be back to verify the next session loads this handoff correctly.

Session closed cleanly.
