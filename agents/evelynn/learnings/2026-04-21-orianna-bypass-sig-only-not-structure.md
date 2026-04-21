# Orianna-Bypass suppresses signature hook only, not structure hook

**Date:** 2026-04-21
**Session:** 34b4f5e7 (S64-coda)
**Tags:** orianna, plan-lifecycle, admin-bypass, hooks

## Finding

The `Orianna-Bypass: <reason>` commit trailer bypasses the Orianna signature hook. It does NOT bypass the structure hook. When an admin `--no-verify` bypass is needed to promote the memory-consolidation plan (commits `536ec0d` + `a31cb78`), both hooks needed to be accounted for explicitly.

The current documentation in `architecture/plan-lifecycle.md` §D9.1 implies bypass is comprehensive. It is not. Two distinct hooks enforce plan promotion gating; the bypass flag is scoped to one.

## Decision gate

Durable, generalizable: any future admin bypass attempt that encounters a structure-hook block will be surprised by this gap. This is a real semantic ambiguity, not an edge case.

## Remediation

1. **Short term:** When using admin bypass on any plan-promotion commit, test with `--no-verify` and explicitly verify that both hooks are suppressed.
2. **Medium term:** Commission Swain or Karma for an ADR consolidating admin-bypass semantics across all hooks. The ADR should name both hooks, define bypass scope, and update `architecture/plan-lifecycle.md` §D9.1 accordingly.
3. **Long term:** Consider a single bypass mechanism that names which hooks it suppresses, making the scope explicit at commit time rather than implicit.
