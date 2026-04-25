# architecture/apps — app-domain knowledge

This subtree holds documentation about **application-domain concerns**: deploy targets,
hosting configuration, infrastructure, and storage setup.

It explicitly does NOT cover agent-network architecture. A reader investigating how the
agent system routes dispatches, manages memory, or enforces invariants should look at
`architecture/agent-network-v1/` instead.

## Contents

| File | Covers |
|---|---|
| `deployment.md` | Firebase deploy flow for `strawberry-app` `[placeholder — lands W1]` |
| `firebase-storage-cors.md` | Firebase Storage CORS configuration `[placeholder — lands W1]` |
| `infrastructure.md` | VPS (Hetzner CX22), PM2 processes, SSH setup `[placeholder — lands W2]` |

## Drift tolerance

Files here are app-domain knowledge and subject to looser drift tolerance than
`agent-network-v1/`. They are not pinned by the `canonical-v1.md` lock manifest.
