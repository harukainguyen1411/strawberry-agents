# Learning: Work-reviewer identity model — PR comment pattern

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard ec53a0d6)
**Concern:** work
**Severity:** high

## What happened

Duong corrected a fundamental model error: `strawberry-reviewers` / `strawberry-reviewers-2` accounts are **personal-concern only** (Evelynn side). All work-concern agents — including executor AND reviewer roles (Senna, Lucian) — operate under the single `duongntd99` account on `missmp/*` repos.

Because GitHub enforces author-cannot-approve-own-PR, and executor agents already use `duongntd99` as the PR author, Senna and Lucian **cannot post GitHub approving Reviews** on work PRs. They would be approving their own account's PRs.

## Resolution

**Canonical flow for work PRs:**

1. Executor opens PR under `duongntd99`.
2. Senna / Lucian dispatch with `[concern: work]`. They `gh auth switch --user duongntd99` before any `gh` call.
3. Reviewer posts verdict via `gh pr comment <N> --repo missmp/<repo> -F <body-file>` — a PR **comment**, not a GitHub Review.
4. Rule 18 (a): checks green — verified by reviewer or coordinator.
5. Rule 18 (b): non-author approval — satisfied by Duong's manual web-UI Approve from `harukainguyen1411`.
6. Once (a) and (b) are both satisfied, any work agent may `gh pr merge <N>` under `duongntd99`.

## Evidence

Senna posted PR #114 verdict as PR comment at https://github.com/missmp/company-os/pull/114#issuecomment-4311529017 — first confirmed success under the corrected flow.

## Do not

- Use `scripts/reviewer-auth.sh` for work-scope. It is Evelynn-side only.
- Attempt `gh pr review --approve` from `duongntd99` on work PRs — GitHub will reject the self-approval.
- Use `gh pr merge --admin` or any branch-protection bypass.

## Canonical location

`agents/sona/CLAUDE.md` — "Identity Model — Work Scope" and "Reviewer flow — work scope" sections.
