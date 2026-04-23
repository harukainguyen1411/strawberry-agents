---
plan: plans/in-progress/personal/2026-04-20-strawberry-inbox-channel.md
checked_at: 2026-04-22T14:02:05Z
auditor: orianna
claude_cli: absent
block_findings: 16
warn_findings: 0
info_findings: 199
---

## Block findings

1. **Claim:** `scripts/hooks/inbox-nudge.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-nudge.sh` | **Result:** path not found | **Severity:** block
2. **Claim:** `scripts/hooks/inbox-nudge.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-nudge.sh` | **Result:** path not found | **Severity:** block
3. **Claim:** `plans/in-progress/2026-04-20-strawberry-inbox-channel` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/plans/in-progress/2026-04-20-strawberry-inbox-channel` | **Result:** path not found | **Severity:** block
4. **Claim:** `assessments/qa-reports/2026-04-…-inbox-watch.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/assessments/qa-reports/2026-04-…-inbox-watch.md` | **Result:** path not found | **Severity:** block
5. **Claim:** `scripts/hooks/tests/inbox-watch.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch.test.sh` | **Result:** path not found | **Severity:** block
6. **Claim:** `scripts/hooks/tests/inbox-watch-bootstrap.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-bootstrap.test.sh` | **Result:** path not found | **Severity:** block
7. **Claim:** `scripts/hooks/tests/inbox-channel.integration.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-channel.integration.test.sh` | **Result:** path not found | **Severity:** block
8. **Claim:** `scripts/hooks/tests/inbox-channel.fault.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-channel.fault.test.sh` | **Result:** path not found | **Severity:** block
9. **Claim:** `agents/nonexistent/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/nonexistent/` | **Result:** path not found | **Severity:** block
10. **Claim:** `scripts/hooks/inbox-migrate.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-migrate.sh` | **Result:** path not found | **Severity:** block
11. **Claim:** `scripts/hooks/inbox-migrate.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-migrate.sh` | **Result:** path not found | **Severity:** block
12. **Claim:** `scripts/hooks/inbox-migrate.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-migrate.sh` | **Result:** path not found | **Severity:** block
13. **Claim:** `scripts/hooks/tests/inbox-watch.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch.test.sh` | **Result:** path not found | **Severity:** block
14. **Claim:** `scripts/hooks/tests/inbox-watch-bootstrap.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-bootstrap.test.sh` | **Result:** path not found | **Severity:** block
15. **Claim:** `scripts/hooks/tests/inbox-channel.integration.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-channel.integration.test.sh` | **Result:** path not found | **Severity:** block
16. **Claim:** `scripts/hooks/tests/inbox-channel.fault.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-channel.fault.test.sh` | **Result:** path not found | **Severity:** block

## Warn findings

None.

## Info findings

1. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
2. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
3. **Claim:** `code.claude.com/docs/en/tools-reference#monitor-tool` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
4. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
5. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
6. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
7. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
8. **Claim:** `.claude/skills/agent-ops/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/agent-ops/SKILL.md` | **Result:** exists | **Severity:** info
9. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
10. **Claim:** `.claude/skills/check-inbox/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/check-inbox/SKILL.md` | **Result:** exists | **Severity:** info
11. **Claim:** `.claude/skills/check-inbox/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/check-inbox/SKILL.md` | **Result:** exists | **Severity:** info
12. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
13. **Claim:** `scripts/hooks/tests/inbox-watch-test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-test.sh` | **Result:** exists | **Severity:** info
14. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
15. **Claim:** `2>/dev/null` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
16. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
17. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
18. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
19. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
20. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
21. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
22. **Claim:** `.claude/skills/check-inbox/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/check-inbox/SKILL.md` | **Result:** exists | **Severity:** info
23. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
24. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
25. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
26. **Claim:** `scripts/hooks/inbox-watch-bootstrap.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch-bootstrap.sh` | **Result:** exists | **Severity:** info
27. **Claim:** `inbox-watch-bootstrap.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
28. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
29. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
30. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
31. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
32. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
33. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
34. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
35. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
36. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
37. **Claim:** `agents/evelynn/inbox/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/evelynn/inbox/` | **Result:** exists | **Severity:** info
38. **Claim:** `agents/evelynn/inbox/archive/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/evelynn/inbox/archive/` | **Result:** exists | **Severity:** info
39. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
40. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
41. **Claim:** `agents/evelynn/inbox/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/evelynn/inbox/` | **Result:** exists | **Severity:** info
42. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
43. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
44. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
45. **Claim:** `.claude/skills/agent-ops/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/agent-ops/SKILL.md` | **Result:** exists | **Severity:** info
46. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
47. **Claim:** `/compact` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
48. **Claim:** `settings.json` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
49. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
50. **Claim:** `scripts/hooks/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/` | **Result:** exists | **Severity:** info
51. **Claim:** `inbox-nudge.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
52. **Claim:** `scripts/hooks/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/` | **Result:** exists | **Severity:** info
53. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
54. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
55. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
56. **Claim:** `old-msg.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
57. **Claim:** `fresh-msg.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
58. **Claim:** `archive/2026-03/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
59. **Claim:** `archive/2026-04/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
60. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
61. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
62. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
63. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
64. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
65. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
66. **Claim:** `scripts/plan-promote.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/plan-promote.sh` | **Result:** exists | **Severity:** info
67. **Claim:** `scripts/hooks/tests/inbox-watch-test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-test.sh` | **Result:** exists | **Severity:** info
68. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
69. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
70. **Claim:** `2>/dev/null` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
71. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
72. **Claim:** `scripts/hooks/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/` | **Result:** exists | **Severity:** info
73. **Claim:** `scripts/hooks/tests/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/` | **Result:** exists | **Severity:** info
74. **Claim:** `scripts/orianna-fact-check.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/orianna-fact-check.sh` | **Result:** exists | **Severity:** info
75. **Claim:** `.claude/plugins/strawberry-inbox/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/plugins/strawberry-inbox/` | **Result:** exists | **Severity:** info
76. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
77. **Claim:** `scripts/hooks/tests/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/` | **Result:** exists | **Severity:** info
78. **Claim:** `settings.json` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
79. **Claim:** `~/Documents/Personal/strawberry-agents/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
80. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
81. **Claim:** `scripts/hooks/tests/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/` | **Result:** exists | **Severity:** info
82. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
83. **Claim:** `scripts/hooks/inbox-watch-bootstrap.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch-bootstrap.sh` | **Result:** exists | **Severity:** info
84. **Claim:** `.claude/skills/check-inbox/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/check-inbox/SKILL.md` | **Result:** exists | **Severity:** info
85. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
86. **Claim:** `scripts/hooks/tests/inbox-watch-test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-test.sh` | **Result:** exists | **Severity:** info
87. **Claim:** `harukainguyen1411/strawberry-agents` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
88. **Claim:** `scripts/hooks/tests/inbox-watch-test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-test.sh` | **Result:** exists | **Severity:** info
89. **Claim:** `fixture/inbox-empty/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
90. **Claim:** `fixture/inbox-one-pending/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
91. **Claim:** `fixture/inbox-mixed/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
92. **Claim:** `archive/2026-03/stale.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
93. **Claim:** `fixture/inbox-no-identity/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
94. **Claim:** `fixture/inbox-opt-out/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
95. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
96. **Claim:** `pre-push-tdd.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
97. **Claim:** `agents/viktor/inbox/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/viktor/inbox/` | **Result:** exists | **Severity:** info
98. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
99. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
100. **Claim:** `2>/dev/null` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
101. **Claim:** `fixture/inbox-empty/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
102. **Claim:** `fixture/inbox-one-pending/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
103. **Claim:** `fixture/inbox-mixed/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
104. **Claim:** `scripts/hooks/inbox-watch-bootstrap.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch-bootstrap.sh` | **Result:** exists | **Severity:** info
105. **Claim:** `scripts/hooks/inbox-watch-bootstrap.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch-bootstrap.sh` | **Result:** exists | **Severity:** info
106. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
107. **Claim:** `.claude/skills/check-inbox/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/check-inbox/SKILL.md` | **Result:** exists | **Severity:** info
108. **Claim:** `.claude/skills/check-inbox/SKILL.md` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/check-inbox/SKILL.md` | **Result:** exists | **Severity:** info
109. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
110. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
111. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
112. **Claim:** `2026-04/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
113. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
114. **Claim:** `scripts/hooks/inbox-watch-bootstrap.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch-bootstrap.sh` | **Result:** exists | **Severity:** info
115. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
116. **Claim:** `scripts/hooks/tests/inbox-watch-test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-test.sh` | **Result:** exists | **Severity:** info
117. **Claim:** `scripts/hooks/tests/inbox-watch-test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/inbox-watch-test.sh` | **Result:** exists | **Severity:** info
118. **Claim:** `scripts/hooks/tests/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/` | **Result:** exists | **Severity:** info
119. **Claim:** `scripts/hooks/inbox-watch.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch.sh` | **Result:** exists | **Severity:** info
120. **Claim:** `scripts/hooks/inbox-watch-bootstrap.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/inbox-watch-bootstrap.sh` | **Result:** exists | **Severity:** info
121. **Claim:** `.claude/skills/check-inbox/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/check-inbox/` | **Result:** exists | **Severity:** info
122. **Claim:** `.claude/settings.json` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/.claude/settings.json` | **Result:** exists | **Severity:** info
123. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
124. **Claim:** `inbox-watch-bootstrap.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
125. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
126. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
127. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
128. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
129. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
130. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
131. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
132. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
133. **Claim:** `scripts/hooks/tests/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/` | **Result:** exists | **Severity:** info
134. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
135. **Claim:** `inbox-watch.test.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
136. **Claim:** `scripts/hooks/tests/pre-compact-gate.test.sh` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/pre-compact-gate.test.sh` | **Result:** exists | **Severity:** info
137. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
138. **Claim:** `archive/2026-04/foo.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
139. **Claim:** `archive/2026-03/old.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
140. **Claim:** `archive/2026-04/fresh.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
141. **Claim:** `old.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
142. **Claim:** `fresh.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
143. **Claim:** `archive/2026-03/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
144. **Claim:** `archive/2026-04/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
145. **Claim:** `archive/2026-03/a.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
146. **Claim:** `archive/2026-03/b.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
147. **Claim:** `a.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
148. **Claim:** `b.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
149. **Claim:** `archive/2026-03/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
150. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
151. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
152. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
153. **Claim:** `archive/2026-03/old.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
154. **Claim:** `.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
155. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
156. **Claim:** `archive/.DS_Store` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
157. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
158. **Claim:** `inbox-watch-bootstrap.test.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
159. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
160. **Claim:** `inbox-channel.integration.test.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
161. **Claim:** `agents/evelynn/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/evelynn/` | **Result:** exists | **Severity:** info
162. **Claim:** `agents/sona/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/sona/` | **Result:** exists | **Severity:** info
163. **Claim:** `agents/evelynn/inbox/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/agents/evelynn/inbox/` | **Result:** exists | **Severity:** info
164. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
165. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
166. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
167. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
168. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
169. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
170. **Claim:** `/agent-ops` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
171. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
172. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
173. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
174. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
175. **Claim:** `inbox-watch-bootstrap.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
176. **Claim:** `inbox-channel.fault.test.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
177. **Claim:** `inbox/foo.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
178. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
179. **Claim:** `inbox/foo.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
180. **Claim:** `inbox/foo.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
181. **Claim:** `inbox/foo.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
182. **Claim:** `inbox/foo.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
183. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
184. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
185. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
186. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
187. **Claim:** `/check-inbox` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
188. **Claim:** `archive/2026-03/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
189. **Claim:** `2>/dev/null` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
190. **Claim:** `archive/2026-03/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
191. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
192. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
193. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
194. **Claim:** `inbox-watch.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
195. **Claim:** `inbox/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
196. **Claim:** `SKILL.md` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
197. **Claim:** `archive/` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
198. **Claim:** `scripts/hooks/tests/` | **Anchor:** `test -e /Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/tests/` | **Result:** exists | **Severity:** info
199. **Claim:** `.test.sh` | **Anchor:** routing lookup | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
