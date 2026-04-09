#!/bin/sh
set -e

TOKEN_DIR="/root/.config/litellm/github_copilot"
TOKEN_FILE="${TOKEN_DIR}/access-token"

# If GITHUB_COPILOT_TOKEN env var is set and no token file exists, inject it
if [ -n "$GITHUB_COPILOT_TOKEN" ] && [ ! -f "$TOKEN_FILE" ]; then
    echo "[entrypoint] Injecting GITHUB_COPILOT_TOKEN from environment variable..."
    mkdir -p "$TOKEN_DIR"
    printf '%s' "$GITHUB_COPILOT_TOKEN" > "$TOKEN_FILE"
fi

# Mode switch: token exists and valid → LiteLLM proxy, otherwise → Auth Wizard
if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
    echo "[entrypoint] Token found. Validating with GitHub Copilot API..."

    MAX_RETRIES=3
    RETRY=0
    HTTP_STATUS="000"

    while [ "$RETRY" -lt "$MAX_RETRIES" ]; do
        RETRY=$((RETRY + 1))
        # Use Python httpx (available in litellm image) instead of curl
        HTTP_STATUS=$(TOKEN_FILE="$TOKEN_FILE" python3 -c "
import os, httpx
try:
    token = open(os.environ['TOKEN_FILE']).read().strip()
    r = httpx.get('https://api.github.com/copilot_internal/v2/token',
        headers={
            'Authorization': 'token ' + token,
            'Accept': 'application/json',
            'Editor-Version': 'vscode/1.85.1',
            'Editor-Plugin-Version': 'copilot/1.155.0',
            'User-Agent': 'GithubCopilot/1.155.0',
        }, timeout=10)
    print(r.status_code)
except Exception:
    print('000')
" 2>/dev/null || echo "000")

        if [ "$HTTP_STATUS" = "200" ]; then
            break
        fi

        # Definitive auth failure — no point retrying
        if [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "403" ]; then
            echo "[entrypoint] Token rejected by API (HTTP $HTTP_STATUS). No retry."
            break
        fi

        # Network error — retry with backoff
        DELAY=$((RETRY * 3))
        echo "[entrypoint] Validation attempt $RETRY/$MAX_RETRIES failed (HTTP $HTTP_STATUS). Retrying in ${DELAY}s..."
        sleep "$DELAY"
    done

    if [ "$HTTP_STATUS" = "200" ]; then
        echo "[entrypoint] Token is valid. Starting LiteLLM proxy..."
        exec litellm --config /app/config.yaml --host 0.0.0.0 --port 4000
    elif [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "403" ]; then
        echo "[entrypoint] Token is invalid or expired (HTTP $HTTP_STATUS). Removing stale credentials..."
        rm -f "$TOKEN_FILE" "${TOKEN_DIR}/api-key.json"
        echo "[entrypoint] Starting Auth Wizard for re-authentication..."
        exec python /app/railway/auth_wizard.py
    else
        echo "[entrypoint] Could not reach GitHub API after $MAX_RETRIES attempts (HTTP $HTTP_STATUS)."
        echo "[entrypoint] Starting LiteLLM proxy with existing token (will refresh at runtime)..."
        exec litellm --config /app/config.yaml --host 0.0.0.0 --port 4000
    fi
else
    echo "[entrypoint] No token found. Starting Auth Wizard..."
    exec python /app/railway/auth_wizard.py
fi
