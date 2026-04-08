#!/usr/bin/env bash
# Re-authenticate GitHub OAuth and upload fresh credentials to Azure.
# Use when Layer 1 token expires (upstream 401/403 errors).

set -euo pipefail
source "$(dirname "$0")/_common.sh"
load_config

log_info "=== Re-Authentication ==="
echo ""

require_docker
require_cmd az "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
require_az_login

log_warn "This will:"
echo "  1. Remove the old Docker auth volume"
echo "  2. Run LiteLLM locally for fresh GitHub Device Flow auth"
echo "  3. Export and upload new credentials to Azure"
echo "  4. Restart the Container App"
echo ""

if ! confirm "Proceed?"; then
    log_info "Aborted."
    exit 0
fi

# Step 1: Remove old volume
log_info "Removing old Docker volume '${DOCKER_VOLUME_NAME}'..."
docker volume rm "$DOCKER_VOLUME_NAME" 2>/dev/null || true

# Step 2: Re-authenticate
log_info "Starting LiteLLM for GitHub authentication..."
log_info "Complete the Device Flow in your browser, then press Ctrl+C."
echo ""

docker run $DOCKER_IT_FLAG --rm \
    -p "${LITELLM_PORT}:${LITELLM_PORT}" \
    -v "${DOCKER_VOLUME_NAME}:/root/.config" \
    -v "${REPO_ROOT}/litellm_config.yaml:/app/config.yaml:ro" \
    "$LITELLM_IMAGE" \
    --config /app/config.yaml --host 0.0.0.0 --port "$LITELLM_PORT" || true

# Step 3: Export credentials
EXPORT_DIR="${REPO_ROOT}/.auth-export"
EXTRACT_DIR="${REPO_ROOT}/.auth-extracted"
rm -rf "$EXPORT_DIR" "$EXTRACT_DIR"
mkdir -p "$EXPORT_DIR" "$EXTRACT_DIR"

log_info "Exporting fresh credentials..."
docker run --rm \
    -v "${DOCKER_VOLUME_NAME}:/source:ro" \
    -v "${EXPORT_DIR}:/backup" \
    alpine tar czf /backup/litellm_auth.tar.gz -C /source .

tar xzf "${EXPORT_DIR}/litellm_auth.tar.gz" -C "$EXTRACT_DIR"

# Step 4: Upload to Azure
log_info "Uploading credentials to Azure File Share..."
STORAGE_KEY=$(get_storage_key)

az storage file upload-batch \
    --destination "$FILE_SHARE_NAME" \
    --source "$EXTRACT_DIR" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --overwrite \
    --output none
log_ok "Credentials uploaded."

# Step 5: Restart container
log_info "Restarting Container App..."
REVISION=$(az containerapp revision list \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" -o tsv)

az containerapp revision restart \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --revision "$REVISION" \
    --output none
log_ok "Container restarting."

# Clean up
rm -rf "$EXPORT_DIR" "$EXTRACT_DIR"

echo ""
log_info "Waiting 30s for container to start..."
sleep 30

# Verify
APP_URL=$(get_app_url)
load_or_generate_api_key

log_info "Testing proxy..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${APP_URL}/v1/models" \
    -H "Authorization: Bearer ${LITELLM_API_KEY}" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
    log_ok "Re-authentication successful! Proxy is working."
else
    log_warn "Proxy returned HTTP $HTTP_CODE. It may still be starting. Run: ./scripts/status.sh"
fi

echo ""
log_info "No client-side changes needed — proxy URL and API key are unchanged."
