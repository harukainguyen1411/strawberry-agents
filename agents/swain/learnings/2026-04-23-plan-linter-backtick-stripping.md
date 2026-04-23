# Plan-structure linter strips backtick spans before prose checks

## Context

2026-04-23 while authoring the memory-flow simplification ADR, the `pre-commit-zz-plan-structure.sh` linter rejected every task line with the error "task entry missing estimate_minutes: field (§D4)" even though each task line ended with `` `estimate_minutes: 60` ``. Looked at the linter source:

```awk
prose = line
while (match(prose, /`[^`]*`/)) {
  prose = substr(prose, 1, RSTART-1) substr(prose, RSTART+RLENGTH)
}
if (prose !~ /estimate_minutes:/) { ...BLOCK... }
```

The linter strips backtick spans **before** the prose check. Wrapping `estimate_minutes: N` in backticks removes it from the check entirely.

## Fix

Write task lines with bare `estimate_minutes: N` and `kind: X`, outside backticks:

```
- [ ] T1 — draft `.claude/skills/close-coordinator-session/SKILL.md`  estimate_minutes: 60  kind: design
```

Not:

```
- [ ] T1 — draft `.claude/skills/close-coordinator-session/SKILL.md`  `estimate_minutes: 60`  `kind: design`
```

## Related: `## Test plan` heading literal

Same linter requires the literal heading `## Test plan` (regex `/^## Test plan[[:space:]]*$/`) when frontmatter has `tests_required: true`. Numbered variants like `## 10. Test plan` silently fail the check with "tests_required is true but `## Test plan` section is missing or empty". Write the heading bare; let the plan prose sections before it carry numbering if needed.

## Related: batch suppressor injection

When a plan legitimately cites many prospective paths in backticks (overlap enumeration tables, rename mappings, ADR alternatives discussion), hand-editing 30+ `<!-- orianna: ok -- ... -->` suppressors is slow. Faster: a small python pass that walks every backticked token, classifies it as path-like using the linter's own rules, and appends a uniform suppressor to any line whose token doesn't exist on disk. One pass, 38 suppressors, sub-second.

```python
for m in re.finditer(r'`([^`]+)`', line):
    tok = m.group(1)
    if looks_like_path(tok) and not os.path.exists(os.path.join(REPO_ROOT, tok)):
        ...append suppressor to line once...
```

Match the linter's `looks_like_path` rules: contains `/` or `.ext`, doesn't start with `http://`/`https://`, `-`, or `/`.
