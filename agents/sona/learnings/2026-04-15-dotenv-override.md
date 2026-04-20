# load_dotenv must use override=True

**Date:** 2026-04-15
**Context:** Demo Studio v3 backend returning Firestore 403 despite correct .env

**Problem:** `load_dotenv()` does NOT override existing shell environment variables. If a previous process or agent exports `FIRESTORE_PROJECT_ID=old-value`, all subsequent processes inherit it, and `load_dotenv()` silently keeps the stale value.

**Symptom:** Direct Python scripts worked fine (no shell env), but uvicorn subprocesses inherited the stale `FIRESTORE_PROJECT_ID=ds-v3-workspace-2026` from the parent shell.

**Fix:** Use `load_dotenv(override=True)` so .env always wins over shell environment.

**Lesson:** Always use `override=True` with load_dotenv in services that may be started from shells with exported env vars (which includes Claude Code agent subprocesses).
