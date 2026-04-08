#!/usr/bin/env bash
# Phase 3+4: Provision Azure resources and deploy LiteLLM proxy.
# Requires: Azure CLI (logged in), credentials exported via setup-auth.sh.

set -euo pipefail
source "$(dirname "$0")/_common.sh"
load_config

log_info "=== Azure Deployment ==="
echo ""

# --- Prerequisites ---
require_cmd az "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
require_cmd jq "brew install jq / apt install jq / choco install jq"
require_az_login

EXPORT_DIR="${REPO_ROOT}/.auth-export"
EXTRACT_DIR="${REPO_ROOT}/.auth-extracted"

if [[ ! -f "${EXPORT_DIR}/litellm_auth.tar.gz" ]]; then
    log_error "No exported credentials found at ${EXPORT_DIR}/litellm_auth.tar.gz"
    log_error "Run ./scripts/setup-auth.sh first."
    exit 1
fi

load_or_generate_api_key

echo ""
log_info "Deployment settings:"
echo "  Resource Group:       $RESOURCE_GROUP"
echo "  Location:             $LOCATION"
echo "  Container App:        $CONTAINER_APP_NAME"
echo "  Environment:          $CONTAINER_APP_ENV"
echo "  Storage Account:      $STORAGE_ACCOUNT_NAME"
echo "  LiteLLM Image:        $LITELLM_IMAGE"
echo "  API Key:              ${LITELLM_API_KEY:0:6}..."
echo ""

if ! confirm "Proceed with deployment?"; then
    log_info "Aborted."
    exit 0
fi

# ============================================================
# Phase 3: Azure Resources
# ============================================================

# 3.1 — Ensure Azure extensions
log_info "Ensuring Azure CLI extensions..."
az extension add --name containerapp --upgrade --yes 2>/dev/null || true
az provider register --namespace Microsoft.App --wait 2>/dev/null || true
az provider register --namespace Microsoft.OperationalInsights --wait 2>/dev/null || true

# 3.2 — Resource Group
log_info "Creating resource group '$RESOURCE_GROUP'..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none
log_ok "Resource group ready."

# 3.3 — Container Apps Environment
log_info "Creating Container Apps environment '$CONTAINER_APP_ENV'..."
az containerapp env create \
    --name "$CONTAINER_APP_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none 2>/dev/null || log_warn "Environment may already exist, continuing..."
log_ok "Environment ready."

# 3.4 — Storage Account + File Share
log_info "Creating storage account '$STORAGE_ACCOUNT_NAME'..."
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --output none 2>/dev/null || log_warn "Storage account may already exist, continuing..."

STORAGE_KEY=$(get_storage_key)

log_info "Creating file share '$FILE_SHARE_NAME'..."
az storage share create \
    --name "$FILE_SHARE_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --output none 2>/dev/null || true
log_ok "Storage ready."

# 3.5 — Upload auth credentials
log_info "Uploading authentication credentials..."
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar xzf "${EXPORT_DIR}/litellm_auth.tar.gz" -C "$EXTRACT_DIR"

az storage file upload-batch \
    --destination "$FILE_SHARE_NAME" \
    --source "$EXTRACT_DIR" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --output none
log_ok "Credentials uploaded."

# 3.6 — Upload config files
log_info "Uploading LiteLLM configuration..."
az storage directory create \
    --share-name "$FILE_SHARE_NAME" \
    --name "app-config" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --output none 2>/dev/null || true

az storage file upload \
    --share-name "$FILE_SHARE_NAME" \
    --source "${REPO_ROOT}/litellm_config.yaml" \
    --path "app-config/config.yaml" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --output none
log_ok "Configuration uploaded."

# 3.7 — Mount storage to environment
log_info "Mounting storage to Container Apps environment..."
az containerapp env storage set \
    --name "$CONTAINER_APP_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --storage-name "litellmconfig" \
    --azure-file-account-name "$STORAGE_ACCOUNT_NAME" \
    --azure-file-account-key "$STORAGE_KEY" \
    --azure-file-share-name "$FILE_SHARE_NAME" \
    --access-mode ReadWrite \
    --output none
log_ok "Storage mounted."

# ============================================================
# Phase 4: Deploy Container App
# ============================================================

log_info "Deploying Container App '$CONTAINER_APP_NAME'..."
az containerapp create \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINER_APP_ENV" \
    --image "$LITELLM_IMAGE" \
    --target-port "$LITELLM_PORT" \
    --ingress external \
    --transport http \
    --min-replicas 1 \
    --max-replicas 1 \
    --cpu "$CONTAINER_CPU" \
    --memory "$CONTAINER_MEMORY" \
    --env-vars \
        "LITELLM_MASTER_KEY=$LITELLM_API_KEY" \
        "PYTHONPATH=/app" \
    --command "sh" \
    --args "-c" "litellm --config /mnt/config/app-config/config.yaml --host 0.0.0.0 --port $LITELLM_PORT" \
    --output none 2>/dev/null || log_warn "Container App may already exist, updating..."

# 4.2 — Add volume mounts via YAML
log_info "Configuring volume mounts..."
TEMP_YAML=$(mktemp)

az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --output yaml > "$TEMP_YAML"

# Use Python to patch the YAML (available in most environments with az cli)
python3 - "$TEMP_YAML" <<'PYEOF'
import sys, yaml

with open(sys.argv[1], 'r') as f:
    app = yaml.safe_load(f)

template = app.setdefault('properties', {}).setdefault('template', {})

# Set volumes
template['volumes'] = [{
    'name': 'litellm-storage',
    'storageName': 'litellmconfig',
    'storageType': 'AzureFile',
}]

# Set volume mounts on first container
containers = template.setdefault('containers', [{}])
containers[0]['volumeMounts'] = [
    {'volumeName': 'litellm-storage', 'mountPath': '/mnt/config'},
    {'volumeName': 'litellm-storage', 'subPath': '', 'mountPath': '/root/.config'},
]

with open(sys.argv[1], 'w') as f:
    yaml.dump(app, f, default_flow_style=False)
PYEOF

az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --yaml "$TEMP_YAML" \
    --output none

rm -f "$TEMP_YAML"
log_ok "Volume mounts configured."

# Clean up extracted auth files
rm -rf "$EXTRACT_DIR"

# ============================================================
# Verify
# ============================================================

APP_URL=$(get_app_url)
echo ""
log_ok "=== Deployment Complete ==="
echo ""
echo "  Proxy URL:  https://${APP_URL}"
echo "  API Key:    ${LITELLM_API_KEY}"
echo "  Key file:   ${REPO_ROOT}/.litellm_api_key"
echo ""
log_info "Waiting 30s for container to start..."
sleep 30

log_info "Testing health endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${APP_URL}/health" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
    log_ok "Proxy is healthy!"
elif [[ "$HTTP_CODE" == "000" ]]; then
    log_warn "Could not reach proxy yet. It may still be starting. Run: ./scripts/status.sh"
else
    log_warn "Health check returned HTTP $HTTP_CODE. Run: ./scripts/status.sh"
fi

echo ""
log_info "Next step: run ./scripts/configure-client.sh to get client setup instructions."
