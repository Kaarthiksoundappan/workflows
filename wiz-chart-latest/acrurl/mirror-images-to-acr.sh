#!/bin/bash
# Script to mirror Wiz Kubernetes Integration images to Azure Container Registry
# Version: 1.1 for wiz-kubernetes-integration v0.2.142
#
# Usage:
#   1. Configure ACR credentials below
#   2. Make executable: chmod +x mirror-images-to-acr.sh
#   3. Run: ./mirror-images-to-acr.sh
#
# ACR Authentication Methods:
#   Method 1 (Recommended): Docker login with username/password
#     - Get credentials: az acr credential show -n <acr-name>
#     - Or enable admin: az acr update -n <acr-name> --admin-enabled true
#     - Set ACR_USERNAME and ACR_PASSWORD below
#
#   Method 2: Azure CLI (may not work with recent Azure CLI versions)
#     - Set ACR_USE_AZ_LOGIN=true
#     - Run: az login && az acr login --name <acr-name>
#

set -e  # Exit on error

# ==============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# ==============================================================================

# Your Azure Container Registry name (without .azurecr.io)
ACR_NAME="your-acr-name"

# ACR authentication credentials
# Method 1: Username + Password/Token (recommended for recent Azure CLI versions)
ACR_USERNAME=""           # Service principal or admin username
ACR_PASSWORD=""           # Password or refresh token

# Method 2: Auto-fetch token using Azure CLI (requires 'az login')
# If ACR_USERNAME and ACR_PASSWORD are empty, script will attempt to use 'az acr login'
ACR_USE_AZ_LOGIN=false    # Set to true to use 'az acr login' (may not work in recent versions)

# Wiz sensor registry credentials (obtain from Wiz support)
# These are required to pull from wizio.azurecr.io (private registry)
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

  # Check if docker is installed
  if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Install from: https://docs.docker.com/get-docker/"
    exit 1
  fi
  print_info "Docker: Installed"

  # Validate ACR name
  if [ "$ACR_NAME" = "your-acr-name" ]; then
    print_error "Please update ACR_NAME in the script configuration"
    exit 1
  fi
  print_info "ACR Name: $ACR_NAME"

  # Check authentication method
  if [ "$ACR_USE_AZ_LOGIN" = true ]; then
    # Check if az CLI is installed and logged in
    if ! command -v az &> /dev/null; then
      print_error "Azure CLI (az) is not installed. Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
      exit 1
    fi
    print_info "Azure CLI: Installed"

    if ! az account show &> /dev/null; then
      print_error "Not logged in to Azure. Run: az login"
      exit 1
    fi
    print_success "Azure CLI: Logged in"
    print_info "ACR Auth Method: az acr login"
  else
    # Using docker login with credentials
    if [ -z "$ACR_USERNAME" ] || [ -z "$ACR_PASSWORD" ]; then
      print_error "ACR_USERNAME and ACR_PASSWORD must be set in configuration"
      print_error "Or set ACR_USE_AZ_LOGIN=true to use Azure CLI authentication"
      print_info ""
      print_info "To get ACR credentials:"
      print_info "  1. Enable admin user: az acr update -n $ACR_NAME --admin-enabled true"
      print_info "  2. Get credentials: az acr credential show -n $ACR_NAME"
      print_info "  Or use service principal credentials"
      exit 1
    fi
    print_info "ACR Auth Method: docker login (username/password)"
  fi

  echo ""
}

login_to_registries() {
  print_header "Logging into Container Registries"

  # Login to ACR
  print_info "Logging into ACR: $ACR_NAME.azurecr.io"

  if [ "$ACR_USE_AZ_LOGIN" = true ]; then
    # Use Azure CLI method (may not work in recent versions)
    if az acr login --name "$ACR_NAME" 2>&1; then
      print_success "Logged into ACR via Azure CLI"
    else
      print_error "az acr login failed. Consider using docker login method instead."
      print_info "Set ACR_USE_AZ_LOGIN=false and provide ACR_USERNAME and ACR_PASSWORD"
      exit 1
    fi
  else
    # Use docker login with credentials (works with recent Azure CLI)
    print_info "Using docker login with provided credentials"
    echo "$ACR_PASSWORD" | docker login "${ACR_NAME}.azurecr.io" \
      --username "$ACR_USERNAME" \
      --password-stdin

    if [ $? -eq 0 ]; then
      print_success "Logged into ACR via docker login"
    else
      print_error "docker login to ACR failed. Check your credentials."
      exit 1
    fi
  fi

  # Login to Wiz private registry if credentials provided
  if [ -n "$WIZ_SENSOR_USERNAME" ] && [ -n "$WIZ_SENSOR_PASSWORD" ]; then
    print_info "Logging into Wiz private registry: wizio.azurecr.io"
    echo "$WIZ_SENSOR_PASSWORD" | docker login wizio.azurecr.io \
      --username "$WIZ_SENSOR_USERNAME" \
      --password-stdin
    print_success "Logged into Wiz private registry"
  else
    print_warning "Wiz sensor credentials not provided. Private images will be skipped."
    print_warning "Obtain credentials from Wiz support to mirror sensor images."
  fi

  echo ""
}

import_image_via_acr() {
  local name=$1
  local source=$2
  local target="${ACR_NAME}.azurecr.io/${TARGET_PREFIX}/${name}"

  print_info "Importing: $source -> $target"

  if az acr import \
    --name "$ACR_NAME" \
    --source "$source" \
    --image "${TARGET_PREFIX}/${name}" \
    --force \
    2>&1; then
    print_success "Imported: $name"
    return 0
  else
    print_error "Failed to import: $name"
    return 1
  fi
}

mirror_image_via_docker() {
  local name=$1
  local source=$2
  local target="${ACR_NAME}.azurecr.io/${TARGET_PREFIX}/${name}"

  print_info "Mirroring via Docker: $source"

  # Pull source image
  if ! docker pull "$source"; then
    print_error "Failed to pull: $source"
    return 1
  fi

  # Tag for target registry
  docker tag "$source" "$target"

  # Push to ACR
  if docker push "$target"; then
    print_success "Pushed: $target"

    # Clean up local images
    docker rmi "$source" "$target" 2>/dev/null || true
    return 0
  else
    print_error "Failed to push: $target"
    return 1
  fi
}

mirror_public_images() {
  print_header "Mirroring Public Images"

  local success_count=0
  local fail_count=0

  for name in "${!PUBLIC_IMAGES[@]}"; do
    local source="${PUBLIC_IMAGES[$name]}"

    # Try ACR import first (faster and doesn't require local Docker)
    if import_image_via_acr "$name" "$source"; then
      ((success_count++))
    else
      print_warning "ACR import failed, trying Docker method..."
      if mirror_image_via_docker "$name" "$source"; then
        ((success_count++))
      else
        ((fail_count++))
      fi
    fi
    echo ""
  done

  print_info "Public images: $success_count succeeded, $fail_count failed"
  echo ""
}

mirror_private_images() {
  print_header "Mirroring Private Images (Requires Wiz Credentials)"

  if [ -z "$WIZ_SENSOR_USERNAME" ] || [ -z "$WIZ_SENSOR_PASSWORD" ]; then
    print_warning "Skipping private images - credentials not provided"
    print_info "To mirror sensor images:"
    print_info "  1. Contact Wiz support for wizio.azurecr.io credentials"
    print_info "  2. Update WIZ_SENSOR_USERNAME and WIZ_SENSOR_PASSWORD in this script"
    print_info "  3. Re-run the script"
    return
  fi

  local success_count=0
  local fail_count=0

  for name in "${!PRIVATE_IMAGES[@]}"; do
    local source="${PRIVATE_IMAGES[$name]}"

    # Private images must use Docker method (ACR import doesn't support auth)
    if mirror_image_via_docker "$name" "$source"; then
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
  print_header "Wiz Images to ACR Migration Script"
  print_info "Target ACR: ${ACR_NAME}.azurecr.io"
  print_info "Target Prefix: ${TARGET_PREFIX}"

  # Run checks and migrations
  check_prerequisites
  login_to_registries
  mirror_public_images
  mirror_private_images
  verify_images
  print_next_steps

  print_header "Migration Complete!"
  print_success "All available images have been mirrored to your ACR"
}

# Run main function
main "$@"
