# PR #75 review — Firebase Loop 2c route migration (missmp/company-os)

Date: 2026-04-23
Repo: missmp/company-os (work concern)
PR: https://github.com/missmp/company-os/pull/75
Companion: PR #70 (xfails — branch `feat/firebase-auth-2c-xfails`)
Commits: `965a97b` (impl), `0362bb3` (tests)
Comment posted: https://github.com/missmp/company-os/pull/75#issuecomment-4301280108
Verdict: Request changes (advisory — posted as comment under duongntd99 because
`reviewer-auth.sh` is broken for missmp/company-os).

## Top findings

**Blockers**
1. **Contract mismatch between impl (PR #75) and xfail matrix (PR #70) on 4 routes**:
   `/build`, `/reauth`, `/complete` kept as `verify_internal_secret` only (correct per
   PR body intent), and `/session/{sid}/preview` is a 404 stub — but PR #70's
   `test_route_auth_matrix_2c.py::_SESSION_OWNER_ROUTES` asserts full owner-matrix
   behavior on all 4. After xfail-flip (T.V.1), these ~24 assertions will still fail
   strictly. Either drop them from the matrix, or migrate `/build,reauth,complete` to
   `require_session_or_owner` in #75.
2. **`/session/{sid}/stream` missing from PR #70 matrix entirely.** Highest-value data
   leak surface (all agent events) has zero 6-state matrix coverage on
   `_stream_session_owner_auth`.

**Important**
1. **TOCTOU in `auth_exchange` claim path.** When two Slack visits race,
   `set_session_owner` returns False for the loser but code ignores the result and
   redirects to `/session/{sid}` with stale cookie → user hits 403 at `session_page`.
   Not exploitable, but noisy UX + misleading logs. Fix: re-read session on
   `claimed=False` and 403 early with `reason="raced_claim"`.

**Suggestions / Positives**
- `require_session_or_owner` returns minimal stub on internal bypass vs. full session
  doc on cookie path — asymmetric return shape is a future-bug magnet.
- `_is_legacy_user` relies on `"legacy:"` prefix; defensive-only concern.
- Redundant test patches (`main.get_session` + `auth._load_session`) — no-op but noise.
- Positives: transactional `set_session_owner`, keyword-only `owner_uid`/`owner_email`,
  flag-gated legacy fallback, explicit public-stub documentation for `/preview`.

## Mechanics learned / re-confirmed

- **When the xfail harness PR and the impl PR are separate branches**, always diff
  the xfail test's expected-status table against the actual impl behavior per route
  *before* approving impl. The route list in the impl PR body is a hint, not a
  contract; the xfail matrix is the real contract. If these two disagree, the
  xfail-flip step will fail, and that surfaces only after both have merged.
- **`_SESSION_OWNER_ROUTES` vs actual impl** was a ~1-minute diff-eye-scan that
  caught 4 routes of drift. Always do this eye-scan.
- **`reviewer-auth.sh --lane senna` is broken for missmp/company-os** — the
  `strawberry-reviewers-2` identity doesn't have push/review access on this repo.
  Fall-back is `gh pr comment -F <file>` under duongntd99; sign the body with
  generic `-- reviewer` per work-scope anonymity rule.
- **`gh api repos/.../contents/...?ref=feat/xxx`** fails on zsh because of the
  unescaped `/` in the branch ref — use URL-encoded `feat%2Fxxx`.

## Files touched in PR (for reference)

- `tools/demo-studio-v3/auth.py` — new deps: `require_user`, `require_session_owner`,
  `require_session_or_owner`, `_load_session`, `_is_legacy_user`.
- `tools/demo-studio-v3/session.py` — `create_session(*, owner_uid, owner_email)`,
  new `set_session_owner()` transactional write.
- `tools/demo-studio-v3/main.py` — route migration on 9 session routes +
  `auth_exchange` claim-on-first-touch + `_stream_session_owner_auth` wrapper.
- 18 test files patched with new dep overrides / cookie headers /
  `patch("auth._load_session", ...)`.
