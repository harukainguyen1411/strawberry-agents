# GET-then-PUT pre-interceptors: common pitfalls

When a pre-interceptor does a GET then builds a PUT body:

1. **READ_ONLY_FIELDS list is fragile** — must be validated against the actual PUT endpoint schema. Any unrecognized field causes a 400. Defensive approach: catch the PUT error and re-surface with context.
2. **Step-level error context** — wrap GET and PUT calls separately so callers know which step failed.
3. **String validation** — use `.trim() === ""` not `=== ""` when validating URL/string inputs.
4. **Document auto-stripping in tool descriptions** — if a pre-interceptor strips fields, the tool description should mention it so agents aren't confused when fields they sent don't appear to take effect.
