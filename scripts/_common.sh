#!/usr/bin/env bash
# Shared helper functions for CopilotLiteLLM scripts

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- Config loading ----------
load_config() {
    local config_file="${REPO_ROOT}/config.env"
    if [[ ! -f "$config_file" ]]; then
        log_error "config.env not found. Copy config.env.example to config.env and customize it."
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$config_file"
}

# ---------- Prerequisite checks ----------
require_cmd() {
    local cmd="$1"
    local install_hint="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "'$cmd' is not installed."
        [[ -n "$install_hint" ]] && log_error "Install: $install_hint"
        exit 1
    fi
}

require_az_login() {
    if ! az account show &>/dev/null; then
        log_error "Not logged in to Azure CLI. Run: az login"
        exit 1
    fi
}

require_docker() {
    require_cmd docker "https://www.docker.com/products/docker-desktop/"
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running. Start Docker Desktop."
        exit 1
    fi
}

# ---------- Azure helpers ----------
get_storage_key() {
    az storage account keys list \
        --resource-group "$RESOURCE_GROUP" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --query '[0].value' -o tsv
}

get_app_url() {
    az containerapp show \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.configuration.ingress.fqdn" -o tsv
}

# ---------- API key management ----------
load_or_generate_api_key() {
    local key_file="${REPO_ROOT}/.litellm_api_key"
    if [[ -n "${LITELLM_API_KEY:-}" ]]; then
        return
    fi
    if [[ -f "$key_file" ]]; then
        LITELLM_API_KEY="$(cat "$key_file")"
        log_info "Loaded API key from .litellm_api_key"
    else
        LITELLM_API_KEY="sk-$(openssl rand -hex 16)"
        echo "$LITELLM_API_KEY" > "$key_file"
        chmod 600 "$key_file"
        log_ok "Generated new API key → .litellm_api_key"
    fi
    export LITELLM_API_KEY
}

# ---------- Windows / Git Bash compatibility ----------
# Git Bash on Windows mangles Unix paths (e.g. /source → C:/Program Files/Git/source).
# Export MSYS_NO_PATHCONV=1 to prevent this for docker commands.
export MSYS_NO_PATHCONV=1

# Detect if we have a TTY for docker -it
DOCKER_IT_FLAG="-i"
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_IT_FLAG="-it"
fi

# ---------- Confirmation prompt ----------
confirm() {
    local msg="${1:-Continue?}"
    echo -en "${YELLOW}${msg} [y/N] ${NC}"
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]]
}
