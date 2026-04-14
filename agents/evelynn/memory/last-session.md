# Last Session — 2026-04-13 (S41, Mac, Direct mode)

Long incident-response + pipeline hardening session. Dark Strawberry went down (~1 hour blank-page incident from a local deploy), recovered, and came out with a deploy lockdown, feature flags, storage fix, Gemini intake, and a multi-format I/O plan.

## Critical for next session

1. **Deploy lockdown is complete** — Firebase SA key rotated, Firebase CLI logged out locally, CI-only deploy enforced via PR #102 (merged). Nobody can `npm run deploy` to prod anymore. Credential-removal approach, not a 6-layer gate.

2. **Feature flags via Remote Config wired** — PR #103 merged. Client-side email allowlist active (Haruka's email shows Bee). Remote Config is wired for future rollouts. MCP custom signals blocked by SDK version mismatch (v10 → needs v11 for `setCustomSignals`) — not a blocker, just a known limitation.

3. **Firebase Storage initialized and rules fixed** — PR #104 merged. Storage was never initialized (the "CORS error" was a 404 misread). Katarina fixed wrong path prefix + placeholder UID. Storage is now live.

4. **Gemini intake bot** — Gemini API key set in Firebase Secret Manager. Ekko implemented PR #105 (local-testing ready, not merged). Check merge status next session. Syndra wrote the intake plan.

5. **Multi-format I/O plan from Swain** — plan written, check `plans/` for status. May need Duong approval before implementation.

6. **Skill-body stripping completed** — Katarina retroactively stripped leaked skill bodies from 18 historical transcripts (810 KB removed). Skill-body detector ported from workspace to strawberry's transcript cleaner.

7. **Lessons burned in this session:**
   - Never claim "no CI/CD" without checking `.github/workflows/` first — 10 workflows already existed.
   - Never run `npm run deploy` locally, bypassing CI. That was the blank-page incident.
   - Pyke ignored scope-change messages twice — rewrite the plan directly rather than messaging opus planners.
   - Ornn cannot respond in background subagent mode (no SendMessage). Route relay through Evelynn.
   - Duong prefers architectural enforcement over rules: "If the pipeline is robust then you can't make mistakes."

8. **PR #105 (Gemini intake)** — check merge/test status. Ekko had it local-testing ready at session close.
