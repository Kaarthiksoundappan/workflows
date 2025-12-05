#!/bin/bash
# Script to mirror Wiz Kubernetes Integration images to Azure Container Registry
# Version: 2.0 for wiz-kubernetes-integration v0.2.142
#
# Usage:
#   1. Login to Azure: az login
#   2. Configure ACR name below
#   3. Make executable: chmod +x mirror-images-to-acr.sh
#   4. Run: ./mirror-images-to-acr.sh
#
# This script uses 'az acr import' to mirror images directly between registries
# without requiring Docker daemon. This is faster and more reliable.
#
# Requirements:
#   - Azure CLI installed and logged in
#   - Appropriate permissions on target ACR (AcrPush role or Owner)
#   - For private Wiz images: Credentials from Wiz support
#

set -e  # Exit on error

# ==============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# ==============================================================================

# Your Azure Container Registry name (without .azurecr.io)
ACR_NAME="your-acr-name"

# Wiz private registry credentials (obtain from Wiz support)
# Required for importing private sensor images from wizio.azurecr.io
# Leave empty to skip private images
WIZ_SENSOR_USERNAME=""
WIZ_SENSOR_PASSWORD=""

# Target registry prefix in your ACR
TARGET_PREFIX="wiz"

# ==============================================================================
# IMAGE DEFINITIONS
# ==============================================================================

# Public images (no authentication required)
declare -A PUBLIC_IMAGES=(
  # Admission Controller
  ["wiz-admission-controller"]="wiziopublic.azurecr.io/wiz-app/wiz-admission-controller:2.11"

  # Kubernetes Connector
  ["wiz-kubernetes-connector"]="wiziopublic.azurecr.io/wiz-app/wiz-kubernetes-connector:3.0"

  # Wiz Broker (part of connector)
  ["wiz-broker"]="wiziopublic.azurecr.io/wiz-app/wiz-broker:latest"
)

# Private images (require Wiz credentials)
declare -A PRIVATE_IMAGES=(
  # Wiz Sensor (requires authentication)
  ["sensor"]="wizio.azurecr.io/sensor:v1"

  # Wiz Workload Scanner (for disk scanning feature)
  ["wiz-workload-scanner"]="wizio.azurecr.io/wiz-app/wiz-workload-scanner:v1"
)

# ==============================================================================
# FUNCTIONS
# ==============================================================================

print_header() {
  echo ""
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

print_info() {
  echo "[INFO] $1"
}

print_success() {
  echo "[SUCCESS] $1"
}

print_error() {
  echo "[ERROR] $1" >&2
}

print_warning() {
  echo "[WARNING] $1"
}

check_prerequisites() {
  print_header "Checking Prerequisites"

  # Check if az CLI is installed
  if ! command -v az &> /dev/null; then
    print_error "Azure CLI (az) is not installed. Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
  fi
  print_info "Azure CLI: Installed"

  # Check Azure login
  if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Run: az login"
    exit 1
  fi
  print_success "Azure CLI: Logged in"

  # Validate ACR name
  if [ "$ACR_NAME" = "your-acr-name" ]; then
    print_error "Please update ACR_NAME in the script configuration"
    exit 1
  fi
  print_info "ACR Name: $ACR_NAME"

  # Check ACR exists and we have access
  print_info "Verifying ACR access..."
  if ! az acr show --name "$ACR_NAME" &> /dev/null; then
    print_error "Cannot access ACR '$ACR_NAME'. Check name and permissions."
    exit 1
  fi
  print_success "ACR access verified"

  echo ""
}

check_wiz_credentials() {
  print_header "Checking Wiz Credentials"

  # Check if Wiz credentials are provided for private images
  if [ -n "$WIZ_SENSOR_USERNAME" ] && [ -n "$WIZ_SENSOR_PASSWORD" ]; then
    print_success "Wiz sensor credentials provided"
    print_info "Private images (sensor, workload-scanner) will be imported"
  else
    print_warning "Wiz sensor credentials not provided"
    print_warning "Private images will be skipped"
    print_info "To import sensor images:"
    print_info "  1. Contact Wiz support for wizio.azurecr.io credentials"
    print_info "  2. Set WIZ_SENSOR_USERNAME and WIZ_SENSOR_PASSWORD in this script"
  fi

  echo ""
}

import_image_via_acr() {
  local name=$1
  local source=$2
  local is_private=$3  # true/false indicating if source is private
  local target="${ACR_NAME}.azurecr.io/${TARGET_PREFIX}/${name}"

  print_info "Importing: $source"
  print_info "Target: $target"

  # Build az acr import command
  local import_cmd="az acr import --name $ACR_NAME --source $source --image ${TARGET_PREFIX}/${name} --force"

  # Add credentials if importing from private registry
  if [ "$is_private" = "true" ] && [ -n "$WIZ_SENSOR_USERNAME" ] && [ -n "$WIZ_SENSOR_PASSWORD" ]; then
    import_cmd="$import_cmd --username $WIZ_SENSOR_USERNAME --password $WIZ_SENSOR_PASSWORD"
    print_info "Using Wiz credentials for private image"
  fi

  # Execute import
  if eval $import_cmd 2>&1; then
    print_success "Imported: $name"
    return 0
  else
    print_error "Failed to import: $name"
    return 1
  fi
}

mirror_public_images() {
  print_header "Importing Public Images"

  local success_count=0
  local fail_count=0

  for name in "${!PUBLIC_IMAGES[@]}"; do
    local source="${PUBLIC_IMAGES[$name]}"

    # Import using az acr import (no Docker required)
    if import_image_via_acr "$name" "$source" "false"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
    echo ""
  done

  print_info "Public images: $success_count succeeded, $fail_count failed"
  echo ""
}

mirror_private_images() {
  print_header "Importing Private Images (Requires Wiz Credentials)"

  if [ -z "$WIZ_SENSOR_USERNAME" ] || [ -z "$WIZ_SENSOR_PASSWORD" ]; then
    print_warning "Skipping private images - credentials not provided"
    print_info "To import sensor images:"
    print_info "  1. Contact Wiz support for wizio.azurecr.io credentials"
    print_info "  2. Update WIZ_SENSOR_USERNAME and WIZ_SENSOR_PASSWORD in this script"
    print_info "  3. Re-run the script"
    return
  fi

  local success_count=0
  local fail_count=0

  for name in "${!PRIVATE_IMAGES[@]}"; do
    local source="${PRIVATE_IMAGES[$name]}"

    # Import with Wiz credentials
    if import_image_via_acr "$name" "$source" "true"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
    echo ""
  done

  print_info "Private images: $success_count succeeded, $fail_count failed"
  echo ""
}

verify_images() {
  print_header "Verifying Images in ACR"

  print_info "Listing images in ${ACR_NAME}.azurecr.io/${TARGET_PREFIX}:"
  az acr repository list \
    --name "$ACR_NAME" \
    --output table \
    | grep "^${TARGET_PREFIX}/" || print_warning "No images found with prefix: ${TARGET_PREFIX}/"

  echo ""
  print_info "Detailed image tags:"
  for name in "${!PUBLIC_IMAGES[@]}"; do
    echo "  - ${TARGET_PREFIX}/${name}:"
    az acr repository show-tags \
      --name "$ACR_NAME" \
      --repository "${TARGET_PREFIX}/${name}" \
      --output table 2>/dev/null || echo "    (not found)"
  done

  if [ -n "$WIZ_SENSOR_USERNAME" ]; then
    for name in "${!PRIVATE_IMAGES[@]}"; do
      echo "  - ${TARGET_PREFIX}/${name}:"
      az acr repository show-tags \
        --name "$ACR_NAME" \
        --repository "${TARGET_PREFIX}/${name}" \
        --output table 2>/dev/null || echo "    (not found)"
    done
  fi

  echo ""
}

print_next_steps() {
  print_header "Next Steps"

  echo "1. Push Helm chart to ACR:"
  echo "   helm push wiz-kubernetes-integration-0.2.142.tgz oci://${ACR_NAME}.azurecr.io/helm"
  echo ""
  echo "2. Create ACR credentials secret:"
  echo "   kubectl create secret docker-registry acr-credentials \\"
  echo "     --docker-server=${ACR_NAME}.azurecr.io \\"
  echo "     --docker-username=<acr-username> \\"
  echo "     --docker-password=<acr-password> \\"
  echo "     --namespace=wiz"
  echo ""
  echo "3. Update helmrelease.yaml placeholders:"
  echo "   - Replace 'your-acr-name' with '${ACR_NAME}'"
  echo ""
  echo "4. Deploy via Flux/GitOps"
  echo ""
  echo "Image URLs in your ACR:"
  for name in "${!PUBLIC_IMAGES[@]}"; do
    echo "  - ${ACR_NAME}.azurecr.io/${TARGET_PREFIX}/${name}"
  done
  if [ -n "$WIZ_SENSOR_USERNAME" ]; then
    for name in "${!PRIVATE_IMAGES[@]}"; do
      echo "  - ${ACR_NAME}.azurecr.io/${TARGET_PREFIX}/${name}"
    done
  fi
  echo ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  print_header "Wiz Images to ACR Import Script (No Docker Required)"
  print_info "Target ACR: ${ACR_NAME}.azurecr.io"
  print_info "Target Prefix: ${TARGET_PREFIX}"
  print_info "Method: az acr import (Azure CLI)"

  # Run checks and migrations
  check_prerequisites
  check_wiz_credentials
  mirror_public_images
  mirror_private_images
  verify_images
  print_next_steps

  print_header "Import Complete!"
  print_success "All available images have been imported to your ACR"
}

# Run main function
main "$@"
