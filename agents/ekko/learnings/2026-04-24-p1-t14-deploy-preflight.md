# 2026-04-24 — T.P1.14 deploy preflight (blocked)

## Task

T.P1.14 from plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md — deploy S1 + S3
with FACTORY_REAL_BUILD=1 to staging + prod.

## Preflight findings

### T.P1.12 — FAIL (deploy blocker)

File: `company-os/tools/demo-studio-v3/tests/test_build_endpoint.py`

All three test cases in `TestP112IntegrationHappyPath` and `TestP112IntegrationFailurePath`
still carry the `P1_XFAIL = pytest.mark.xfail(strict=True, reason="P1 not yet implemented")`
marker. No T.P1.12 implementation commit exists on `feat/demo-studio-v3`.

Commits checked: the most recent P1 task commit on the branch is `21621b4` (T.P1.7 fault
injection fixtures, 2026-04-24). There is no commit implementing the T.P1.12 wire-up
(Rakan's integration test that connects S1 /build → S3 → session doc).

The `test_plan_slug_is_referenced_in_module_docstring` helper test would pass, but all
three substantive test cases remain xfail with strict=True.

Deploy instruction from Sona: "If the file is still xfail-marked or absent, STOP and
report — deploy is not safe." → STOPPED.

### T.P1.13b — PASS

`company-os/tools/demo-studio-v3/static/studio.js` has the full `renderDemoReadyPanel(d)`
function (lines 292-349). It reads `d.outputUrls.demoUrl` and `d.outputUrls.projectUrl`,
renders a panel with "Demo ready" heading, clickable primary CTA (`href=demoUrl`,
`target="_blank" rel="noopener noreferrer"`), copy button, and secondary WS project link.
Landed via commit `a6fa591` (feat: T.P1.13b — add persistent Demo ready panel above chat
log, PR #83). Panel also wired at line 948 on `d.status === 'complete'`.

T.P1.13b DoD: panel present with `d.status === 'complete'` check and `d.outputUrls.demoUrl`
CTA. CONFIRMED PRESENT.

### T.P1.E1 — PASS (verified earlier today)

All 5 required S3 env vars confirmed present on deployed demo-factory staging service:
WS_APP_BASE_URL, DEMO_BASE_URL, CONFIG_MGMT_URL, CONFIG_MGMT_TOKEN, FACTORY_REAL_BUILD=0.
Source: this session's learnings/2026-04-24-p1-e1-e2-env-var-provisioning.md.

### T.P1.E2 — PASS (verified earlier today)

FACTORY_BASE_URL and FACTORY_TOKEN (secret DS_FACTORY_TOKEN) confirmed added to live
demo-studio service. New revision demo-studio-00028-2n2 deployed earlier today.
Source: same learning file.

## gcloud describe permission block

The harness blocked `gcloud run services describe` for T.P1.E1/E2 live verification.
Relied on the verified earlier-today memory entry (learning file + MEMORY.md line 152).

## Outcome

Deploy not executed. Blocked on T.P1.12 xfail not flipped to pass.

Route back to Sona: T.P1.12 implementation (Rakan's wire-up commit) is the sole remaining
blocker before T.P1.14 can proceed.
