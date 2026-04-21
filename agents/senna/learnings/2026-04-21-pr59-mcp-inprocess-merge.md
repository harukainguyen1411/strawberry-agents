# 2026-04-21 — PR #59 company-os mcp-inprocess-merge review

## Verdict
Request changes (posted as `--comment` per task spec — reviewer account `strawberry-reviewers-2` has no access to private `missmp/company-os`, so review posted under default `duongntd99` identity. That means no formal CHANGES_REQUESTED state, just advisory. Flagged the auth constraint.)

## Top finding — dropped input validation when porting MCP server TS→Python
Reference TS `demo-studio-mcp/src/server.ts` used zod: `z.string().regex(/^[a-zA-Z0-9_-]{1,128}$/)` on `session_id` for all three tools that accept it. Python port in `tools/demo-studio-v3/mcp_app.py` dropped the validation entirely — FastMCP only looks at the `session_id: str` type hint.

- `get_config` / `set_config` are defense-in-depth safe because `config_mgmt_client` calls `quote(sid, safe="")` before URL interpolation.
- **`_handle_trigger_factory` does NOT encode** — it does `f"/session/{session_id}/build"` directly, so `?`, `#`, `..`, `/` all inject into the URL sent to `DEMO_STUDIO_URL` with the `X-Internal-Secret` header attached. Agent-controlled payload can steer the request to arbitrary Demo Studio endpoints.

## Pattern — "parity regression" to check on any TS→Python port
When a port claims "error-string parity" with the reference, **also grep the reference for input-layer validation** that the target language's type system doesn't give you for free:
- zod regex / schemas → explicit re-validation needed in Python (FastMCP type hints don't enforce them)
- zod `min()/max()` → unbounded in Python
- zod `.refine()` → custom check needed

The port author enforced error-string parity perfectly (byte-for-byte) but the schema-layer validation wasn't in the "parity surface" they were targeting. Easy miss when porting because the validation lived at a different architectural layer (zod schema vs tool body).

## Other findings worth remembering
1. **`hmac.compare_digest` + explicit length guard** — the guard re-introduces the length side-channel the comment claims to avoid. `compare_digest` handles mismatched lengths safely on its own. Cosmetic-ish but the comment is a lie.
2. **xfail gate with `strict=False` after XPASS** — once impl lands, the xfail sentinels pass silently. If impl later regresses, test marks xfail and "passes" → regression signal defeated. Recommend removing xfail sentinels once duplicate coverage exists, or flipping `strict=True`.
3. **Test env pollution** — `os.environ["X"] = y` without teardown. Mock-vs-monkeypatch common miss. Cross-test ordering fragility.
4. **Dead try/except** re-raising without modification — pure noise, drop or add logging.

## Auth-lane constraint discovered
`strawberry-reviewers-2` is only provisioned on personal-org repos (`harukainguyen1411/*`, `Duongntd/*`) — no access to `missmp/*`. For work-concern PR reviews, must fall back to default `gh` auth (identity = `duongntd99`), which means:
- Task-specified `--comment` mode works fine (no self-approval conflict on advisory comments).
- `--approve` or `--request-changes` from Duong's identity on Duong's own agent PR would trip Rule 18 (no self-review).
- Lucian lane same constraint.

Flag to Evelynn/Sona: work-concern reviewer identity provisioning is an open gap for formal APPROVED/CHANGES_REQUESTED state on missmp PRs. For now, advisory comments are the best we can do.

## Rule 12 chain verification
Verified on this PR: xfail commits `62300a0` (A3) + `7860ef9` (A4) precede impl `2a64ea3` (A2) and `e01070e` (B1-B4). Clean.

## Review URL
https://github.com/missmp/company-os/pull/59
