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
    TOKEN=$(cat "$TOKEN_FILE")
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token ${TOKEN}" \
        -H "Accept: application/json" \
        -H "Editor-Version: vscode/1.85.1" \
        -H "Editor-Plugin-Version: copilot/1.155.0" \
        -H "User-Agent: GithubCopilot/1.155.0" \
        "https://api.github.com/copilot_internal/v2/token" 2>/dev/null || echo "000")

    if [ "$HTTP_STATUS" = "200" ]; then
        echo "[entrypoint] Token is valid. Starting LiteLLM proxy..."
        exec litellm --config /app/config.yaml --host 0.0.0.0 --port 4000
    else
        echo "[entrypoint] Token is invalid or expired (HTTP $HTTP_STATUS). Removing stale credentials..."
        rm -f "$TOKEN_FILE" "${TOKEN_DIR}/api-key.json"
        echo "[entrypoint] Starting Auth Wizard for re-authentication..."
        exec python /app/railway/auth_wizard.py
    fi
else
    echo "[entrypoint] No token found. Starting Auth Wizard..."
    exec python /app/railway/auth_wizard.py
fi
