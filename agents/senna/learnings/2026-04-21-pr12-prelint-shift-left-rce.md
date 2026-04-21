# PR #12 review — pre-lint shift-left hook shell injection

**Date:** 2026-04-21
**PR:** harukainguyen1411/strawberry-agents#12
**Verdict:** CHANGES_REQUESTED
**Review URL:** https://github.com/harukainguyen1411/strawberry-agents/pull/12#pullrequestreview-PRR_kwDOSGFeXc73EscK

## Top finding — RCE via rule-4 path-existence check

`scripts/hooks/pre-commit-zz-plan-structure.sh:369-373` splices any backtick-quoted token from a plan body into a shell command via string concatenation:

```awk
full_path = REPO_ROOT "/" token
cmd = "test -e " "\"" full_path "\"" " && echo y || echo n"
cmd | getline exists
```

The is-path regex has a weak second branch (`index(token, "/") > 0 && token !~ /[[:space:]]/`) that admits shell metacharacters. Brace expansion `{touch,/tmp/foo}` smuggles a space-free `touch` invocation, bypassing the "no whitespace" filter. Confirmed silent RCE: the hook reports BLOCK as expected AND executes the injected command.

Exploit body: `` `foo/";{touch,/tmp/senna-rce-silent.flag};:;#` ``.

Recommended fix: replace `cmd | getline` with `getline _ < full_path` (awk-native, no shell). Alternative is to move the path-existence loop out of awk into the parent shell with a `null`-separated path list.

## Review pattern — when is-path detection is involved, probe for injection

Any time a reviewer sees user-controlled content flowing into a `cmd | getline` or `system()` in awk (or `sh -c` / `eval` in shell), probe for injection with at least:

1. Double-quote to break out of an enclosing `"..."`.
2. Brace-expansion `{cmd,arg1,arg2}` to smuggle a space-free command when whitespace is filtered.
3. `;` followed by `:` (null cmd) followed by `#` to silence errors after the payload.

This combination evades most of the common naive filters.

## Grandfathering check that worked

`git diff --cached --name-only --diff-filter=ACM | grep '^plans/.*\.md$'` correctly ignores unstaged broken plans. Confirmed by seeding a grandfathered broken plan, modifying an unrelated file, and observing the hook exit 0. Good.

## Grandfathering hole I found

`--diff-filter=ACM` omits `R` (rename). A `git mv old.md new.md` + edit of new.md passes undetected. The PR body claims "grandfathered until next edit" but a rename+edit is an edit. Fix: `--diff-filter=ACMR`.

## False positives in rule-2 unit-literal detection

`index(prose, "(d)") > 0` and `index(prose, "h)") > 0` are substring matches — they trip on enumerated lists like `a), b), ... h)` or `(a), (b), (c), (d)`. Orianna itself writes such enumerations in DoD prose. Fix: require a preceding digit, e.g. `[0-9]+[[:space:]]*\(d\)`.

## YAML frontmatter parsing — trailing comments

`tests_required: false  # infra only` parses as `v = "false  # infra only"`, fails the `!= "false"` check, and incorrectly demands a `## Test plan` section. Fix: also `sub(/[[:space:]]*#.*$/, "", v)` when stripping whitespace.

## Lane separation verified working

This is the first PR where I reviewed alongside Lucian after the reviewer-lane separation (strawberry-reviewers vs strawberry-reviewers-2) went live. Lucian APPROVED on the earlier review slot; my CHANGES_REQUESTED landed on a separate slot and is visible in `gh pr view --json reviews`. GitHub did not collapse or overwrite either. Pattern holds.

## Benchmark note

PR body claims 180ms for 10 staged plans. My local run on this hardware (macOS darwin-24.6.0, M-series) clocked 490-600ms depending on content. Not under SLA pressure, but worth calling out when the PR pins a specific number.
