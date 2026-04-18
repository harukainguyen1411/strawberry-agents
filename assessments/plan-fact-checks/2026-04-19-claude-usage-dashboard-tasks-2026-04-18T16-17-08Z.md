---
plan: plans/proposed/2026-04-19-claude-usage-dashboard-tasks.md
checked_at: 2026-04-18T16:17:08Z
auditor: orianna
claude_cli: present
block_findings: 28
warn_findings: 0
info_findings: 8
---

## Block findings

<!-- All load-bearing path-shaped claims that do not resolve against the correct
repo checkout per contract §5. This plan is a task breakdown that names many
future files; per contract §4 strict default, missing paths are blocked.
Author can accept findings or add `<!-- orianna: ok -->` suppressions on the
relevant lines to acknowledge these are planned-not-yet-existing artifacts. -->

### This repo (`scripts/`, `assessments/` prefixes route here per §5)

1. **Claim:** `scripts/usage-dashboard/generate-roster.mjs` | **Anchor:** `test -e scripts/usage-dashboard/generate-roster.mjs` | **Result:** not found | **Severity:** block
2. **Claim:** `scripts/__tests__/generate-roster.test.mjs` | **Anchor:** `test -e scripts/__tests__/generate-roster.test.mjs` | **Result:** not found | **Severity:** block
3. **Claim:** `scripts/__tests__/fixtures/jsonl/` | **Anchor:** `test -e scripts/__tests__/fixtures/jsonl/` | **Result:** not found | **Severity:** block
4. **Claim:** `scripts/usage-dashboard/agent-scan.mjs` | **Anchor:** `test -e scripts/usage-dashboard/agent-scan.mjs` | **Result:** not found | **Severity:** block
5. **Claim:** `scripts/__tests__/agent-scan.test.mjs` | **Anchor:** `test -e scripts/__tests__/agent-scan.test.mjs` | **Result:** not found | **Severity:** block
6. **Claim:** `scripts/usage-dashboard/merge.mjs` | **Anchor:** `test -e scripts/usage-dashboard/merge.mjs` | **Result:** not found | **Severity:** block
7. **Claim:** `scripts/__tests__/merge.test.mjs` | **Anchor:** `test -e scripts/__tests__/merge.test.mjs` | **Result:** not found | **Severity:** block
8. **Claim:** `scripts/usage-dashboard/build.sh` | **Anchor:** `test -e scripts/usage-dashboard/build.sh` | **Result:** not found | **Severity:** block
9. **Claim:** `scripts/__tests__/build-sh.test.mjs` | **Anchor:** `test -e scripts/__tests__/build-sh.test.mjs` | **Result:** not found | **Severity:** block
10. **Claim:** `scripts/usage-dashboard/refresh-server.mjs` | **Anchor:** `test -e scripts/usage-dashboard/refresh-server.mjs` | **Result:** not found | **Severity:** block
11. **Claim:** `scripts/__tests__/refresh-server.test.mjs` | **Anchor:** `test -e scripts/__tests__/refresh-server.test.mjs` | **Result:** not found | **Severity:** block
12. **Claim:** `scripts/usage-dashboard/sbu.sh` | **Anchor:** `test -e scripts/usage-dashboard/sbu.sh` | **Result:** not found | **Severity:** block
13. **Claim:** `scripts/usage-dashboard/README.md` | **Anchor:** `test -e scripts/usage-dashboard/README.md` | **Result:** not found | **Severity:** block
14. **Claim:** `scripts/__tests__/sbu.test.mjs` | **Anchor:** `test -e scripts/__tests__/sbu.test.mjs` | **Result:** not found | **Severity:** block
15. **Claim:** `assessments/qa-reports/2026-04-19-usage-dashboard-v1.md` | **Anchor:** `test -e assessments/qa-reports/2026-04-19-usage-dashboard-v1.md` | **Result:** not found | **Severity:** block

### strawberry-app repo (`dashboards/` prefix routes here per §5)

16. **Claim:** `dashboards/usage-dashboard/` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/` | **Result:** not found | **Severity:** block
17. **Claim:** `dashboards/usage-dashboard/index.html` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/index.html` | **Result:** not found | **Severity:** block
18. **Claim:** `dashboards/usage-dashboard/data.json` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/data.json` | **Result:** not found | **Severity:** block
19. **Claim:** `dashboards/usage-dashboard/roster.json` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/roster.json` | **Result:** not found | **Severity:** block
20. **Claim:** `dashboards/usage-dashboard/package.json` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/package.json` | **Result:** not found | **Severity:** block
21. **Claim:** `dashboards/usage-dashboard/styles.css` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/styles.css` | **Result:** not found | **Severity:** block
22. **Claim:** `dashboards/usage-dashboard/app.js` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/app.js` | **Result:** not found | **Severity:** block
23. **Claim:** `dashboards/usage-dashboard/__tests__/html.test.mjs` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/__tests__/html.test.mjs` | **Result:** not found | **Severity:** block
24. **Claim:** `dashboards/usage-dashboard/__tests__/app.test.mjs` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/__tests__/app.test.mjs` | **Result:** not found | **Severity:** block
25. **Claim:** `dashboards/usage-dashboard/__tests__/refresh.test.mjs` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/__tests__/refresh.test.mjs` | **Result:** not found | **Severity:** block
26. **Claim:** `dashboards/usage-dashboard/vendor/` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/usage-dashboard/vendor/` | **Result:** not found | **Severity:** block

### Scoping note — cross-repo path routing

Several task bodies describe the feature as living in strawberry-app under
`scripts/usage-dashboard/` (see Override #2 and T1–T6 "Where" sections), but
contract §5 routes any `scripts/` prefix to this repo. The 14 `scripts/...`
block findings above reflect that routing. If `scripts/usage-dashboard/` is
intended to live in strawberry-app, either (a) extend the routing table in
`agents/orianna/claim-contract.md` to steer a specific sub-prefix to the app
repo, or (b) rewrite the references as absolute paths the reader can resolve
unambiguously (e.g. `strawberry-app/scripts/usage-dashboard/...`).

### Unknown path prefix (`tests/` — not in routing table)

27. **Claim:** `tests/e2e/usage-dashboard.spec.ts` | **Anchor:** n/a — unknown prefix | **Result:** `tests/` prefix not in §5 routing table | **Severity:** block
28. **Claim:** `tests/e2e/fixtures/usage-dashboard-data.json` | **Anchor:** n/a — unknown prefix | **Result:** `tests/` prefix not in §5 routing table | **Severity:** block

## Warn findings

None.

## Info findings

### Clean passes (path resolves)

1. **Claim:** `agents/memory/agent-network.md` | **Anchor:** `test -e agents/memory/agent-network.md` | **Result:** found | **Severity:** info
2. **Claim:** `scripts/safe-checkout.sh` | **Anchor:** `test -e scripts/safe-checkout.sh` | **Result:** found | **Severity:** info
3. **Claim:** `dashboards/test-dashboard/` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/dashboards/test-dashboard/` | **Result:** found | **Severity:** info
4. **Claim:** parent plan `plans/approved/2026-04-19-claude-usage-dashboard.md` (frontmatter) | **Anchor:** `test -e plans/approved/2026-04-19-claude-usage-dashboard.md` | **Result:** found | **Severity:** info

### Allowlisted integration names (Section 1 bare vendor names)

5. **Claim:** `ccusage` | **Anchor:** `agents/orianna/allowlist.md` §1 | **Result:** allowlisted | **Severity:** info
6. **Claim:** `Chart.js` | **Anchor:** `agents/orianna/allowlist.md` §1 | **Result:** allowlisted | **Severity:** info
7. **Claim:** `Playwright` | **Anchor:** `agents/orianna/allowlist.md` §1 | **Result:** allowlisted | **Severity:** info

### Unknown path prefix (home-relative `~/...` tokens not covered by §5)

8. **Claim:** multiple `~/Documents/...`, `~/.claude/...`, `~/.zshrc` tokens | **Anchor:** n/a | **Result:** unknown prefix `~/`; add to contract if any become load-bearing verification targets | **Severity:** info
