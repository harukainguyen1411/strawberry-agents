---
date: 2026-04-16
topic: Pre-commit secrets scanning — workspace-wide design
---

# Pre-Commit Secrets Scanning — MMP Workspace

## Context

6 keys leaked in a git history scrub. Goal: prevent secrets from ever entering git history across 57+ repos (Go, Python, TypeScript, Vue).

---

## 1. Tool Selection — Gitleaks

**Recommendation: gitleaks**

Already installed at `/opt/homebrew/bin/gitleaks`.

Comparison:

| Tool | Speed | Accuracy | Allowlisting | Notes |
|------|-------|----------|--------------|-------|
| gitleaks | Fast (Go binary) | High, 150+ built-in rules | `.gitleaks.toml` allowlist | Best fit |
| trufflehog | Slower (entropy + regex) | Very high | Per-repo config | Better for history scans, overkill for pre-commit |
| detect-secrets | Moderate (Python) | Medium | `.secrets.baseline` | Requires Python env, per-repo baseline files |
| git-secrets | Fast | Low (AWS-only by default) | Pattern-based | Too narrow for multi-cloud/multi-token workspace |

Gitleaks wins because:
- Already installed — zero new tooling friction
- Single static binary, no runtime dependency (Python env, etc.)
- 150+ built-in rules covering AWS, GCP, GitHub tokens, Slack, Anthropic, Stripe, etc.
- `protect` mode designed specifically for pre-commit use (scans staged files only, fast)
- `.gitleaks.toml` supports per-pattern allowlisting with regex and file path rules
- Works identically across Go, Python, TypeScript repos — language-agnostic

---

## 2. Hook Architecture — Global git hook via core.hooksPath

**Recommendation: global hook directory via `git config --global core.hooksPath`**

Do NOT use the `pre-commit` Python framework or per-repo `.pre-commit-config.yaml`.

Rationale:
- 57 repos — maintaining 57 config files is untenable
- The `pre-commit` framework requires Python and `pip install pre-commit` on every machine; adds a non-trivial dependency
- A single shared hook directory is set once per developer machine and applies to ALL repos automatically
- No per-repo changes needed — new repos get protection immediately
- Consistent with the existing approach: the `flight-status-service` `commit-msg` hook shows the team is comfortable with git hooks

Architecture:

```
~/.config/git/hooks/          ← global hooks directory (one per developer machine)
  pre-commit                  ← runs gitleaks protect on staged files
  commit-msg                  ← can also enforce AI authorship rule here globally
```

Set globally:
```
git config --global core.hooksPath ~/.config/git/hooks
```

The pre-commit hook script:

```bash
#!/usr/bin/env bash
set -e

# Run gitleaks on staged files only
if command -v gitleaks &>/dev/null; then
  gitleaks protect --staged --redact --config ~/.config/git/gitleaks.toml
fi
```

Flags:
- `protect --staged` — scans only what is staged for this commit (fast, targeted)
- `--redact` — redacts secret values in error output (never prints the actual secret)
- `--config` — points to the shared allowlist config in the developer's home dir

---

## 3. What to Scan For

Gitleaks built-in rules cover the most common patterns automatically. Key rule groups that apply to this workspace:

- **Anthropic:** `sk-ant-api-*` keys
- **AWS:** `AKIA*` access keys, secret access keys
- **GCP:** service account JSON keys (`"type": "service_account"`), API keys (`AIza*`)
- **GitHub:** `ghp_` (PATs), `ghs_` (GitHub App secrets), `gho_` OAuth tokens
- **Slack:** `xoxb-` bot tokens, `xoxp-` user tokens, signing secrets
- **Stripe:** `sk_live_*`, `pk_live_*`
- **Generic:** high-entropy strings assigned to variables named `SECRET`, `TOKEN`, `PASSWORD`, `API_KEY`, `PRIVATE_KEY`
- **Private keys:** `-----BEGIN RSA PRIVATE KEY-----`, `-----BEGIN EC PRIVATE KEY-----`
- **Connection strings:** `postgres://user:password@`, `mongodb+srv://...`
- `.env` file contents with actual values (not placeholders)

The global `~/.config/git/gitleaks.toml` extends built-ins with workspace-specific patterns:

```toml
[extend]
useDefault = true   # include all 150+ built-in rules

[[rules]]
id = "mmp-internal-secret"
description = "MMP INTERNAL_SECRET env var with real value"
regex = '''INTERNAL_SECRET\s*=\s*[^\s"']{8,}'''
tags = ["mmp", "internal"]
```

---

## 4. Allowlisting

Three mechanisms, in priority order:

### a. Inline `# gitleaks:allow` comments
For individual lines in code/config files that are intentionally placeholder-looking:
```python
# gitleaks:allow
EXAMPLE_API_KEY = "sk-ant-example-key-for-docs"
```

Use sparingly — only for documentation examples and test fixtures that can't be restructured.

### b. `.gitleaks.toml` in repo root (allowlist by file path or regex)
Each repo can have its own `.gitleaks.toml` that extends the global one:
```toml
[extend]
path = "~/.config/git/gitleaks.toml"

[[rules.allowlist]]
description = "Test fixtures with fake keys"
paths = [
  "tests/fixtures/.*",
  "testdata/.*",
  "__tests__/.*",
]

[[rules.allowlist]]
description = "Example .env files use placeholders"
paths = [".*\\.env\\.example"]
regexes = ['''=\s*$''', '''=\s*<[^>]+>''', '''=\s*your[-_]''']
```

This file is committed per-repo — only add it when you have real false positives to suppress.

### c. Restructure test fixtures
Preferred over allowlisting. Replace fake-looking real-format keys in test fixtures with clearly fake patterns:
- Bad: `sk-ant-api03-AbCdEfGh...` (triggers scanner)
- Good: `sk-ant-TESTONLY-fake` (clearly fake, low entropy, won't match)
- Good: `test_api_key_placeholder` (no format match)

---

## 5. Enforcement

### Developer machines (primary enforcement)
The global hook runs on every `git commit`. It cannot be bypassed without explicit `--no-verify`. Team policy: `--no-verify` is prohibited except for emergency hotfixes, which require a Slack post explaining the bypass.

### CI enforcement (secondary layer, defense in depth)
Add gitleaks to every repo's CI pipeline as a job that runs on PR creation. This catches:
- Commits made before the hook was installed
- Anyone who bypassed with `--no-verify`
- CI-injected secrets that slip into artifacts

GitHub Actions step (add to existing CI workflow):
```yaml
- name: Scan for secrets
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    config-path: .gitleaks.toml  # optional, falls back to built-ins
```

This blocks PR merges when secrets are detected. Pair with branch protection requiring this check to pass.

### Ensuring all developers have hooks installed
Three mechanisms:

1. **Onboarding script** — add to the workspace setup script (ws-clone or equivalent):
   ```bash
   mkdir -p ~/.config/git/hooks
   cp scripts/git-hooks/pre-commit ~/.config/git/hooks/
   chmod +x ~/.config/git/hooks/pre-commit
   git config --global core.hooksPath ~/.config/git/hooks
   ```

2. **CI as backstop** — even if someone skips hook setup, CI catches it before merge

3. **Periodic audit** — quarterly check: ask team members to confirm `git config --global core.hooksPath` is set correctly

---

## 6. Rollout Plan

### Phase 1 — Tooling setup (Day 1, ~30 min)
1. Create `scripts/git-hooks/` directory in the workspace root (shared across all team members via ws-clone)
2. Write `scripts/git-hooks/pre-commit` (the hook script above)
3. Write `~/.config/git/gitleaks.toml` (the global allowlist config above)
4. Run `git config --global core.hooksPath ~/.config/git/hooks` on Duong's machine
5. Test: stage a fake `ANTHROPIC_API_KEY=sk-ant-test123` in a scratch file, confirm commit is blocked

### Phase 2 — CI integration (Day 1-2, ~1 hr)
1. Add gitleaks GitHub Actions step to the 5-10 most sensitive repos first:
   - `tse` (main API), `mcps`, `company-os`, `finance`, `secretary`
2. Run gitleaks in history-scan mode on these repos to confirm no existing leaks:
   ```
   gitleaks detect --source . --redact
   ```
3. For any findings: rotate the leaked key immediately, then add to allowlist if it's a false positive

### Phase 3 — Team rollout (Week 1)
1. Share the onboarding script with all engineers (Slack + update team runbook)
2. Add CI gitleaks check to remaining active repos
3. Add a note to CLAUDE.md: "never use --no-verify without posting justification in Slack"

### Phase 4 — History scan (Week 2)
1. Run `gitleaks detect` on full git history of high-risk repos
2. For any confirmed leaked keys: rotate immediately, do NOT rely on git history rewrite (keys are already exposed)
3. Document rotated keys in an internal security incident log (not committed anywhere)

---

## Key Decisions

- **gitleaks, not pre-commit framework** — simpler, no Python dep, already installed
- **Global hook, not per-repo** — one setup covers all 57 repos, new repos auto-protected
- **`protect --staged` not `detect`** — only scans staged files, keeps pre-commit fast (<1s)
- **`--redact` always** — never print the actual secret value in terminal output
- **CI as mandatory backstop** — hooks can be bypassed with `--no-verify`; CI cannot
- **Rotate, don't rewrite history** — history rewrite on a multi-person team is dangerous (breaks shared history); rotate the key, that's sufficient

---

## False Positive Patterns Observed in This Workspace

From prior PR reviews:
- GCP project IDs like `mmpt-233505` — not secrets, safe to commit
- `os.environ.get("KEY", "")` — reads from env, not hardcoded
- `.env.example` entries with empty values (`KEY=`) or placeholders (`KEY=your-key-here`)
- References to "Claude" as a product name in commit messages — not an authorship violation
- `INTERNAL_SECRET=` in `.env.example` with empty value — safe placeholder

These should be pre-emptively added to the global allowlist config.
