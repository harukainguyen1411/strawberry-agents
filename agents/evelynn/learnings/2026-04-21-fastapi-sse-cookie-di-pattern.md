# FastAPI SSE endpoints must use Cookie DI, not direct require_session calls

**Date:** 2026-04-21
**Session:** 0cf7b28e (S65)

## Lesson

In FastAPI, SSE endpoints (and any streaming endpoint) must inject cookie dependencies via FastAPI's Dependency Injection system, not by calling `await require_session(request)` directly. Direct calls bypass FastAPI's Cookie extraction — the cookie value is never parsed, and auth silently fails.

The correct pattern:
```python
async def session_logs_sse(
    session_id: str,
    session: Session = Depends(require_session),  # FastAPI injects cookie
):
    ...
```

Not:
```python
async def session_logs_sse(request: Request, session_id: str):
    session = await require_session(request)  # WRONG — cookie injection never fires
```

## Application

Senna's critical finding C1 on PR #61. Talon's hotfix commit `3995de5`. Applies to any FastAPI SSE/streaming endpoint that requires cookie-based session auth. Review all SSE endpoints in demo-studio (S1) for this pattern on the next audit pass.
