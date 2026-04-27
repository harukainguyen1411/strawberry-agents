---
date: 2026-04-26
pr: 92
verdict: APPROVE
topic: no-AI-attribution detector tightening — structural fix for the false-positive class I had been catching
---

# PR #92 — attribution-phrase regex + override removal

## Context

This is the structural fix for the bare-token C-block false-positive class that's
been generating noise in my recent reviews (PR #89/#90/#91 vicinity — `opus model
tier`, `Sonnet executor profile`, etc., would block under the old
`(claude|anthropic|sonnet|opus|haiku|AI-generated)` C-pattern even when used in
purely technical contexts). T2 replaces the bare-token C-block with two narrow
patterns:

1. **Phrase**: `(Generated|Authored|Written|Co-authored|Coauthored)[[:space:]]+by[[:space:]]+(Claude|Anthropic|Sonnet|Opus|Haiku)` — case-insensitive verb + space + `by` + space + model.
2. **Trailing**: `(^|[[:space:]])[Bb]y[[:space:]]+(Claude|Anthropic)([[:space:]]*[.,;]|[[:space:]]*$)` — narrow EOL/punct-bounded trailing form.

Plus narrowed `claude.com` → `claude.com/code` verbatim. Plus removed
`Human-Verified: yes` early-exit blocks AND the rejection-message paragraphs from
both scripts.

## How I verified

1. Direct probing of 24 cases against the PR branch's hook script — all match
   expected behavior. Particularly important: `we stand by Claude in this
   matter` and `we stand by Claude's decision` both pass (allow) — the trailing
   regex correctly requires `[.,;]` or EOL after the model token, so apostrophe
   and space-letter avoid the pattern.
2. Ran the actual test harnesses: 30 + 27 passing.
3. Verified PR's own commit messages pass the new hook (no Human-Verified).
4. Audited shared-include sync: 30/30 agent defs updated; CLAUDE.md cleaned;
   only residual `Human-Verified` mentions are in script-header disclaimers
   stating it's inert.

## Findings

- One **suggestion-tier** observation: the hyphenated non-canonical trailer
  forms `Co-authored-by Claude` and `Co-Authored-By Claude` (no colon, hyphen
  before `by`, space before model) slip through. The phrase regex needs
  whitespace between verb and `by`; Pattern A needs the colon. This is a
  degenerate form unlikely in practice — git's canonical trailer always has
  the colon, which Pattern A catches.
- Possible follow-up tightening: extend Pattern A to `^Co-Authored-By[: ]`
  or loosen phrase regex to `[-[:space:]]+by[-[:space:]]+`. Filed as
  suggestion only; not a blocker.

## Lessons for me

- **Test the regex against the actual change before drafting the verdict.**
  I built a 24-case probe table covering false-positive avoidance,
  multi-whitespace, mixed case, hyphen variants, and trailing-form edge
  cases. This caught the `Co-authored-by Claude` gap that wouldn't have
  surfaced from reading the regex alone.
- **For shared-include changes, audit the propagation count.** I confirmed 30
  agent defs synced and that the legacy override sentence is gone from all
  of them, plus CLAUDE.md.
- **A "structural fix for false-positives I was catching" is the right time
  to be extra-rigorous about regression tests.** I confirmed
  XPASS on QA-C11/C12 (override-removal regressions) — these prove the
  override mechanism truly cannot be reintroduced silently.

## Test commands captured

```bash
# Extract PR scripts
git fetch origin no-ai-attr-detector-tightening
git show FETCH_HEAD:scripts/hooks/commit-msg-no-ai-coauthor.sh > /tmp/cm-hook.sh

# Run full test harness
git clone --branch no-ai-attr-detector-tightening https://github.com/harukainguyen1411/strawberry-agents /tmp/prtest
cd /tmp/prtest
bash tests/hooks/test_commit_msg_no_ai_coauthor.sh   # 30 pass
bash tests/ci/test_pr_lint_no_ai_attribution.sh      # 27 pass
```

## Verdict

APPROVE. Submitted via `scripts/reviewer-auth.sh --lane senna` as
`strawberry-reviewers-2`.
