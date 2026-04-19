# PR #42 V0.8 importCsv — post-main-merge re-review

- Verdict: APPROVE (re-approve)
- Tip: 18d0563 (merge of origin/main, not a rebase — Rule 11 honored)
- Prior Lucian approval at 169ccb6 was reset by V0.x cascade landing on main; Jayce merged main back.

## What changed since prior approval
- Single code conflict: `t212.ts` — `accountCurrency` capture was reordered to precede the `TRADE_ACTIONS` skip. Rationale: non-trade rows (Deposit/Interest) must still contribute settlement currency, preserving B.2.12/B.2.13 cash-currency-from-CSV invariant (ADR §5 multi-broker cash).
- `portfolio-tools/index.ts` auto-merged (V0.4 d.id snapshot fix arriving via main). Orthogonal to V0.8 orchestration contract.

## Fidelity checks passed
- Rule 11 (merge not rebase): honored.
- Rule 12 xfail-first chain intact across merge: 99266a5 → 076bc47, 410e5e1 → 169ccb6.
- Rule 13 regression test for id:undefined: preserved.
- B.2.1–B.2.13 AC mapping unchanged; PR body still accurate.

## Pattern for future cascade re-reviews
- When main-merge conflict is in parser/handler code, verify that conflict resolution direction honors the newer invariant from the xfail tests (here: accountCurrency capture ordering). A naive keep-ours would have broken B.2.12.
- Check if Senna has already re-approved at same tip to avoid duplicate-lane overlap.
