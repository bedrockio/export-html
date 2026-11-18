#!/usr/bin/env bash
# Interactive Azure setup for ClaimTouch export-html-pdf (Container App only).
# Deploys into an existing resource group and Container App Environment from claimtouch/infra.
# Naming: ct-cta-<env>-htmlpdf-<regionShort>
#
# Prereqs: Azure CLI (az), logged in (az login), subscription set.
# The resource group and Container App Environment must already exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infra"

IMAGE_REPO="claimtouch/export-html-pdf"

# shellcheck source=azure-naming.sh
source "${SCRIPT_DIR}/azure-naming.sh"

ENV=""
LOCATION="${DEFAULT_LOCATION}"
RESOURCE_GROUP_NAME=""
CONTAINER_APP_ENV_NAME=""
CONTAINER_APP_NAME=""
CONTAINER_APP_ENVIRONMENT_ID=""
CONTAINER_APP_IMAGE=""
CONTAINER_APP_CPU="2"
CONTAINER_APP_MEMORY="4.0"
ACR_RESOURCE_GROUP_NAME="ct-cta-prod-rg-eus"
ACR_NAME="claimtouch"

DEFAULT_ENV_VARS=(
  NODE_ENV=production
  PORT=2305
)

set_naming_defaults() {
  set_htmlpdf_naming "$ENV" "$LOCATION"
}

image_tag_env() {
  case "$1" in
    prod) echo "production" ;;
    *) echo "$1" ;;
  esac
}

prompt_value() {
  local prompt="$1"
  local default="$2"
  local reply
  read -r -p "${prompt} [${default}]: " reply
  echo "${reply:-${default}}"
}

ensure_acr_image() {
  local image="$1"
  local server="${ACR_NAME}.azurecr.io"
  case "$image" in
    "${server}/"*)
      echo "$image"
      ;;
    *.azurecr.io/*|*.*/*)
      echo "$image"
      ;;
    *)
      echo "${server}/${image#/}"
      ;;
  esac
}

check_prereqs() {
  if ! command -v az &>/dev/null; then
    echo "Error: Azure CLI (az) is not installed or not in PATH."
    exit 1
  fi
  if ! az account show &>/dev/null; then
    echo "Error: Not logged in to Azure. Run 'az login'."
    exit 1
  fi
  echo "Using subscription: $(az account show --query name -o tsv)"
}

collect_environment() {
  echo ""
  echo "ClaimTouch export-html-pdf – add Container App to existing platform (claimtouch/infra)."
  local reply
  while true; do
    read -r -p "Environment (prod|stage|dev|qa|test) [stage]: " reply
    reply="${reply:-stage}"
    case "$reply" in
      prod|stage|dev|qa|test)
        ENV="$reply"
        break
        ;;
      *)
        echo "Please choose one of: prod, stage, dev, qa, test."
        ;;
    esac
  done
  LOCATION=$(prompt_value "Azure region (e.g. eastus, westeurope)" "${DEFAULT_LOCATION}")
  set_naming_defaults
  CONTAINER_APP_IMAGE="${ACR_NAME}.azurecr.io/${IMAGE_REPO}:latest-$(image_tag_env "$ENV")"
  echo ""
  echo "Derived names (env=${ENV}, region=${LOCATION}, short=${REGION_SHORT}):"
  echo "  Resource group:     ${RESOURCE_GROUP_NAME}"
  echo "  Container App Env:  ${CONTAINER_APP_ENV_NAME}"
  echo "  Container App:      ${CONTAINER_APP_NAME}"
  echo "  Image:              ${CONTAINER_APP_IMAGE}"
  echo ""
}

resolve_environment_id() {
  if ! az group show --name "${RESOURCE_GROUP_NAME}" &>/dev/null; then
    echo "Error: Resource group '${RESOURCE_GROUP_NAME}' does not exist."
    echo "Provision platform first: https://github.com/claimtouch/infra"
    exit 1
  fi
  CONTAINER_APP_ENVIRONMENT_ID=$(az containerapp env show \
    --name "${CONTAINER_APP_ENV_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query id -o tsv 2>/dev/null || true)
  if [[ -z "${CONTAINER_APP_ENVIRONMENT_ID}" ]]; then
    echo "Error: Container App Environment '${CONTAINER_APP_ENV_NAME}' not found in '${RESOURCE_GROUP_NAME}'."
    echo "Check naming or create the CAE via claimtouch/infra."
    exit 1
  fi
  echo "Resolved Container App Environment ID."
}

collect_app_config() {
  CONTAINER_APP_NAME=$(prompt_value "Container App name" "${CONTAINER_APP_NAME}")
  local image_input
  image_input=$(prompt_value "Container image (include ${ACR_NAME}.azurecr.io/...)" "${CONTAINER_APP_IMAGE}")
  CONTAINER_APP_IMAGE="$(ensure_acr_image "${image_input}")"
  if [[ "${CONTAINER_APP_IMAGE}" != "${image_input}" ]]; then
    echo "Normalized image to ACR-qualified ref: ${CONTAINER_APP_IMAGE}"
  fi
  CONTAINER_APP_CPU=$(prompt_value "Container CPU (e.g. 2)" "${CONTAINER_APP_CPU}")
  CONTAINER_APP_MEMORY=$(prompt_value "Container memory (Gi, e.g. 4.0)" "${CONTAINER_APP_MEMORY}")
  ACR_RESOURCE_GROUP_NAME=$(prompt_value "ACR resource group" "${ACR_RESOURCE_GROUP_NAME}")
}

build_deployment_params() {
  local params=(
    "containerAppEnvironmentId=${CONTAINER_APP_ENVIRONMENT_ID}"
    "containerAppName=${CONTAINER_APP_NAME}"
    "containerAppImage=${CONTAINER_APP_IMAGE}"
    "containerAppCpu=${CONTAINER_APP_CPU}"
    "containerAppMemory=${CONTAINER_APP_MEMORY}"
    "acrResourceGroupName=${ACR_RESOURCE_GROUP_NAME}"
    "acrName=${ACR_NAME}"
  )
  printf '%s\n' "${params[@]}"
}

run_deployment() {
  local param_args=()
  while IFS= read -r line; do
    param_args+=(--parameters "$line")
  done < <(build_deployment_params)

  echo "Deploying export-html-pdf Container App to resource group: ${RESOURCE_GROUP_NAME}..."
  az deployment group create \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --template-file "${INFRA_DIR}/main.bicep" \
    --name claimtouch-export-html-pdf-setup \
    "${param_args[@]}" \
    --output table

  echo "Deployment complete. Outputs:"
  az deployment group show \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name claimtouch-export-html-pdf-setup \
    --query properties.outputs \
    --output table 2>/dev/null || true

  echo "Setting default environment variables on ${CONTAINER_APP_NAME}..."
  az containerapp update \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${CONTAINER_APP_NAME}" \
    --set-env-vars "${DEFAULT_ENV_VARS[@]}" \
    --output none
}

main() {
  echo "=== ClaimTouch export-html-pdf – Azure setup (Bicep) ==="
  check_prereqs
  collect_environment
  resolve_environment_id
  collect_app_config

  echo ""
  echo "Summary:"
  echo "  Resource group:     ${RESOURCE_GROUP_NAME}"
  echo "  Container App:      ${CONTAINER_APP_NAME}"
  echo "  Image:              ${CONTAINER_APP_IMAGE}"
  echo "  ACR:                ${ACR_RESOURCE_GROUP_NAME} / ${ACR_NAME}"
  echo "  Default env vars:"
  local var
  for var in "${DEFAULT_ENV_VARS[@]}"; do
    echo "    ${var}"
  done
  echo ""
  read -r -p "Proceed with deployment? (y/N): " confirm
  confirm="${confirm:-n}"
  if [[ ! "$confirm" =~ ^[yY] ]]; then
    echo "Aborted."
    exit 0
  fi

  run_deployment

  echo ""
  echo "Next steps:"
  echo "  1. Push an image via the Deploy GitHub Actions workflow (or docker build/push)."
  echo "  2. Point API PDF_CONVERTER_ENDPOINT at https://<fqdn>/1/pdf"
  echo "  3. Platform/DR docs: https://github.com/claimtouch/infra"
}

main "$@"
