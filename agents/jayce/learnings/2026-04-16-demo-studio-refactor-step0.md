# Demo Studio — Step 0 Kill Workers & API Scaffolding Learnings

## Duplicate `components` key in OpenAPI YAML is silently ignored

When a YAML file has two top-level `components:` keys, most parsers use only the first and silently drop the second. Tooling like Swagger UI and openapi-generator may show only the first block's schemas. Always ensure a single `components:` key — merge parameters and schemas into it before the `paths:` block.

## Verification service paths should NOT be versioned

Only Config Mgmt (Service 2) uses `/v1/` path prefixes. Verification (Service 4), Factory (Service 3), and Preview (Service 5) use unversioned paths (`/verify`, `/build`, `/preview/{id}`). When scaffolding stubs, match the spec path in both the YAML spec and the FastAPI route decorator.

## MCP server `updateSession` must be imported if `set_config` tool needs it

When adding a new tool that writes to Firestore, the `updateSession` import in `server.ts` must be explicitly added. The original server only imported `getSession`. Missing this causes a TypeScript compile error on first build.

## Task deduplication in multi-agent teams

When Jayce is both the coordinator assigning tasks AND the implementer executing them, task assignment messages from `jayce` to `jayce` will arrive after the work is already done. Acknowledge them briefly but do not re-do the work.

## OpenAPI tokenUi shape per PR #37

The `tokenUi` field in the Demo Studio config is an open-ended map of i18n text overrides, not a fixed-shape object with `consentPage`/`getPassPage` sub-objects. The correct schema is:
```yaml
tokenUi:
  type: object
  additionalProperties:
    $ref: "#/components/schemas/I18nText"
```

## IpadDemoStep required fields per PR #37

PR #37 schema adds `id` (required string), `nav` (optional object with `back`/`next`), `benefit` (optional I18nText), and `dualPhone` (optional boolean) to `IpadDemoStep`. `talkingPoints` is `string[]`, not `I18nText[]`.

## JourneyAction.linkUrl is required

Per PR #37 schema, `linkUrl` is required on every `JourneyAction` (not nullable). Omit `nullable: true` and include it in the `required` array.

## FastAPI module import check before declaring done

After scaffolding a new FastAPI service, always run `python -c "import main; print('OK')"` from the service directory to verify there are no import errors before reporting completion.
