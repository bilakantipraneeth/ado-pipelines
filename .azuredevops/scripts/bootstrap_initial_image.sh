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

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S')] $*"; }

has_cmd() { 
    command -v "$1" &> /dev/null || command -v "$1.exe" &> /dev/null; 
}

ensure_dependencies() {
    if [[ ! -w "$HOME" ]]; then
        log "FATAL: No write access to $HOME. Installation not possible."
        exit 1
    fi

    export PATH="$HOME/.local/bin:$PATH"

    local primary_tools=("aws" "docker" "gcloud")
    for tool in "${primary_tools[@]}"; do
        if ! has_cmd "${tool}"; then
            log "Tool '${tool}' missing. Attempting installation..."
            mkdir -p "$HOME/.local/bin"

            case "${tool}" in
                "aws")
                    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -q awscliv2.zip
                    ./aws/install -i "$HOME/.local/aws-cli" -b "$HOME/.local/bin" --update
                    rm -rf aws awscliv2.zip ;;
                "gcloud")
                    curl -s https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME/.local" > /dev/null 2>&1
                    export PATH="$PATH:$HOME/.local/google-cloud-sdk/bin" ;;
                "docker")
                    log "FATAL: Docker missing. Machine must have Docker service pre-installed."
                    exit 1 ;;
            esac
            log "'${tool}' successfully installed."
        fi
    done
}

configure_aws() {
    local ak=$1
    local sk=$2
    log "Configuring AWS CLI..."
    
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    unset AWS_SECURITY_TOKEN

    aws configure set aws_access_key_id "$ak"
    aws configure set aws_secret_access_key "$sk"
    aws configure set region "$ECR_REGION"
    aws configure set output json
}

authenticate_registries() {
    local gcp_host=$1
    log "Authenticating registries..."
    gcloud auth configure-docker "${gcp_host}" --quiet > /dev/null 2>&1

    local pass
    if ! pass=$(aws ecr get-login-password --region "${ECR_REGION}" 2>&1); then
        log "Fatal: AWS Auth failed. Error: $pass"
        exit 1
    fi

    if ! echo "$pass" | docker login --username AWS --password-stdin "${ECR_URL}" &> /dev/null; then
        log "Fatal: Docker login to AWS failed."
        exit 1
    fi
}

mirror_image() {
    local gcp_target=$1
    log "Mirroring: [AWS] -> [GCP]"
    docker pull "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" > /dev/null
    docker tag "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" "${gcp_target}"
    docker push "${gcp_target}" > /dev/null
}

cleanup() {
    log "Cleaning up session artifacts..."
    if has_cmd "docker"; then
        docker rmi "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    fi

    if [ -d "$HOME/.aws" ]; then
        rm -rf "$HOME/.aws/credentials" "$HOME/.aws/config" 2>/dev/null || true
    fi
}

main() {
    local artifact_id="${1:-}"
    [[ -z "${artifact_id}" ]] && { echo "Usage: $0 <artifact-path>"; exit 1; }

    trap cleanup EXIT

    local gcp_project=$(echo "${artifact_id}" | cut -d'/' -f2)
    local gcp_location=$(echo "${artifact_id}" | cut -d'/' -f4)
    local gcp_repo=$(echo "${artifact_id}" | cut -d'/' -f6)
    local gcp_host="${gcp_location}-docker.pkg.dev"
    local gcp_target="${gcp_host}/${gcp_project}/${gcp_repo}/${IMAGE_NAME}:${IMAGE_TAG}"

    local ak=$(echo "${AWS_ACCESS_KEY_ID:-}" | tr -d '[:space:]')
    local sk=$(echo "${AWS_SECRET_ACCESS_KEY:-}" | tr -d '[:space:]')
    [[ -z "${ak}" || -z "${sk}" ]] && { log "Fatal: AWS credentials missing."; exit 1; }

    ensure_dependencies
    configure_aws "$ak" "$sk"
    authenticate_registries "$gcp_host"
    mirror_image "$gcp_target"

    log "Operation complete."
}

main "$@"