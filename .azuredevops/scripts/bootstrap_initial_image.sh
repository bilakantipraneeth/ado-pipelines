#!/bin/bash
#
# bootstrap_initial_image.sh

set -euo pipefail

# --- Constants ---
# These specific values are required by the LiveRamp integration docs.
ECR_REGISTRY="461694764112.dkr.ecr.eu-central-1.amazonaws.com"
ECR_REGION="eu-central-1"
IMAGE_NAME="vault-app"
IMAGE_TAG="latest"

# --- Helper Functions ---

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

run_as_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        if command -v sudo &> /dev/null; then
            sudo "$@"
        else
            log "Error: Action requires root privileges, but 'sudo' is not installed."
            exit 1
        fi
    fi
}

ensure_prerequisites() {
    local missing=0
    for cmd in curl unzip; do
        if ! command -v "$cmd" &> /dev/null; then
            log "Error: Prerequisite '$cmd' is not installed."
            missing=1
        fi
    done

    if [ "$missing" -eq 1 ]; then
        log "Critical: Missing basic prerequisites (curl, unzip). Cannot proceed with auto-installation."
        exit 1
    fi
}

install_aws_cli() {
    log "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" > /dev/null 2>&1
    unzip -q awscliv2.zip
    run_as_root ./aws/install
    rm -rf aws awscliv2.zip
    log "AWS CLI installed successfully."
}

install_docker() {
    log "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null 2>&1
    run_as_root sh get-docker.sh
    log "Docker installed successfully."
}

ensure_dependencies() {
    log "Checking dependencies..."

    if ! command -v aws &> /dev/null; then
        log "AWS CLI not found. Attempting installation..."
        install_aws_cli
    else
        log "AWS CLI is present."
    fi

    if ! command -v docker &> /dev/null; then
        log "Docker not found. Attempting installation..."
        install_docker
    else
        log "Docker is present."
    fi

    if ! command -v gcloud &> /dev/null; then
        log "Error: 'gcloud' is not installed. Please install the Google Cloud SDK."

        exit 1
    fi
}

usage() {
    echo "Usage: $0 <artifact-id>"
    echo "  <artifact-id>: The full GCP Artifact Registry path (e.g., projects/P/locations/L/repositories/R)"
    exit 1
}

# --- Main Logic ---

main() {
    # 1. Preparation
    ensure_prerequisites
    ensure_dependencies

    # 2. Argument Parsing
    if [ "$#" -ne 1 ]; then
        usage
    fi
    local artifact_id="$1"

    if [ -z "$artifact_id" ]; then
        log "Error: Artifact ID is empty."
        usage
    fi



    local project_id
    project_id=$(echo "$artifact_id" | cut -d'/' -f2)
    local location
    location=$(echo "$artifact_id" | cut -d'/' -f4)
    local repo_id
    repo_id=$(echo "$artifact_id" | cut -d'/' -f6)

    # Construct GCP Artifact Registry URL
    local gcp_repo_url="$location-docker.pkg.dev/$project_id/$repo_id"
    local gcp_repo_host
    gcp_repo_host=$(echo "$gcp_repo_url" | cut -d'/' -f1)


    log "Authenticating to GCP Artifact Registry: $gcp_repo_host..."
    gcloud auth configure-docker "$gcp_repo_host" --quiet

    log "Authenticating to AWS ECR..."
    aws ecr get-login-password --region "$ECR_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"


    local source_image="$ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    local target_image="$gcp_repo_url/$IMAGE_NAME:$IMAGE_TAG"

    log "Pulling image: $source_image..."
    docker pull "$source_image"

    log "Tagging image: $target_image..."
    docker tag "$source_image" "$target_image"

    log "Pushing image to GCP..."
    docker push "$target_image"

    log "Operation completed successfully."
}

# Run Main
main "$@"