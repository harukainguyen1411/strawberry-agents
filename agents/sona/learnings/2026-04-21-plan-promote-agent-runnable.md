# 2026-04-21 — plan-promote.sh is agent-runnable, not admin-only

## What happened

I was treating `scripts/plan-promote.sh` as requiring the admin identity (`harukainguyen1411`) to run. When Duong asked me to promote a plan, I over-escalated it as a human-only action. Duong pushed back and clarified: the script is fully agent-runnable under the `Duongntd` executor account.

## The correction

Admin identity (`harukainguyen1411`) is required for exactly three things:
1. Rule 18 structural self-merge gaps (break-glass PR merge where no other reviewer is available).
2. Rule 19 `Orianna-Bypass:` commit trailers.
3. Branch-protection config changes on GitHub.

`scripts/plan-promote.sh` does none of those. It runs the Orianna gate, signs the plan, moves the file, rewrites `status:`, commits, and pushes — all under the `Duongntd` executor account. Duong's approval is a **semantic decision** (he says "approve X"), not a technical identity requirement.

## What to do instead

Once Duong approves a plan (explicit "approve X" or implicit via a broader directive), I delegate the promotion to Ekko or Yuumi. They run `scripts/plan-promote.sh` under `Duongntd`. I do not hold the promotion pending Duong's admin session.

## Why it matters

Over-escalating to admin creates unnecessary bottlenecks and forces Duong into technical operations that should be agent-runnable. The distinction between semantic approval (Duong's call) and technical execution (agent's job) is foundational to the coordinator pattern.

## Fixed in

`agents/sona/CLAUDE.md §rule-sona-plan-gate` — rewritten to split semantic vs. technical clearly. Committed at 2d1ac33.
