#!/usr/bin/env bash
# google-oauth-bootstrap.sh — one-time OAuth dance to mint a refresh token
# for the plan-gdoc-mirror scripts.
#
# Run this ONCE on a machine that has a browser (typically Mac), then transfer
# the resulting refresh token into the encrypted secrets blob.
#
# Prerequisites:
#   1. A Google Cloud project with the Google Drive API enabled.
#   2. An OAuth 2.0 Client of type "Desktop app" (or "Web application" with
#      http://localhost as a redirect URI).
#   3. The downloaded client JSON saved at one of:
#        - secrets/google-oauth-client.json (gitignored)
#        - or pass the path as the first argument
#
# Output:
#   - Prints the refresh token to stdout (and only the refresh token).
#   - Caller is responsible for piping it into the encrypted secrets blob.
#
# We never echo the refresh token to logs and never write it to a temp file.
# Standard output is the only sink, by design — caller pipes elsewhere.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CLIENT_JSON="${1:-$REPO_ROOT/secrets/google-oauth-client.json}"
[ -f "$CLIENT_JSON" ] || {
  echo "missing OAuth client JSON: $CLIENT_JSON" >&2
  echo "Download it from https://console.cloud.google.com/apis/credentials" >&2
  exit 1
}

for tool in curl jq python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 1; }
done

CLIENT_ID=$(jq -r '.installed.client_id // .web.client_id' "$CLIENT_JSON")
CLIENT_SECRET=$(jq -r '.installed.client_secret // .web.client_secret' "$CLIENT_JSON")
[ -n "$CLIENT_ID" ] && [ -n "$CLIENT_SECRET" ] || { echo "could not parse client id/secret from $CLIENT_JSON" >&2; exit 1; }

SCOPE="https://www.googleapis.com/auth/drive.file"
PORT="${OAUTH_LOCAL_PORT:-8765}"
REDIRECT_URI="http://localhost:$PORT"

AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth?response_type=code&access_type=offline&prompt=consent&client_id=$CLIENT_ID&redirect_uri=$REDIRECT_URI&scope=$SCOPE"

cat >&2 <<EOF
================================================================
Google OAuth bootstrap for plan-gdoc-mirror.

A local listener will start on port $PORT.

Open this URL in a browser (it will pop automatically on Mac):

  $AUTH_URL

Approve the consent screen. Google will redirect back to localhost
and this script will capture the auth code.
================================================================
EOF

# Try to open the URL natively.
if command -v open >/dev/null 2>&1; then
  open "$AUTH_URL" || true
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$AUTH_URL" || true
fi

# Spin up a one-shot Python listener that captures `?code=...` and prints it.
CODE=$(python3 - "$PORT" <<'PY'
import http.server, socketserver, sys, urllib.parse
port = int(sys.argv[1])
captured = {}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a, **k): pass
    def do_GET(self):
        q = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(q)
        if 'code' in params:
            captured['code'] = params['code'][0]
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.end_headers()
            self.wfile.write(b'<h1>OK. You can close this tab.</h1>')
        else:
            self.send_response(400)
            self.end_headers()
with socketserver.TCPServer(('localhost', port), H) as srv:
    while 'code' not in captured:
        srv.handle_request()
print(captured['code'])
PY
)

[ -n "$CODE" ] || { echo "no auth code captured" >&2; exit 1; }

RESPONSE=$(curl -sS -X POST https://oauth2.googleapis.com/token \
  --data-urlencode "code=$CODE" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode "redirect_uri=$REDIRECT_URI" \
  --data-urlencode "grant_type=authorization_code")

REFRESH_TOKEN=$(jq -r '.refresh_token // empty' <<<"$RESPONSE")
if [ -z "$REFRESH_TOKEN" ]; then
  echo "token exchange failed: $(jq -c '.' <<<"$RESPONSE")" >&2
  exit 1
fi

cat >&2 <<EOF

================================================================
SUCCESS. The refresh token is on stdout.

Next steps:
  1. Encrypt this token and the other three credentials into individual
     age blobs under secrets/encrypted/:
       - secrets/encrypted/google-client-id.age
       - secrets/encrypted/google-client-secret.age
       - secrets/encrypted/google-refresh-token.age
       - secrets/encrypted/google-drive-plans-folder-id.age

  2. On the Windows agent box, decrypt each blob into its plaintext file:
       cat secrets/encrypted/google-refresh-token.age | \\
         tools/decrypt.sh --target secrets/google-refresh-token.env \\
                          --var GOOGLE_REFRESH_TOKEN
     (and likewise for the other three)

  3. Verify with:
       ./scripts/plan-publish.sh plans/proposed/<some-plan>.md
================================================================
EOF

printf '%s\n' "$REFRESH_TOKEN"
