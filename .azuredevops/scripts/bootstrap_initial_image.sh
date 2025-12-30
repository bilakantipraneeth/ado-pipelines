#!/bin/bash
# Mirror images from AWS ECR to GCP Artifact Registry
# Usage: ./bootstrap_initial_image.sh <artifact-id>

set -euo pipefail

# --- Configuration ---
ECR_REGISTRY_ID="461694764112"
ECR_REGION="eu-central-1"
ECR_URL="${ECR_REGISTRY_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com"
IMAGE_NAME="vault-app"
IMAGE_TAG="latest"

# Logging helper
log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S')] $*"; }

# Robust command check
has_cmd() { 
    command -v "$1" &> /dev/null || command -v "$1.exe" &> /dev/null; 
}

# 1. Dependency Management
ensure_dependencies() {
    local primary_tools=("aws" "docker" "gcloud")
    for tool in "${primary_tools[@]}"; do
        if ! has_cmd "${tool}"; then
            log "Tool '${tool}' missing. Attempting recovery..."
            if ! has_cmd "curl" || ! has_cmd "unzip"; then
                log "Fatal: 'curl' and 'unzip' required for auto-install."
                exit 1
            fi
            case "${tool}" in
                "aws")
                    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -q awscliv2.zip && sudo ./aws/install --update
                    rm -rf aws awscliv2.zip ;;
                "gcloud")
                    curl -s https://sdk.cloud.google.com | bash -s -- --disable-prompts > /dev/null 2>&1
                    export PATH=$PATH:$HOME/google-cloud-sdk/bin ;;
                "docker")
                    curl -fsSL https://get.docker.com -o get-docker.sh
                    sudo sh get-docker.sh > /dev/null 2>&1
                    sudo systemctl start docker || true
                    rm get-docker.sh ;;
            esac
            log "'${tool}' installed."
        fi
    done
}

# 2. AWS Configuration
configure_aws() {
    local ak=$1
    local sk=$2
    log "Setting up AWS configuration files..."
    
    # Unset env vars so the CLI uses the config files
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    unset AWS_SECURITY_TOKEN

    aws configure set aws_access_key_id "$ak"
    aws configure set aws_secret_access_key "$sk"
    aws configure set region "$ECR_REGION"
    aws configure set output json
}

# 3. Registry Authentication
authenticate_registries() {
    local gcp_host=$1
    log "Authenticating with Google Cloud..."
    gcloud auth configure-docker "${gcp_host}" --quiet > /dev/null 2>&1

    log "Authenticating with AWS ECR..."
    local pass
    if ! pass=$(aws ecr get-login-password --region "${ECR_REGION}" 2>&1); then
        log "Fatal: AWS Auth failed. Error: $pass"
        exit 1
    fi

    if ! echo "$pass" | docker login --username AWS --password-stdin "${ECR_URL}" &> /dev/null; then
        log "Fatal: Docker login to AWS failed."
        exit 1
    fi
    log "Authentication successful."
}

# 4. Image Mirroring
mirror_image() {
    local gcp_target=$1
    log "Mirroring: [AWS] -> [GCP]"
    docker pull "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" > /dev/null
    docker tag "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" "${gcp_target}"
    docker push "${gcp_target}" > /dev/null
}

# 5. Cleanup Function
cleanup() {
    log "Executing cleanup sequence..."
    
    # Remove mirrored Docker images to save space
    if has_cmd "docker"; then
        log "Purging temporary images..."
        docker rmi "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    fi

    # Wipe transient AWS credentials
    if [ -d "$HOME/.aws" ]; then
        log "Clearing transient AWS credentials..."
        rm -rf "$HOME/.aws/credentials" "$HOME/.aws/config" 2>/dev/null || true
    fi
    
    log "Cleanup complete."
}

main() {
    local artifact_id="${1:-}"
    [[ -z "${artifact_id}" ]] && { echo "Usage: $0 <artifact-path>"; exit 1; }

    # Set trap for cleanup on exit (success or failure)
    trap cleanup EXIT

    # Extract Metadata
    local gcp_project=$(echo "${artifact_id}" | cut -d'/' -f2)
    local gcp_location=$(echo "${artifact_id}" | cut -d'/' -f4)
    local gcp_repo=$(echo "${artifact_id}" | cut -d'/' -f6)
    local gcp_host="${gcp_location}-docker.pkg.dev"
    local gcp_target="${gcp_host}/${gcp_project}/${gcp_repo}/${IMAGE_NAME}:${IMAGE_TAG}"

    # Sanitization
    local ak=$(echo "${AWS_ACCESS_KEY_ID:-}" | tr -d '[:space:]')
    local sk=$(echo "${AWS_SECRET_ACCESS_KEY:-}" | tr -d '[:space:]')
    [[ -z "${ak}" || -z "${sk}" ]] && { log "Fatal: AWS credentials missing."; exit 1; }

    # Pipeline Sequence
    ensure_dependencies
    configure_aws "$ak" "$sk"
    authenticate_registries "$gcp_host"
    mirror_image "$gcp_target"

    log "Bootstrap sequence complete."
}

main "$@"