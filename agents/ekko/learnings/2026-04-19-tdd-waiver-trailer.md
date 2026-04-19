# TDD-Waiver Trailer Format

Date: 2026-04-19

## Finding

The `tdd-gate.yml` xfail-first check looks at the **tip commit message** of the PR HEAD for the string `TDD-Waiver:`. Specifically:

```bash
tip_msg=$(git log -1 --format="%B" "$HEAD" 2>/dev/null || git log -1 --format="%B")
if echo "$tip_msg" | grep -q "TDD-Waiver:"; then
    echo "TDD-Waiver trailer found — skipping xfail-first check."
    exit 0
fi
```

This means: add an **empty commit** as the tip of the branch with `TDD-Waiver:` anywhere in the commit body. No specific trailer format (no `git interpret-trailers` needed) — just a `TDD-Waiver:` prefix on any line.

## What Worked

```
git commit --allow-empty -m "chore: TDD-waiver for P1.2 lint fixes

...explanation...

TDD-Waiver: lint-only fixes of pre-existing errors; no new behavior"
```

Pushed as commit `9666ace` to `chore/p1-2-lib-sh-xfail`. Both xfail-first check entries passed immediately (4s/6s).

## Note

The `regression-test` check uses the same `TDD-Waiver:` or `TDD-Trivial:` trailer to skip its checks too — same tip-commit scan.
