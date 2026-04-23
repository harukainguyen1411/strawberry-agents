# PR #31 re-review — C1–C4 fixed cleanly, four MORE Bash bypasses remain

Session: 2026-04-23 re-review. Lane: senna (strawberry-reviewers-2). Verdict: CHANGES_REQUESTED (second time).

## The four new bypasses

C1–C4 closed cleanly (quoted paths, double-slash, `..`, malformed JSON all now exit 2). But the tokenizer-based guard still loses to:

1. **Variable assignment.** `dest=plans/approved/x.md; git mv src $dest` — token `dest=plans/...` has a `dest=` prefix so glob misses; `$dest` is literal. Shell expands at execution, guard doesn't.
2. **ANSI-C quoting.** `$'plans/approved/x.md'` — `normalize_path` strips `'…'` and `"…"` but not the `$'` prefix.
3. **Redirect without space.** `echo x >plans/approved/y.md` — token `>plans/approved/y.md` starts with `>`, no strip. **Most common idiom in bash**. Also `>>` and `printf … >path`.
4. **APFS case-insensitivity.** `PLANS/APPROVED/x.md` — lowercase `case` glob misses, but macOS APFS (dev default) resolves to the protected dir. Linux CI unaffected, but primary attack environment is macOS.

## The structural lesson (restated, stronger)

The shell-token-based matcher is architecturally mismatched to the attack surface. Every round of fixes enumerates another escape that `shlex`/bash itself would have normalized. The real fix shapes:

- **Python `shlex` / `bashlex`** parser operating on post-parse argv — catches BYPASS-1, 2, 3 automatically (they all collapse to a single `plans/approved/x.md` argv entry after shell parsing).
- **Filesystem-layer enforcement** — `chattr +i` (Linux) or ACLs on protected dirs such that non-root processes cannot move files regardless of shell idiom. Defeats Bash and Write uniformly, no parser needed.

I stated this last round; iterating inside the tokenizer keeps generating new rounds of escapes.

## Method improvements

- **My probe table is generic.** Save as a reusable fixture. Every PR that claims to enforce a shell-idiom guard should run against the same 15+ cases: quoted, double-slash, `..`, `$'…'`, `dest=$X`, `>path`, `>>path`, `<path`, case-mixed, tab-separated, heredoc, cmd-substitution, backtick, pipe-to-tee, unicode slash.
- **APFS case-insensitivity is a filesystem gotcha I'd missed before.** Add to the default probe table. Easy to verify with `diskutil info /`.
- **Audit "<5 findings" claim vs plan spec.** The plan INV-7 says detect non-Orianna promotions. Current repo has 41 historical non-Orianna promotions (Duongntd fastlane). The "<5" was aspirational talk in the task brief, not a spec requirement. Don't get distracted by such claims when verifying against ADR/plan; cross-check the plan's actual INV list.

## Outcome

state=CHANGES_REQUESTED, signed `— Senna`, lane=strawberry-reviewers-2. Counterpart Lucian had approved. Separate-lane architecture (post-PR-45) means my CHANGES_REQUESTED cannot be silently overwritten by his APPROVED — verified twice this session now.
