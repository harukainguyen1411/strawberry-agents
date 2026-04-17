---
name: firebase-admin-sdk
description: Firebase Admin SDK patterns for Firestore MCP tools
type: project
---

## Firestore MCP tool patterns

- **Lazy init**: Initialize Firebase Admin SDK only on first tool call (`_apps` check before `initialize_app`)
- **Composite indexes**: Queries with `updatedBy ==` AND `updatedAt >` (different fields, mixed equality/range) require a composite index in `firestore.indexes.json`. Deploy with `firebase deploy --only firestore:indexes`.
- **Existence check**: `doc_ref.get()` then check `snap.exists` before `update()` — otherwise `NotFound` exception
- **SERVER_TIMESTAMP**: Use `from google.cloud import firestore as _fs; _fs.SERVER_TIMESTAMP` for server-side timestamps
- **FieldFilter import**: `from google.cloud.firestore_v1 import FieldFilter` for `.where(filter=FieldFilter(...))` syntax
- **Timestamps in results**: Firestore timestamps have `.isoformat()` — convert before returning from tools
