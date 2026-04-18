---
plan: plans/approved/2026-04-19-public-app-repo-migration.md
checked_at: 2026-04-18T14:42:57Z
auditor: orianna
claude_cli: absent
block_findings: 1
warn_findings: 1
info_findings: 200
---

## Block findings

1. **Claim:** `agents/evelynn/memory/MEMORY.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/evelynn/memory/MEMORY.md` | **Result:** path not found | **Severity:** block

## Warn findings

1. **Claim:** (cross-repo path check) | **Anchor:** `test -d /Users/duongntd99/Documents/Personal/strawberry-app` | **Result:** could not verify 27 cross-repo path(s); strawberry-app checkout not found at `/Users/duongntd99/Documents/Personal/strawberry-app` | **Severity:** warn

## Info findings

1. **Claim:** `Duongntd/strawberry` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
2. **Claim:** `agents/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/` | **Result:** exists | **Severity:** info
3. **Claim:** `plans/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/` | **Result:** exists | **Severity:** info
4. **Claim:** `assessments/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/assessments/` | **Result:** exists | **Severity:** info
5. **Claim:** `CLAUDE.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
6. **Claim:** `agents/evelynn/CLAUDE.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/evelynn/CLAUDE.md` | **Result:** exists | **Severity:** info
7. **Claim:** `secrets/encrypted/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
8. **Claim:** `architecture/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/` | **Result:** exists | **Severity:** info
9. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
10. **Claim:** `scripts/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/` | **Result:** exists | **Severity:** info
11. **Claim:** `docs/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
12. **Claim:** `architecture/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/` | **Result:** exists | **Severity:** info
13. **Claim:** `package.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
14. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
15. **Claim:** `.github/branch-protection.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
16. **Claim:** `scripts/setup-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-branch-protection.sh` | **Result:** exists | **Severity:** info
17. **Claim:** `.github/dependabot.yml` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
18. **Claim:** `.github/pull_request_template.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
19. **Claim:** `scripts/hooks/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/hooks/` | **Result:** exists | **Severity:** info
20. **Claim:** `decrypt.sh` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
21. **Claim:** `secrets/age-key.txt` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
22. **Claim:** `package.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
23. **Claim:** `package-lock.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
24. **Claim:** `tsconfig.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
25. **Claim:** `turbo.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
26. **Claim:** `firestore.indexes.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
27. **Claim:** `release-please-config.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
28. **Claim:** `ecosystem.config.js` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
29. **Claim:** `README.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
30. **Claim:** `delivery-pipeline-setup.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
31. **Claim:** `vps-setup.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
32. **Claim:** `windows-services-runbook.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
33. **Claim:** `workspace-agent-setup-guide.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
34. **Claim:** `superpowers/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
35. **Claim:** `deployment.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
36. **Claim:** `git-workflow.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
37. **Claim:** `pr-rules.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
38. **Claim:** `testing.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
39. **Claim:** `firebase-storage-cors.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
40. **Claim:** `system-overview.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
41. **Claim:** `platform-split.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
42. **Claim:** `platform-parity.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
43. **Claim:** `docs/architecture/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
44. **Claim:** `scripts/hooks/pre-commit-secrets-guard.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/hooks/pre-commit-secrets-guard.sh` | **Result:** exists | **Severity:** info
45. **Claim:** `scripts/hooks/pre-commit-unit-tests.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/hooks/pre-commit-unit-tests.sh` | **Result:** exists | **Severity:** info
46. **Claim:** `pre-push-tdd.sh` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
47. **Claim:** `pre-commit-artifact-guard.sh` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
48. **Claim:** `scripts/install-hooks.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/install-hooks.sh` | **Result:** exists | **Severity:** info
49. **Claim:** `scripts/safe-checkout.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/safe-checkout.sh` | **Result:** exists | **Severity:** info
50. **Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/plan-promote.sh` | **Result:** exists | **Severity:** info
51. **Claim:** `scripts/plan-publish.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/plan-publish.sh` | **Result:** exists | **Severity:** info
52. **Claim:** `scripts/plan-unpublish.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/plan-unpublish.sh` | **Result:** exists | **Severity:** info
53. **Claim:** `scripts/plan-fetch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/plan-fetch.sh` | **Result:** exists | **Severity:** info
54. **Claim:** `scripts/_lib_gdoc.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/_lib_gdoc.sh` | **Result:** exists | **Severity:** info
55. **Claim:** `scripts/evelynn-memory-consolidate.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/evelynn-memory-consolidate.sh` | **Result:** exists | **Severity:** info
56. **Claim:** `scripts/list-agents.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/list-agents.sh` | **Result:** exists | **Severity:** info
57. **Claim:** `scripts/new-agent.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/new-agent.sh` | **Result:** exists | **Severity:** info
58. **Claim:** `scripts/lint-subagent-rules.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/lint-subagent-rules.sh` | **Result:** exists | **Severity:** info
59. **Claim:** `scripts/strip-skill-body-retroactive.py` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/strip-skill-body-retroactive.py` | **Result:** exists | **Severity:** info
60. **Claim:** `scripts/hookify-gen.js` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/hookify-gen.js` | **Result:** exists | **Severity:** info
61. **Claim:** `scripts/composite-deploy.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/composite-deploy.sh` | **Result:** exists | **Severity:** info
62. **Claim:** `scripts/scaffold-app.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/scaffold-app.sh` | **Result:** exists | **Severity:** info
63. **Claim:** `scripts/seed-app-registry.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/seed-app-registry.sh` | **Result:** exists | **Severity:** info
64. **Claim:** `scripts/health-check.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/health-check.sh` | **Result:** exists | **Severity:** info
65. **Claim:** `scripts/migrate-firestore-paths.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/migrate-firestore-paths.sh` | **Result:** exists | **Severity:** info
66. **Claim:** `scripts/vps-setup.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/vps-setup.sh` | **Result:** exists | **Severity:** info
67. **Claim:** `scripts/deploy-discord-relay-vps.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/deploy-discord-relay-vps.sh` | **Result:** exists | **Severity:** info
68. **Claim:** `scripts/setup-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-branch-protection.sh` | **Result:** exists | **Severity:** info
69. **Claim:** `scripts/verify-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/verify-branch-protection.sh` | **Result:** exists | **Severity:** info
70. **Claim:** `scripts/setup-github-labels.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-github-labels.sh` | **Result:** exists | **Severity:** info
71. **Claim:** `scripts/setup-discord-channels.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-discord-channels.sh` | **Result:** exists | **Severity:** info
72. **Claim:** `scripts/gh-audit-log.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/gh-audit-log.sh` | **Result:** exists | **Severity:** info
73. **Claim:** `scripts/gh-auth-guard.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/gh-auth-guard.sh` | **Result:** exists | **Severity:** info
74. **Claim:** `scripts/google-oauth-bootstrap.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/google-oauth-bootstrap.sh` | **Result:** exists | **Severity:** info
75. **Claim:** `scripts/setup-agent-git-auth.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-agent-git-auth.sh` | **Result:** exists | **Severity:** info
76. **Claim:** `secrets/encrypted/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
77. **Claim:** `CLAUDE.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
78. **Claim:** `agents/evelynn/CLAUDE.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/evelynn/CLAUDE.md` | **Result:** exists | **Severity:** info
79. **Claim:** `tests/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
80. **Claim:** `secrets/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
81. **Claim:** `CLAUDE.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
82. **Claim:** `CONTRIBUTING.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
83. **Claim:** `CODE_OF_CONDUCT.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
84. **Claim:** `architecture/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/` | **Result:** exists | **Severity:** info
85. **Claim:** `agent-network.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
86. **Claim:** `agent-system.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
87. **Claim:** `claude-billing-comparison.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
88. **Claim:** `claude-runlock.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
89. **Claim:** `deployment.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
90. **Claim:** `discord-relay.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
91. **Claim:** `telegram-relay.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
92. **Claim:** `firebase-storage-cors.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
93. **Claim:** `git-workflow.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
94. **Claim:** `pr-rules.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
95. **Claim:** `testing.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
96. **Claim:** `infrastructure.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
97. **Claim:** `key-scripts.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
98. **Claim:** `mcp-servers.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
99. **Claim:** `plugins.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
100. **Claim:** `plan-gdoc-mirror.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
101. **Claim:** `platform-parity.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
102. **Claim:** `platform-split.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
103. **Claim:** `system-overview.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
104. **Claim:** `security-debt.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
105. **Claim:** `README.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
106. **Claim:** `docs/architecture/README.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
107. **Claim:** `scripts/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/` | **Result:** exists | **Severity:** info
108. **Claim:** `agents/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/` | **Result:** exists | **Severity:** info
109. **Claim:** `plans/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/` | **Result:** exists | **Severity:** info
110. **Claim:** `assessments/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/assessments/` | **Result:** exists | **Severity:** info
111. **Claim:** `scripts/setup-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-branch-protection.sh` | **Result:** exists | **Severity:** info
112. **Claim:** `scripts/verify-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/verify-branch-protection.sh` | **Result:** exists | **Severity:** info
113. **Claim:** `scripts/setup-discord-channels.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-discord-channels.sh` | **Result:** exists | **Severity:** info
114. **Claim:** `Duongntd/strawberry` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
115. **Claim:** `README.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
116. **Claim:** `github.com/harukainguyen1411/strawberry-app/pull/N` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
117. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
118. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
119. **Claim:** `.github/branch-protection.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
120. **Claim:** `branch-protection.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
121. **Claim:** `plans/approved/2026-04-17-branch-protection-enforcement.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/approved/2026-04-17-branch-protection-enforcement.md` | **Result:** exists | **Severity:** info
122. **Claim:** `assessments/2026-04-18-migration-dryrun.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/assessments/2026-04-18-migration-dryrun.md` | **Result:** exists | **Severity:** info
123. **Claim:** `gh repo create harukainguyen1411/strawberry-app --public --confirm` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
124. **Claim:** `gh api repos/harukainguyen1411/strawberry-app/actions/permissions --method PUT --field enabled=true --field allowed_actions=all` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
125. **Claim:** `gh api repos/harukainguyen1411/strawberry-app/actions/permissions/workflow --method PUT --field default_workflow_permissions=write --field can_approve_pull_request_reviews=true` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
126. **Claim:** `gh api repos/harukainguyen1411/strawberry-app/vulnerability-alerts --method PUT` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
127. **Claim:** `gh api repos/harukainguyen1411/strawberry-app/automated-security-fixes --method PUT` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
128. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
129. **Claim:** `harukainguyen1411/strawberry-agents` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
130. **Claim:** `git clone --bare https://github.com/Duongntd/strawberry.git /tmp/strawberry-filter.git` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
131. **Claim:** `git clone /tmp/strawberry-filter.git /tmp/strawberry-app && cd /tmp/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
132. **Claim:** `agents/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/` | **Result:** exists | **Severity:** info
133. **Claim:** `plans/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/` | **Result:** exists | **Severity:** info
134. **Claim:** `assessments/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/assessments/` | **Result:** exists | **Severity:** info
135. **Claim:** `architecture/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/` | **Result:** exists | **Severity:** info
136. **Claim:** `secrets/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
137. **Claim:** `tasklist/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
138. **Claim:** `incidents/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
139. **Claim:** `design/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
140. **Claim:** `mcps/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
141. **Claim:** `strawberry-b14/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
142. **Claim:** `CLAUDE.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
143. **Claim:** `agents/evelynn/CLAUDE.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/evelynn/CLAUDE.md` | **Result:** exists | **Severity:** info
144. **Claim:** `architecture/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/` | **Result:** exists | **Severity:** info
145. **Claim:** `docs/architecture/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
146. **Claim:** `scripts/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/` | **Result:** exists | **Severity:** info
147. **Claim:** `gitleaks detect --source=. --redact --report-path=/tmp/gitleaks.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
148. **Claim:** `gitleaks detect --source=. --log-opts="--all" --redact --report-path=/tmp/gitleaks-history.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
149. **Claim:** `/tmp/gitleaks.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
150. **Claim:** `Duongntd/strawberry` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
151. **Claim:** `agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md` | **Result:** exists | **Severity:** info
152. **Claim:** `/tmp/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
153. **Claim:** `/tmp/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
154. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
155. **Claim:** `scripts/setup-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-branch-protection.sh` | **Result:** exists | **Severity:** info
156. **Claim:** `scripts/verify-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/verify-branch-protection.sh` | **Result:** exists | **Severity:** info
157. **Claim:** `README.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
158. **Claim:** `/tmp/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
159. **Claim:** `git remote add origin https://github.com/harukainguyen1411/strawberry-app.git && git push -u origin main` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
160. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
161. **Claim:** `secrets/encrypted/github-triage-pat.txt.age` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
162. **Claim:** `.github/branch-protection.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
163. **Claim:** `plans/approved/2026-04-17-branch-protection-enforcement.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/approved/2026-04-17-branch-protection-enforcement.md` | **Result:** exists | **Severity:** info
164. **Claim:** `scripts/setup-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-branch-protection.sh` | **Result:** exists | **Severity:** info
165. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
166. **Claim:** `scripts/verify-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/verify-branch-protection.sh` | **Result:** exists | **Severity:** info
167. **Claim:** `scripts/setup-github-labels.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-github-labels.sh` | **Result:** exists | **Severity:** info
168. **Claim:** `.github/dependabot.yml` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
169. **Claim:** `package.json` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
170. **Claim:** `github.com/Duongntd/strawberry/pull` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
171. **Claim:** `github.com/harukainguyen1411/strawberry-app/pull` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
172. **Claim:** `Duongntd/strawberry` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
173. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
174. **Claim:** `architecture/git-workflow.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/git-workflow.md` | **Result:** exists | **Severity:** info
175. **Claim:** `architecture/pr-rules.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/pr-rules.md` | **Result:** exists | **Severity:** info
176. **Claim:** `CLAUDE.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
177. **Claim:** `agents/evelynn/CLAUDE.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/agents/evelynn/CLAUDE.md` | **Result:** exists | **Severity:** info
178. **Claim:** `architecture/cross-repo-workflow.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/cross-repo-workflow.md` | **Result:** exists | **Severity:** info
179. **Claim:** `scripts/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/` | **Result:** exists | **Severity:** info
180. **Claim:** `scripts/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/` | **Result:** exists | **Severity:** info
181. **Claim:** `secrets/age-key.txt` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
182. **Claim:** `secrets/age-key.txt` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
183. **Claim:** `Duongntd/strawberry` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
184. **Claim:** `plans/proposed/2026-04-17-dependabot-phase3.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/proposed/2026-04-17-dependabot-phase3.md` | **Result:** exists | **Severity:** info
185. **Claim:** `plans/proposed/2026-04-05-plan-viewer.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/proposed/2026-04-05-plan-viewer.md` | **Result:** exists | **Severity:** info
186. **Claim:** `plans/proposed/2026-04-09-autonomous-pr-lifecycle.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/proposed/2026-04-09-autonomous-pr-lifecycle.md` | **Result:** exists | **Severity:** info
187. **Claim:** `scripts/setup-branch-protection.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/setup-branch-protection.sh` | **Result:** exists | **Severity:** info
188. **Claim:** `/tmp/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
189. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
190. **Claim:** `https://github.com/Duongntd/strawberry/blob/main/plans/approved/2026-04-13-deployment-pipeline-architecture.md` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
191. **Claim:** `https://github.com/harukainguyen1411/strawberry-app/pull/N` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
192. **Claim:** `pre-commit-secrets-guard.sh` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
193. **Claim:** `~/Documents/Personal/strawberry-app/` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
194. **Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/scripts/plan-promote.sh` | **Result:** exists | **Severity:** info
195. **Claim:** `architecture/cross-repo-workflow.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/cross-repo-workflow.md` | **Result:** exists | **Severity:** info
196. **Claim:** `architecture/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/` | **Result:** exists | **Severity:** info
197. **Claim:** `harukainguyen1411/strawberry-app` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
198. **Claim:** `plans/approved/2026-04-17-branch-protection-enforcement.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/plans/approved/2026-04-17-branch-protection-enforcement.md` | **Result:** exists | **Severity:** info
199. **Claim:** `Duongntd/strawberry/pull/N` | **Anchor:** routing lookup | **Result:** unknown path prefix; add to contract if load-bearing | **Severity:** info
200. **Claim:** `architecture/cross-repo-workflow.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry/architecture/cross-repo-workflow.md` | **Result:** exists | **Severity:** info
