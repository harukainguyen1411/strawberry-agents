# PR #56 — Firebase SA secret rename (harukainguyen1411/strawberry-app)

- Ops fix, no formal plan. Renamed `FIREBASE_SERVICE_ACCOUNT` → `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` in `preview.yml` + `myapps-pr-preview.yml`.
- Plan-fidelity: N/A (no plan). Reviewed against invariants instead: fork-guard preserved, least-privilege improved (per-project SA), no production workflow drift, Rule 13 N/A.
- Identity note: `scripts/reviewer-auth.sh gh api user --jq .login` returns `strawberry-reviewers` correctly, but `gh pr view` emits GraphQL scope warnings for org fields (token lacks `read:org`). These are cosmetic — review submission still works.
- Verdict: APPROVE.
