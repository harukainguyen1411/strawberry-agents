---
decision_id: 2026-04-28-akali-skip-duong-manual-qa
date: 2026-04-28
coordinator: sona
concern: work
question: How to unblock Akali's T15 sign-in (no @missmp.eu credential available; dashboard nonce-bypass dropped in §D2)?
options:
  a: Provide a real @missmp.eu credential for Playwright OAuth popup
  b: Ekko patches stg Firebase allowlist to admit duong.missmp.qa@gmail.com, run RUNWAY, revert allowlist after
  c: Skip sign-in in T15, run steps 2-11 with injected session, narrow Duong-Sign-Off waiver
  d: Skip T15 Akali entirely — Duong runs visual QA manually
coordinator_pick: a
coordinator_confidence: medium
duong_pick: d
predict: a
match: false
axes: [qa-rigor, coordinator-autonomy, manual-vs-automated-qa]
plan_ref: plans/approved/work/2026-04-28-demo-studio-v3-mock-to-real-s3-migration.md
hands_off_autodecide: false
---

## Context

Akali was dispatched for T15 RUNWAY against stg `demo-studio-00045-x9j` and blocked at step 1 sign-in: Firebase allowlist enforces `@missmp.eu`, the only QA bot credential is `duong.missmp.qa@gmail.com`, and the dashboard nonce-URL bypass was deliberately removed in §D2 (cherry-pick set excluded dashboard).

Sona surfaced three options (provide real cred / patch allowlist / skip-sign-in-with-waiver). Duong introduced option d, not in Sona's list: full T15 Akali skip, Duong does visual QA manually.

## Why this matters

This is a calibration miss — Sona's option set assumed Akali was the QA path. Duong's pick reveals that "Duong does manual QA" is a viable Phase G shape Sona didn't enumerate. The match-rate hit on `qa-rigor` and `manual-vs-automated-qa` axes feeds future option-set construction (always include "Duong does it manually" when QA is gated on missing automation infrastructure). Confidence-medium was overconfident; should have been low.

Practical follow-on: Rule 16 still requires evidence on UI PRs. Duong's manual QA pass needs a `Duong-Sign-Off: <iso8601>` line on the PR #134 body to replace the missing `QA-Report:` marker. Sona will not add that line — Duong adds it after running their manual pass, which is the whole point of the sign-off mechanism (it must be Duong's eyes, Duong's signature).

T16 (Senna + Lucian PR review) proceeds in parallel against the diff regardless — it does not block on Akali QA.
