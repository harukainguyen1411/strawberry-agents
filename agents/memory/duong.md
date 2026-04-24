# Duong

## Profile
- Name: Duong
- Male, single
- Born: 14 November 1999
- Software engineer at MMP (work handled by separate agent system)
- Lived in Germany for 8 years, currently in Vietnam
- Uses Claude Code CLI as primary AI tool
- Agents named after League of Legends champions

## Slack

- Workspace: `merisier.slack.com`, team `T18MLBHC5`
- Duong's user ID: `U03KDE6SS9J`
- Routing is encoded in MCP tool names — see `mcp__slack__*`. Canonical
  agent→Duong notification: `mcp__slack__notify_duong(text)`. Do not
  reconstruct routing from memory; if a tool for an intent is missing,
  file it against the custom-slack-mcp plan rather than improvising with
  generic post tools.

## GitHub Accounts

Three accounts, scoped by concern. Coordinators (Evelynn, Sona) and their subagents MUST use the right account for the right scope. `gh auth switch --user <login>` to change the active identity.

- **`duongntd99`** — WORK account. Always use for work-scope (Sona side): `missmp/*` orgs including `missmp/company-os`, `missmp/workspace`. This is the canonical account for opening/viewing/commenting on work-repo PRs and for any `gh` operation under work concern.
- **`Duongntd`** — AGENT account for personal stuff (Evelynn side). Invited collaborator with push permission on `harukainguyen1411`-owned repos (strawberry-agents, strawberry-app). Canonical pusher for agent-driven commits on personal concern. No admin bypass.
- **`harukainguyen1411`** — ADMIN account, Duong's personal human identity. Owns the strawberry-* repos. Has admin bypass on branch protection. **Not available to agents by default** — only use when Duong explicitly authorizes it for a specific break-glass action. Default active account on `gh auth status` does NOT imply you may act as it; check scope before acting.

**Scope check before `gh` ops:**
- Sona operating on work-repo PR → ensure active account is `duongntd99`.
- Evelynn operating on personal-repo PR → `Duongntd` is fine; `harukainguyen1411` only with explicit permission.
- Cross-account reads are generally OK; writes/merges/reviews are not.

## Personal Context
- Work-life balance is an ongoing challenge — work absorbs most available time
- Has side project interests and learning goals that get deprioritized
- Values systems and structure — if it's not tracked, it doesn't happen
- Prefers agents with distinct personalities and honest communication

## Decision-Presentation Format (mandatory)

When presenting Duong with decision choices, always use this format:

```
N. <question>
   a: cleanest but might take more time/effort
   b: balanced
   c: quickest, but might introduce debt
Pick: <your recommendation + one-line why>
```

- Always label options a / b / c with that semantics (cleanest → balanced → quick-but-debt).
- Always state your own pick after the options.
- Duong's design preference: **simple yet clean and works**. A well-designed system is one that works well *and* is simple — not a complex one. Lean (a) or (b) on recommendations accordingly; only suggest (c) when the debt is genuinely cheap to repay later.
- Duong answers in compact form: `1a 2b 3a` etc.
- **If Duong skips a number, he concurs with your recommended pick** for that question. Do not re-ask.

## Operating Modes

Two modes govern how much consent to seek per decision. Default is **hands-on**.

- **Hands-on mode (default):** Present decision questions normally using the a/b/c format above. Wait for Duong's answer (or skip-to-concur) before proceeding on load-bearing choices.
- **Hands-off mode:** Make **all** decisions yourself. Do not stop to ask. Report outcomes, not questions. Three selectable tracks — Duong specifies the track when toggling; if unspecified, **Default track** applies:

  1. **Default track** — Follow learned preferences (simple yet clean and works; lean `a` or `b`; only pick `c` if the debt is genuinely cheap to repay). Active when Duong says "hands-off" with no qualifier.

  2. **Fast track** — Pick the quickest option, including `c`-ish choices when they are genuinely faster. MUST log what debt was taken on and what was left undone so it can be paid back later. Active when Duong says "hands-off, fast track" or equivalent phrasing ("ship fast", "urgent", etc.). Intended for ship days, urgent demos, customer-facing fires.

  3. **Slow track** — Always pick the cleanest option. Prefer the structurally-right answer over speed; refactors-as-we-go are fine; no debt, no residuals. Active when Duong says "hands-off, slow track" or equivalent phrasing ("weekend mode", "take your time").

  Escalate only for hard blockers that cannot be resolved within the chosen track (e.g. a destructive git op that would lose data, a secret exposure, a platform CLI that keeps failing past the 3-flag-permutation rule). This escalation clause applies equally to all three tracks.

Mode switches are explicit: Duong says "hands-on" or "hands-off [track]" to toggle. The mode persists until changed or the session ends. On new session, reset to hands-on. Track selection does not persist across sessions.

## Parallelism preference (mandatory for coordinators)

Duong's strong preference: **maximize parallelism**. Coordinators (Evelynn, Sona) should keep as many threads in flight as possible. If the coordinator is idle waiting on one or two subagents, that's a coordination failure — find something else to move in parallel.

Operating directives:

- Never let the team stall on a single long-running dispatch. While waiting for agent X, scan the open-threads / plan queue / backlog for independent work and fire the next dispatch.
- Treat "waiting for approval" and "waiting for a completion" as opportunities to pre-stage follow-on work (plan next implementer dispatch, queue adjacent audits, draft the next ADR).
- Multiple instances of the same agent type are fine as long as the work is independent. The "never parallelize same agent" rule is retired — parallelism risk is a shared-state problem, not a shared-agent-type problem.
- When in doubt: fire the dispatch. It's cheaper to over-dispatch and cancel than to serialize unnecessarily.
- The coordinator's job is to keep the queue full and the dependencies explicit, not to personally execute or to gatekeep throughput.

## Briefing and status-check verbosity (mandatory for coordinators)

Applies to both Evelynn and Sona. Governs any response to: "what's going on", "give me the update", "where are we", "summary", or any variant of a briefing or status-check request.

- **Default: high-level only.** Duong cannot keep track of every subagent, every task ID, every commit SHA, every OQ number — that is the coordinator's job to manage internally. The briefing surface is: what's shipping, what's blocked, what needs him.
- **Specific details only on request.** If he asks "what did Viktor change in T.P1.12?" or "show me the full OQ list" — then and only then go deep.
- **Signal, not log.** A briefing is not a transcript. Three to seven bullets is usually the right shape. If more is genuinely needed, lead with the bullets and offer to expand on request.
- **Surface decisions, hide bookkeeping.** Task IDs, agent IDs, commit SHAs, file paths, reviewer-protocol minutiae belong in coordinator memory — not in the user-facing brief unless Duong asked for them or they're the actionable item.
- **Always include: what he must decide / approve.** If nothing is blocked on him, say so plainly ("nothing blocked on you").

Applies equally to /check-inbox summaries, morning-brief output, session-resume reports, and any ad-hoc "status" query. Overrides any default in individual skills that might produce a fuller dump.
