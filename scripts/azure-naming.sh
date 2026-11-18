#!/usr/bin/env bash
# Shared Azure naming for ClaimTouch export-html-pdf.
# Naming: ct-cta-<env>-htmlpdf-<regionShort>
#
# Usage:
#   source scripts/azure-naming.sh
#   set_htmlpdf_naming <env> [location]
#
# Sets: ENV, LOCATION, REGION_SHORT, RESOURCE_GROUP_NAME, CONTAINER_APP_NAME,
#       CONTAINER_APP_ENV_NAME

ORG="ct"
SYSTEM="cta"
DEFAULT_LOCATION="eastus"

region_to_short() {
  case "$1" in
    eastus)          echo "eus" ;;
    eastus2)         echo "eus2" ;;
    westus)          echo "wus" ;;
    westus2)         echo "wus2" ;;
    westeurope)      echo "weu" ;;
    northeurope)     echo "neu" ;;
    uksouth)         echo "uks" ;;
    ukwest)          echo "ukw" ;;
    *)               echo "$1" | tr -d -c 'a-z0-9' | head -c 4 ;;
  esac
}

normalize_htmlpdf_env() {
  case "$1" in
    production|prod) echo "prod" ;;
    stage)           echo "stage" ;;
    qa)              echo "qa" ;;
    dev)             echo "dev" ;;
    test)            echo "test" ;;
    *)               echo "$1" ;;
  esac
}

set_htmlpdf_naming() {
  local raw_env="$1"
  local location="${2:-${DEFAULT_LOCATION}}"

  ENV="$(normalize_htmlpdf_env "$raw_env")"
  LOCATION="$location"
  REGION_SHORT="$(region_to_short "$LOCATION")"

  case "$ENV" in
    prod)
      RESOURCE_GROUP_NAME="ct-cta-prod-rg-${REGION_SHORT}"
      CONTAINER_APP_ENV_NAME="ct-cta-prod-cae-${REGION_SHORT}"
      CONTAINER_APP_NAME="ct-cta-prod-htmlpdf-${REGION_SHORT}"
      ;;
    stage)
      RESOURCE_GROUP_NAME="claimtouch-stage"
      CONTAINER_APP_ENV_NAME="ct-cta-stage-cae-${REGION_SHORT}"
      CONTAINER_APP_NAME="ct-cta-stage-htmlpdf-${REGION_SHORT}"
      ;;
    qa)
      RESOURCE_GROUP_NAME="ct-claims-${ENV}-rg-${REGION_SHORT}"
      CONTAINER_APP_ENV_NAME="ct-claims-${ENV}-cae-${REGION_SHORT}"
      CONTAINER_APP_NAME="${ORG}-${SYSTEM}-${ENV}-htmlpdf-${REGION_SHORT}"
      ;;
    *)
      RESOURCE_GROUP_NAME="${ORG}-${SYSTEM}-${ENV}-rg-${REGION_SHORT}"
      CONTAINER_APP_ENV_NAME="${ORG}-${SYSTEM}-${ENV}-cae-${REGION_SHORT}"
      CONTAINER_APP_NAME="${ORG}-${SYSTEM}-${ENV}-htmlpdf-${REGION_SHORT}"
      ;;
  esac
}
