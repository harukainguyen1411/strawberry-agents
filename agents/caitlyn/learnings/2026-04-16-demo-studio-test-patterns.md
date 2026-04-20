---
name: Demo Studio v3 test patterns
description: Key patterns and conventions for the demo-studio-v3 test suite
type: reference
---

- conftest.py stubs google.cloud.firestore and anthropic; provides sample_session, mock_get_session, async client fixtures
- Most test files duplicate their own _session_data/_make_session helpers with slightly different defaults instead of using conftest
- Frontend tests read static/studio.js as raw text and assert on string presence (not DOM parsing)
- Backend tests use httpx AsyncClient with ASGITransport against the FastAPI app
- Auth tests use _cookie_header helper (create_session_cookie) and generate_csrf_token
- Run command: `set -a && source .env && source .agent-ids.env && set +a && python -m pytest <file> -v`
- Markers: @pytest.mark.session, @pytest.mark.ui, @pytest.mark.auth, @pytest.mark.chat, @pytest.mark.factory_v2, @pytest.mark.preview, @pytest.mark.dashboard
