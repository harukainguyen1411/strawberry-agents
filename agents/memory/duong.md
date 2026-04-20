# Duong

## Profile
- Name: Duong
- Male, single
- Born: 14 November 1999
- Software engineer at MMP (work handled by separate agent system)
- Lived in Germany for 8 years, currently in Vietnam
- Uses Claude Code CLI as primary AI tool
- Agents named after League of Legends champions

## GitHub Accounts
- `harukainguyen1411` — HUMAN account, Duong's personal identity. Owns strawberry-app + strawberry-agents repos. Has admin bypass. Reviewer identity on PRs authored by the agent account. Canonical for ALL Google services.
- `Duongntd` — AGENT account. Invited collaborator with push permission on repos owned by harukainguyen1411. Canonical pusher for all agent-driven commits. No bypass. PATs for agent ops are minted from this account.
- `duong.nguyen.thai` — Work account. NOT used for Strawberry.

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
- **Hands-off mode:** Make **all** decisions yourself following Duong's preferences (simple yet clean and works; lean toward `a` or `b`; only pick `c` if the debt is genuinely cheap to repay). Do not stop to ask. Report outcomes, not questions. Escalate only for hard blockers that cannot be resolved within the stated preferences (e.g. a destructive git op that would lose data, a secret exposure, a platform CLI that keeps failing past the 3-flag-permutation rule).

Mode switches are explicit: Duong says "hands-on" or "hands-off" to toggle. The mode persists until changed or the session ends. On new session, reset to hands-on.
