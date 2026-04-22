---
title: Orianna URL host frequency — top-5 hosts flagged in last 30 days
author: viktor
created: 2026-04-22
concern: personal
kind: advisory
related:
  - plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md
  - assessments/orianna-prompt-audit-2026-04-21.md
---

# Orianna URL host frequency (last 30 days)
# Task T11.b of plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md

## Scope

Grep of all `assessments/plan-fact-checks/2026-04-2*.md` reports for
URL-shaped tokens that Orianna flagged in Step C or Step E. Count per host.
Evidence for a v2 allowlist expansion PR (not a code change in this plan).

Sample window: 2026-04-20 to 2026-04-22 (all fact-check reports produced
since the gate-v2 regime shipped).

---

## Top-5 host table

| Rank | Host | Raw count | Flagged as block | Flagged as info/Step E trigger | Notes |
|------|------|----------:|:----------------:|:------------------------------:|-------|
| 1 | `platform.claude.com` | 19 | 1 | 18 | The single block was on a bare-path token (`platform.claude.com/docs/en/managed-agents/sessions`) treated as a filesystem path by Step C (work-concern routing). All others were Step E triggers that resolved info after WebFetch confirmed the page live. |
| 2 | `code.claude.com` | 10 | 0 | 10 | All Step E triggers for the `Monitor` tool documentation URL (`code.claude.com/docs/en/tools-reference#monitor-tool`). Resolved info on every invocation — page confirmed live, Monitor tool existence verified. |
| 3 | `anthropic.com` | 2 | 0 | 2 | Appeared as bare `anthropic.com` in suppressed lines (not as actual Step E triggers). Logged as info only. |
| 4 | `identitytoolkit.googleapis.com` | 2 | 0 | 2 | Both occurrences on `<!-- orianna: ok -->` suppressed lines in the firebase-auth plan. Logged as info (author-suppressed). |
| 5 | `github.com` | 0 | 0 | 0 | No github.com URL appearances as unsuppressed backtick claims in the sample window. Only appeared inside prose links `[text](url)` which bypass the Step C extractor. |

---

## Notes on the T9 allowlist

T9 (`scripts/orianna-pre-fix.sh`) seeds the auto-suppressor allowlist with
three hosts: `platform.claude.com`, `docs.anthropic.com`, and `github.com`.

From this data:
- `platform.claude.com` — confirmed as the dominant trigger host. T9 allowlist entry is correct.
- `code.claude.com` — second-highest trigger (10 hits) and NOT currently in the T9 allowlist. Recommend adding `code.claude.com` to the T9 initial allowlist. All 10 triggers resolved info; live-verification cost was wasted.
- `docs.anthropic.com` — zero hits in this window. T9 entry is speculative but harmless.
- `github.com` — zero unsuppressed hits. T9 entry is speculative but harmless (matches Sona's feedback doc §1 recommendation for prose hosts).
- `identitytoolkit.googleapis.com` — only 2 hits, both already suppressed. Not a T9 candidate.

**Recommendation:** add `code.claude.com` to the T9 auto-suppressor allowlist as a fourth entry alongside the three currently specified.

---

## Methodology

```bash
grep -roh "https://[a-zA-Z0-9._/-]*" \
  assessments/plan-fact-checks/2026-04-2*.md \
  | sed 's|.*https://||' | sed 's|/.*||' \
  | sort | uniq -c | sort -rn
```

Additional targeted greps for bare-host tokens not prefixed with `https://`:
```bash
grep -roh "platform\.claude\.com\|docs\.anthropic\.com\|github\.com\|code\.claude\.com\|identitytoolkit\.googleapis\.com\|anthropic\.com" \
  assessments/plan-fact-checks/2026-04-2*.md \
  | sed 's|.*:||' | sort | uniq -c | sort -rn
```

Results cross-checked against report text to separate Step C blocks,
Step E triggers, and author-suppressed info from actual load-bearing flags.
