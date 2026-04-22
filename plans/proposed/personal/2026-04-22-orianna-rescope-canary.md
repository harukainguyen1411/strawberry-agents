---
title: Orianna rescope canary — verify first-pass approval without suppression markers
status: proposed
concern: personal
owner: viktor
created: 2026-04-22
tags: [orianna-gate, canary, rescope]
complexity: quick
tests_required: false
orianna_gate_version: 2
architecture_impact: none
---

# Orianna rescope canary

This plan is a T11 canary fixture. Its purpose is to verify that the
substance-vs-format rescope (ADR 2026-04-22) allows plans citing HTTP routes,
fenced-block ASCII diagrams, and dotted identifiers to pass the proposed →
approved gate on the first attempt, without any `<!-- orianna: ok -->` markers
on those specific tokens.

---

## 1. Background

The motivating evidence for the rescope includes plans blocked on tokens like
`/auth/login`, `POST /api/sessions`, and `firebase_admin.auth.verify_id_token`.
This canary cites those classes of tokens in a minimal plan body to confirm the
gate accepts them after the rescope.

---

## 2. Canary claims (non-internal-prefix — must produce zero blocks)

The following token types are cited inline. Under v2 claim-contract they are
C2b (info) or non-claim (§2). No suppression markers are added.

HTTP routes used in the session API:
- `POST /auth/login` → session creation
- `GET /auth/session/{sid}` → session lookup
- `DELETE /auth/logout` → session teardown

Python identifiers from the demo-studio integration:
- `firebase_admin.auth.verify_id_token` → ID token verification
- `ds_session` → session store abstraction

ASCII state-machine diagram (inside a fenced block — not extracted at all):

```
/auth/login --> /auth/session/{sid} --> /auth/logout
     |                                       |
     v                                       v
firebase_admin.auth.verify_id_token     ds_session.clear()
tools/demo-studio-v3/agent_proxy.py
```

---

## 3. Internal-prefix claims (C2a — must still be verified)

The following tokens begin with internal prefixes and are genuine load-bearing
references. They must resolve via test -e:

`agents/orianna/claim-contract.md` — v2 contract file modified in T4.
`scripts/fact-check-plan.sh` — bash fallback updated in T5.
`agents/orianna/prompts/plan-check.md` — prompt updated in T6.

---

## 4. Canary success criterion

Zero block findings on the first `scripts/orianna-sign.sh` run after the
rescope lands (claim-contract v2 + updated bash fallback + updated prompts).
Warn and info findings are acceptable. No `<!-- orianna: ok -->` markers
are added to this plan.

---

## Tasks

- [ ] **T1** — Run fact-check on this plan and confirm zero block findings. estimate_minutes: 5.
  kind: impl

## Architecture impact

None. This is a read-only canary plan. No code or infrastructure changes.
