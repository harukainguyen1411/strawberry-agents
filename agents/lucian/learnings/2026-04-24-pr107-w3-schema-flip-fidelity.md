---
date: 2026-04-24
agent: lucian
pr: missmp/company-os#107
topic: W3 set_config schema flip + soft-fail validation — plan-fidelity review
verdict: clean (advisory only — reviewer-auth cross-repo gap)
---

# PR #107 — W3 config-schema flip fidelity

Plan audited: `plans/in-progress/work/2026-04-23-agent-owned-config-flow.md` §4 W3.
(Caller named `2026-04-23-demo-studio-config-architecture.md` which does not exist — the canonical slug is `agent-owned-config-flow`.)

## Verdict
Plan-fidelity clean across all 7 caller-requested checks. No structural blocks. Three drift notes, none blocking.

## Checks resolved
1. Schema flip {path,value} → {config: object} — matches §D2.
2. Soft-fail + force=true retry — bounded at 1 retry; validation surfaced in tool_result; matches §D7.
3. T-hotfix deletion — `_default_patch_config`, `_apply_dotted_path`, `_SESSION_LOCKS`, `_get_session_lock` all removed. Shim symbol `_default_snapshot_config_shim` never landed (plan §A1 assumption held).
4. BD.B.3 invariant — `_handle_set_config` does not import or call session-doc helpers; `agent_proxy.py` closure only threads `sse_sink`. Static regression guard asserts `_UPDATABLE_FIELDS` excludes `{configVersion, seededConfig, seedSentAt}`.
5. OQ-K2 prose — ARCHITECTURE.md §SSE Schema — Additivity Contract covers producer+consumer obligations with enforcement claim.
6. Rule 12 — xfail `5a8ad11` at 03:00Z precedes impl `2a10732` at 03:21Z on same branch. Guard uses runtime `_w3_impl_present()` probe (no marker removal needed).
7. Scope creep — SYSTEM_PROMPT edits overlap W2.T6 / W5.T3 scope but are semantically required for W3's tool-shape flip.

## Drift notes
- D-1. PR body names wrong plan slug (`demo-studio-config-architecture`). Commits reference correct slug.
- D-2. SYSTEM_PROMPT edits absorbed from W2/W5 — risk of merge churn with later PRs.
- D-3. Concurrent-write race profile deliberately changes from lock-serialised to S2 last-write-wins. Hotfix test TS.HF-SC.5 correctly xfail(strict=False).

## Advisory-comment posting
`strawberry-reviewers` token returns 404 on `/repos/missmp/company-os/issues/107/comments` — same cross-repo access gap as PR #103/#104/#105/#106. Comment NOT posted; findings returned to Sona for relay via an authenticated identity if wanted.

## Pattern reinforced
Caller-supplied plan paths have drifted before. Always grep the plan index when the named slug does not resolve.
