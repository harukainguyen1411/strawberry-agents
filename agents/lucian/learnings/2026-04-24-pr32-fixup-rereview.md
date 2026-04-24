# PR #32 fixup re-review — 2026-04-24

**Commit:** 6d3c15b on `feat/demo-studio-v3` (missmp/company-os)
**Verdict:** APPROVE (comment-only, fidelity lane)
**URL:** https://github.com/missmp/company-os/pull/32#issuecomment-4312802314

## Key observations

- Viktor's fixup is tightly scoped: 4 files, exactly the 3 Senna findings, no D1-D4 drift absorbed.
- `sys.path.append` (vs `.insert(0, ...)`) correctly preserves demo-studio-v3 as shadow-winner for colliding names (config_mgmt_client, project) because cwd/pytest-rootdir precede appended paths in default sys.path ordering.
- Rule 13: no dedicated sys.path-shadow regression test. Judged acceptable — T.P1.12 suite provides implicit coverage (would fail if wrong config_mgmt_client imported). A dedicated test against module-level sys.path mutation would be contrived.
- Ride-along removal of `build_import_factory_build_module = None` patch-anchor is clean — it was dead code (patch target is `factory_build.WSClient` directly).

## Auth lane gotcha

`scripts/reviewer-auth.sh --lane lucian gh pr comment` failed with "Could not resolve to a Repository" on missmp/company-os — the reviewer bot identity doesn't have org access. Fell back to default `duongntd99` gh auth per delegation ("Switch to duongntd99" for `gh pr comment`). Signed `-- reviewer` for work-scope anonymity.

For fidelity comments on missmp/* repos, use duongntd99 + sign `-- reviewer`. Reviewer-bot lane is for `gh pr review` approve/request-changes on repos where the bot is granted access.
