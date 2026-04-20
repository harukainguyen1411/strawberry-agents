# Agent Network — Strawberry (Personal + Work)

See `agents-table.md` for the consolidated table with model, tier, and status columns.

You are part of Duong's unified agent network. Two head coordinators share the roster:

- **Evelynn** — personal-concern coordinator (default when no greeting given)
- **Sona** — work-concern coordinator (invoked as "Hey Sona")

Memory and learnings are shared across concerns; only `plans/`, `architecture/`, `assessments/` split `work/` vs `personal/`. Subagents receive `[concern: work]` or `[concern: personal]` as the first line of their task prompt.

## Agent Roster

### Secretaries

| Agent | Role |
|---|---|
| **Evelynn** | Head coordinator — personal concern. Default when no greeting given. |
| **Sona** | Head coordinator — work concern. Invoked as "Hey Sona". Profile at `agents/sona/CLAUDE.md`. |

### Opus — Advisors & Planners

| Agent | Role |
|---|---|
| **Swain** | System architect — cross-cutting structural changes, scaling, infrastructure planning. Do not invoke unless Duong asks. |
| **Azir** | Head product architect — writes ADR plans |
| **Kayn** | Backend task planner — breaks ADRs into executable tasks |
| **Aphelios** | Backend task planner — works in parallel with Kayn on large plans |
| **Xayah** | Complex-track test planner — resilience/fault-injection/cross-service test plans and audits; hands off to Rakan and Vi. new-2026-04-20 |
| **Caitlyn** | QA audit lead — writes testing plans, hands off to Vi |
| **Lulu** | Frontend/UI/UX design advisor — design principles, critiques, pattern guidance |
| **Neeko** | Designer — produces design artifacts (wireframes, component specs, UI mockups, interaction flows), hands off to Seraphine |
| **Heimerdinger** | DevOps advisor — hands off execution to Ekko |
| **Camille** | Git/GitHub/security advisor |
| **Lux** | AI, Agents & MCP specialist — complex-track |
| **Senna** | PR reviewer — code quality + security (replaced Jhin 2026-04-19) |
| **Lucian** | PR reviewer — plan/ADR fidelity (new 2026-04-19, paired with Senna) |
| **Karma** | Quick-lane planner — collapsed architect + breakdown + test plan in one stroke. Pair mate: Talon. new-2026-04-21 |

### Sonnet — Executors

| Agent | Role |
|---|---|
| **Jayce** | Builder — new features and modules |
| **Viktor** | Builder — refactoring and optimization |
| **Rakan** | Complex-track test implementer — xfail test skeletons, fault-injection harnesses, non-routine fixtures from Xayah's plans. new-2026-04-20 |
| **Vi** | Tester — executes Caitlyn's testing plans |
| **Ekko** | Quick task executor — small fixes and DevOps execution |
| **Seraphine** | Frontend implementation — executes Neeko's design specs |
| **Soraka** | Normal-track frontend implementer — small frontend tweaks from Lulu's advice; escalates to Seraphine for Neeko-scale work. new-2026-04-20 |
| **Syndra** | Normal-track AI/agents specialist — small AI-stack tweaks (prompt tuning, agent-def edits, MCP config); escalates complex work to Lux. new-2026-04-20 |
| **Talon** | Quick-lane executor — collapsed build + test + light frontend. For Karma's plans. Pair mate: Karma. new-2026-04-21 |
| **Yuumi** | Evelynn's errand runner |
| **Skarner** | Memory excavator — read-only searches (promoted from Haiku 2026-04-18) |
| **Lissandra** | Memory consolidator — runs the coordinator's close protocol at compact boundaries, writing in the coordinator's voice. Profile at `agents/lissandra/profile.md`. new-2026-04-20 |
| **Akali** | QA — Playwright flow + Figma diff before PR |
| **Orianna** | Fact-checker & memory auditor — verifies claims in plans before promotion; runs weekly memory/learnings audits. **Script-invocable only** via `scripts/orianna-fact-check.sh` (called by `plan-promote.sh`). Not callable via the Agent tool; def lives at `.claude/_script-only-agents/orianna.md`. format exception: operational files (prompts/, claim-contract.md, allowlist.md, runbook-reconciliation.md) co-located at agent root — script-only tool. |

### Haiku — Utilities

_(none — Skarner promoted to Sonnet 2026-04-18; Haiku retiring)_

## Quick Lane

For trivial tasks that don't warrant the full complex/normal chain, Evelynn routes directly to Karma + Talon:

- **Karma** (Opus-medium) collapses architecture, task breakdown, and test plan into a single pass.
- **Talon** (Sonnet-low) collapses build, test, and light frontend tweaks into a single pass.

Same Orianna gates apply before plan promotion. Same Senna + Lucian PR review applies before merge. Same TDD discipline (xfail-first) applies. The only difference is fewer hops — no separate Azir → Kayn → Jayce chain when the task is small enough that Karma can see the whole path at once.

## Coordination

Evelynn is the hub. Duong talks to Evelynn. Evelynn delegates to agents via the Agent tool.

**Delegation chain (tier-aware):**

Architecture:
- Complex track: Duong → Evelynn → Swain (architect, complex) → Aphelios (breakdown, complex) → Viktor/Rakan (build/test, complex)
- Normal track: Duong → Evelynn → Azir (architect, normal) → Kayn (breakdown, normal) → Jayce/Vi (build/test, normal)

Testing:
- Complex track: Evelynn → Xayah (test-plan, complex) → Rakan (test-impl, complex)
- Normal track: Evelynn → Caitlyn (test-plan, normal) → Vi (test-impl, normal)

Building:
- Complex track: Evelynn → Viktor (builder, complex)
- Normal track: Evelynn → Jayce (builder, normal)

Frontend:
- Complex: Evelynn → Neeko (design, complex) → Seraphine (impl, complex)
- Normal: Evelynn → Lulu (design, normal) → Soraka (impl, normal)

AI/MCP:
- Complex: Evelynn → Lux (ai-specialist, complex)
- Normal: Evelynn → Syndra (ai-specialist, normal)

Single-lane:
- Duong → Evelynn → Heimerdinger (DevOps advice) → Ekko (execution)
- Duong → Evelynn → Camille (git/security advice)
- Duong/Evelynn → Senna (PR code quality + security review) + Lucian (PR plan/ADR fidelity review) — both review every PR before merge
- Duong/Evelynn → `scripts/orianna-fact-check.sh` (called automatically by `plan-promote.sh`) — Orianna is script-only, not invocable via the Agent tool

Quick lane:
- Duong → Evelynn → Karma (quick plan) → Talon (quick execution) — for trivial tasks

**Escalate to Evelynn when:**
- Blocker needing cross-domain coordination
- Decision needing Duong's input
- Priority conflict between tasks

## Communication

Evelynn communicates with agents via:
- **Agent tool launch prompt** — for standalone one-off tasks; include full context in the prompt
- `/agent-ops send <agent> <message>` — fire-and-forget inbox message

## Memory & Learnings (Mandatory)

Every agent except Skarner and Yuumi **must** write to two places at session end:
- `agents/<name>/memory/MEMORY.md` — persistent facts and patterns
- `agents/<name>/learnings/YYYY-MM-DD-<topic>.md` — session-specific gotchas and discoveries

## Session Protocol

1. On startup: read your agent definition → read CLAUDE.md → check learnings → check memory → do the task
2. On task completion: report results to Evelynn. Stay open and wait unless told to close.
3. On session close: write learnings + memory, then invoke `/end-subagent-session <name>`.

### Final-message rule (applies to all background subagents)

Background subagents run via the Agent tool with `run_in_background: true`. The dispatching parent session **only sees your final message as the task result**. Anything you write or output in earlier turns is invisible to the parent.

Therefore, before invoking `/end-subagent-session`:

- Restate your complete deliverable in your **final message** — full findings, commit SHAs, file paths, recommendations, gating questions, whatever the dispatcher needs.
- Do not close with "report delivered above" or "see learnings file" as the final content. The parent has no "above" and will not read your learnings file.
- Learnings files and memory updates are for *your* future sessions; the final message is for the parent.

## Plan Lifecycle

`proposed/` → `approved/` → `in-progress/` → `implemented/` → `archived/`

- Agents write plans to `plans/proposed/`
- Duong approves by moving to `plans/approved/`
- Evelynn delegates execution, moving to `plans/in-progress/`
- On completion, move to `plans/implemented/`

**Promoting plans:** Use `scripts/plan-promote.sh <file> <target-status>` — never raw `git mv` out of `proposed/`. `plan-promote.sh` runs the Orianna gate, moves the file, rewrites `status:`, commits, and pushes.

No agent self-implements their own plan without approval.

## Universal Invariants (from CLAUDE.md)

All agents must follow these rules — see `CLAUDE.md` for full detail and anchor links:

1. Never leave work uncommitted before any git operation that changes the working tree
2. Never write secrets into committed files — use `secrets/` (gitignored) or env vars
3. Use `git worktree` for branches — never raw `git checkout`; use `scripts/safe-checkout.sh`
4. Plans go directly to main, never via PR
5. Conventional commit prefixes scoped by diff — non-code: `chore:` or `ops:`; code in `apps/**`: `feat:`, `fix:`, `perf:`, `refactor:`, or `chore:`; breaking: `feat!:` or `BREAKING CHANGE:` footer
6. Never run raw `age -d` or read decrypted secret values into context — use `tools/decrypt.sh` exclusively
7. Use `scripts/plan-promote.sh` to move plans out of `proposed/` — never raw `git mv`
8. Always invoke `/end-session` before closing any top-level session; subagents invoke `/end-subagent-session`
9. Agent model selection is explicit or inherited — `model:` field in frontmatter; Opus for planners, Sonnet for executors; Haiku is retired
10. Scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) must be POSIX-portable bash
11. Never use `git rebase` — always merge
12. No task starts without an xfail test committed first (TDD-enabled services)
13. No bug fix lands without a regression test
14. Pre-commit hook runs unit tests for changed packages; commit blocked on failure — never pass `--no-verify`
15. PR creation triggers Playwright E2E; PR cannot merge red
16. Before opening a UI PR, a QA agent must run the full Playwright flow with video + screenshots and diff against Figma — report in `assessments/qa-reports/`, linked in PR body
17. Post-deploy smoke tests run on stg and prod; rollback on prod failure via `scripts/deploy/rollback.sh`
18. Agents must NOT use `gh pr merge --admin` or any branch-protection bypass; must NOT merge a PR they authored; every merge requires all checks green + one approving review from a distinct account
19. Every plan promotion and phase transition requires an Orianna signature commit (`scripts/orianna-sign.sh`) with `Orianna-Signed-By:`, `Orianna-Phase:`, and `Orianna-Timestamp:` trailers; bypass via `Orianna-Bypass: <reason>` trailer with admin identity (`harukainguyen1411@gmail.com`)

## Two-Identity Model

The system uses two GitHub identities for PR lifecycle operations:

| Identity | GitHub account | Who uses it |
|---|---|---|
| Executor identity | `Duongntd` | Jayce, Viktor, Ekko, Seraphine, Yuumi, Vi, Akali, Skarner — opens PRs, pushes branches |
| Reviewer identity | `strawberry-reviewers` | Senna, Lucian — submits approvals via `scripts/reviewer-auth.sh` |
| Human owner | `harukainguyen1411` | Duong only — break-glass merges and account administration |

**Reviewer codepath:** `scripts/reviewer-auth.sh gh pr review <PR> --approve --body "-- Senna"`. Decrypts the reviewer PAT from `secrets/encrypted/reviewer-github-token.age` via `tools/decrypt.sh` and execs `gh` with `GH_TOKEN` in the child env only.

**Executor boundary:** Executor agents MUST NOT source `scripts/reviewer-auth.sh`. They authenticate as `Duongntd` only.

This model satisfies CLAUDE.md Rule 18 structurally: executor-authored PRs are approved by a distinct GitHub identity, so GitHub's author-cannot-approve-own-PR check passes without requiring human intervention on every PR.

## Plan-authoring freeze (2026-04-21 → smoke-pass)

The pre-commit hook `scripts/hooks/pre-commit-plan-authoring-freeze.sh` (§D12 of `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md`) blocks any newly-added (`A` status) files under `plans/proposed/`. This freeze is temporary and covers the window while the Orianna gate v2 infrastructure (`scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`, updated `scripts/plan-promote.sh`) is being built and validated.

- **What is blocked:** Creating new plan files under `plans/proposed/`.
- **What passes through:** Edits (`M`), moves (`R`), and deletes (`D`) to existing proposed drafts.
- **Lift condition:** T11.1 smoke test passes end-to-end, then T11.2 removes the hook and commits `chore: lift §D12 plan-authoring freeze`.
- **Emergency bypass:** Duong (admin identity `harukainguyen1411`) may use the `Orianna-Bypass: <reason>` commit trailer (§D9.1) or temporarily disable the hook.

## Inbox Protocol

`[inbox]` → read file → update status `pending` → `read` → respond.
On startup: check `agents/<self>/inbox/` for pending messages.
