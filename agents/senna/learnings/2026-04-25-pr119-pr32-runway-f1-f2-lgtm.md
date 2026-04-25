---
date: 2026-04-25
pr: missmp/company-os#119
verdict: LGTM (advisory)
concern: work
---

# PR #119 — PR32 RUNWAY F1+F2 hotfix code-quality review

## Verdict

LGTM (advisory). No request-changes findings across F1, F2, T2, T6.

Comment posted as `duongntd99` via `scripts/post-reviewer-comment.sh`:
https://github.com/missmp/company-os/pull/119#issuecomment-4318520987

## Findings worth keeping

1. **Substring disambiguation pattern for absence-asserts.** The test asserts
   `"import factory_bridge\n" not in src` and `"factory_bridge.trigger_factory(" not in src`.
   The `\n` anchor is load-bearing because `import factory_bridge` is a strict
   substring of `import factory_bridge_v2`. The trailing `(` on the call assert
   carries the same role for `trigger_factory_v2(`. Empirical verification (sed-revert
   the file, run the test) is the only way to know these asserts are actually tight —
   added that to my review checklist for any "module name + version suffix" rename.

2. **Optional-kwarg drop is not always a bug.** `_default_trigger_build` passes only
   `session_id` to `trigger_factory_v2(session_id, project_id=None)`, dropping any
   `**kwargs`. Looked like a smell at first; turned out the agent-driven `trigger_factory`
   tool has empty `input_schema.properties` so there's nothing to forward, and the
   new-flow direct caller at `main.py:2735` passes `project_id` explicitly on its own
   path. Kwarg-drop here is intentional. Lesson: trace the call graph before flagging.

3. **Docker `.dockerignore` glob scope.** `*` doesn't cross `/` (Go `filepath.Match`),
   so flat-filename patterns like `.env.*.local` are safe and don't over-match into
   subdirectories. Good sanity check pattern: enumerate sibling `.env*` files
   (`.env.example` here) and confirm none match unintentionally.

4. **`fix(scope):` works in company-os.** Repo convention: PRs #114, #115 use
   `fix(demo-studio-v3):` — Strawberry's Rule 5 (`apps/**` vs `chore:`) is a personal-
   scope rule, not a work-scope rule. Don't paste personal Rule 5 into work-scope
   reviews.

5. **Anonymity hook caught my agent name.** I drafted "Senna code-quality review" in
   the body header; `post-reviewer-comment.sh` exit 3 caught it before posting. Cheap
   self-check: `grep -E "Senna|Lucian|Sona|Evelynn|claude" body.md` before invoking the
   poster. Cost me one round-trip; would prefer zero.
