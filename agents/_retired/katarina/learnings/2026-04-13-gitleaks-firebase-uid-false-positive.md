# Gitleaks false-positive on Firebase UIDs

## Pattern
Gitleaks `generic-api-key` rule flags Firebase UIDs hardcoded in source files. Firebase UIDs are ~28-char alphanumeric strings with entropy high enough to trigger the heuristic. This is a false positive — UIDs are not secrets.

## Solution
Add `// gitleaks:allow` (or `# gitleaks:allow` for non-JS) as an inline comment on the offending line. Gitleaks respects these inline suppressions.

Do NOT add the file path to the `.gitleaks.toml` allowlist if you only need to suppress specific lines — that would allow any secret in that file.

## When this comes up
Any time you hardcode a Firebase UID (or similar non-secret high-entropy identifier) in a committed file — e.g., storage.rules, Firestore rules, config files.
