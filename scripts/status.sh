#!/usr/bin/env bash
# Check proxy health, container status, and diagnose common issues.
#
# Usage:
#   ./scripts/status.sh          — quick health check
#   ./scripts/status.sh logs     — show recent container logs
#   ./scripts/status.sh test     — send a test completion request

set -euo pipefail
source "$(dirname "$0")/_common.sh"
load_config

require_cmd az "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
require_cmd curl
require_az_login

ACTION="${1:-health}"

load_or_generate_api_key

APP_URL=$(get_app_url 2>/dev/null || true)

if [[ -z "$APP_URL" ]]; then
    log_error "Container App '$CONTAINER_APP_NAME' not found."
    log_error "Has it been deployed? Run ./scripts/deploy-azure.sh"
    exit 1
fi

PROXY_URL="https://${APP_URL}"

case "$ACTION" in
    health)
        log_info "=== Proxy Status ==="
        echo "  URL: ${PROXY_URL}"
        echo ""

        # Container status
        log_info "Container status:"
        az containerapp show \
            --name "$CONTAINER_APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --query "{status: properties.runningStatus, revision: properties.latestRevisionName, fqdn: properties.configuration.ingress.fqdn}" \
            -o table 2>/dev/null || log_warn "Could not fetch container status."
        echo ""

        # Health endpoint
        log_info "Health check..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${PROXY_URL}/health" 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "200" ]]; then
            log_ok "Health endpoint: OK (HTTP 200)"
        elif [[ "$HTTP_CODE" == "000" ]]; then
            log_error "Health endpoint: UNREACHABLE"
        else
            log_warn "Health endpoint: HTTP $HTTP_CODE"
        fi

        # Model listing
        log_info "Model listing..."
        MODELS_RESPONSE=$(curl -s "${PROXY_URL}/v1/models" \
            -H "Authorization: Bearer ${LITELLM_API_KEY}" 2>/dev/null || echo "")

        if [[ -n "$MODELS_RESPONSE" ]] && echo "$MODELS_RESPONSE" | jq -e '.data' &>/dev/null; then
            MODEL_COUNT=$(echo "$MODELS_RESPONSE" | jq '.data | length')
            log_ok "Models available: $MODEL_COUNT"
            echo "$MODELS_RESPONSE" | jq -r '.data[].id' | sed 's/^/    /'
        else
            log_warn "Could not list models. Token may be expired."
            log_warn "Check logs: ./scripts/status.sh logs"
        fi
        ;;

    logs)
        log_info "=== Recent Container Logs ==="
        az containerapp logs show \
            --name "$CONTAINER_APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --tail 100

        echo ""
        log_info "Scanning for errors..."
        ERROR_LINES=$(az containerapp logs show \
            --name "$CONTAINER_APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --tail 200 2>/dev/null | grep -iE "error|expired|401|403|failed|exception" || true)

        if [[ -n "$ERROR_LINES" ]]; then
            log_warn "Found potential issues:"
            echo "$ERROR_LINES" | head -20
        else
            log_ok "No obvious errors in recent logs."
        fi
        ;;

    test)
        log_info "=== Test Completion ==="
        log_info "Sending test request to ${PROXY_URL}..."
        echo ""

        RESPONSE=$(curl -s "${PROXY_URL}/v1/chat/completions" \
            -H "Authorization: Bearer ${LITELLM_API_KEY}" \
            -H "Content-Type: application/json" \
            -d '{
                "model": "claude-sonnet-4-5",
                "messages": [{"role": "user", "content": "Say hello in one word."}],
                "max_tokens": 10
            }' 2>/dev/null || echo '{"error": "Connection failed"}')

        if echo "$RESPONSE" | jq -e '.choices[0].message.content' &>/dev/null; then
            REPLY=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')
            MODEL=$(echo "$RESPONSE" | jq -r '.model')
            log_ok "Response from $MODEL: $REPLY"
        else
            log_error "Test failed:"
            echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
            echo ""
            log_info "If you see auth errors, run: ./scripts/reauth.sh"
        fi
        ;;

    *)
        echo "Usage: $0 {health|logs|test}"
        exit 1
        ;;
esac
