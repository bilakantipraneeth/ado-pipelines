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

# Track tools installed by this script
INSTALLED_TOOLS=""
INSTALL_BASE="$HOME/.local"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S')] $*"; }

has_cmd() { 
    command -v "$1" &> /dev/null || command -v "$1.exe" &> /dev/null; 
}

ensure_dependencies() {
    export CLOUDSDK_CORE_DISABLE_PROMPTS=1

    # Detect a writable and executable directory (Handling noexec partitions)
    INSTALL_BASE="$HOME/.local"
    local test_script_name=".exec_test_$(date +%s).sh"
    local possible_dirs=("$HOME/.local" "$HOME" "/tmp" "/var/tmp")
    local found_dir=""

    for dir in "${possible_dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || continue
        local ts="$dir/$test_script_name"
        echo "#!/bin/sh" > "$ts" 2>/dev/null && chmod +x "$ts" 2>/dev/null
        if "$ts" >/dev/null 2>&1; then
            found_dir="$dir"
            rm -f "$ts" 2>/dev/null
            break
        fi
        rm -f "$ts" 2>/dev/null
    done

    if [[ -n "$found_dir" ]]; then
        INSTALL_BASE="$found_dir"
        [[ "$found_dir" != "$HOME/.local" ]] && log "Warning: $HOME is restricted. Using $found_dir for installations."
    else
        log "FATAL: No writable and executable directory found for dependencies."
        exit 1
    fi

    mkdir -p "${INSTALL_BASE}/bin"
    export PATH="${INSTALL_BASE}/bin:${INSTALL_BASE}/google-cloud-sdk/bin:$PATH"

    local primary_tools=("aws" "docker" "gcloud")
    for tool in "${primary_tools[@]}"; do
        if ! has_cmd "${tool}"; then
            log "Tool '${tool}' missing. Attempting non-interactive user-level installation..."
            case "${tool}" in
                "aws")
                    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    python3 -m zipfile -e awscliv2.zip "${INSTALL_BASE}"
                    find "${INSTALL_BASE}/aws" -type f -exec chmod +x {} +
                    "${INSTALL_BASE}/aws/install" -i "${INSTALL_BASE}/aws-cli" -b "${INSTALL_BASE}/bin" --update
                    rm -rf "${INSTALL_BASE}/aws" awscliv2.zip ;;
                "gcloud")
                    if [ ! -d "${INSTALL_BASE}/google-cloud-sdk" ]; then
                        curl -s https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="${INSTALL_BASE}" > /dev/null 2>&1
                    fi ;;
                "docker")
                    # Download the full Docker static suite (includes dockerd)
                    local DOCKER_VER="27.3.1"
                    curl -sL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VER}.tgz" -o "docker.tgz"
                    tar -xzf docker.tgz --strip-components=1 -C "${INSTALL_BASE}/bin"
                    rm "docker.tgz"

                    # Download Rootless Extras (Crucial for non-root daemon)
                    curl -sL "https://download.docker.com/linux/static/stable/x86_64/docker-rootless-extras-${DOCKER_VER}.tgz" -o "rootless.tgz"
                    tar -xzf rootless.tgz --strip-components=1 -C "${INSTALL_BASE}/bin"
                    rm "rootless.tgz"
                    
                    chmod +x "${INSTALL_BASE}/bin/"*

                    # Try to start the daemon if still not reachable
                    if ! docker info >/dev/null 2>&1; then
                        start_local_daemon
                    fi
                    ;;
            esac
            INSTALLED_TOOLS="${INSTALLED_TOOLS} ${tool}"
            log "'${tool}' successfully installed."
        fi
    done

    # If Docker daemon is not running, try to start it
    if ! docker info >/dev/null 2>&1; then
        start_local_daemon
    fi

    # Final Check: Docker Daemon Connectivity
    check_docker_daemon
}

start_local_daemon() {
    log "Attempting to start a local Docker daemon (Rootless)..."
    
    # Check for system dependencies for Rootless Docker
    if ! has_cmd "newuidmap"; then
        log "WARNING: 'newuidmap' not found. It is required for Rootless Docker."
        if sudo -n true 2>/dev/null; then
            log "Attempting to install 'uidmap' via sudo..."
            export DEBIAN_FRONTEND=noninteractive
            sudo apt-get update -qq && sudo apt-get install -y -qq uidmap
        else
            log "ERROR: Cannot install 'uidmap' (no sudo access). Rootless Docker will fail."
            return 1
        fi
    fi

    if ! has_cmd "dockerd-rootless.sh"; then
        log "Downloading Docker Rootless Extras..."
        local DOCKER_VER="27.3.1"
        curl -sL "https://download.docker.com/linux/static/stable/x86_64/docker-rootless-extras-${DOCKER_VER}.tgz" -o "rootless.tgz"
        tar -xzf "rootless.tgz" --strip-components=1 -C "${INSTALL_BASE}/bin"
        rm "rootless.tgz"
        chmod +x "${INSTALL_BASE}/bin/"*
    fi
    
    # Set up runtime directory for rootless
    export XDG_RUNTIME_DIR="${INSTALL_BASE}/docker-run"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    # Start dockerd-rootless in the background
    nohup "${INSTALL_BASE}/bin/dockerd-rootless.sh" \
        --data-root "${INSTALL_BASE}/docker-data" \
        > "${INSTALL_BASE}/docker.log" 2>&1 &
    
    local pid=$!
    log "Daeman process started (PID: $pid). Waiting for socket at ${XDG_RUNTIME_DIR}/docker.sock..."

    # Wait for the socket
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
    
    for i in {1..30}; do
        if docker info >/dev/null 2>&1; then
            log "SUCCESS: Local Rootless Docker daemon is running!"
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            log "ERROR: Daemon process died early."
            break
        fi
        sleep 2
    done

    log "WARNING: Local daemon failed to start. See ${INSTALL_BASE}/docker.log"
    return 1
}

check_docker_daemon() {
    log "Checking Docker daemon connectivity..."
    if docker info >/dev/null 2>&1; then
        log "Docker daemon is healthy and reachable."
        return 0
    fi

    log "FATAL: Docker daemon is NOT reachable."
    if [[ -S /var/run/docker.sock ]]; then
        if [[ ! -w /var/run/docker.sock ]]; then
            log "REASON: Current user needs write access to the docker socket."
            log "TIP: Try 'sudo chmod 666 /var/run/docker.sock' or adding user to 'docker' group."
        fi
    else
        log "REASON: Docker socket not found. The Docker Service (daemon) is likely not running."
    fi
    exit 1
}

test_docker_flow() {
    local target=$1
    log "[TEST] Starting Docker Flow Test (nginx -> GCP)..."
    log "[TEST] Pulling nginx:latest..."
    docker pull nginx:latest
    
    local test_target="${target%/*}/nginx:latest"
    log "[TEST] Tagging nginx as ${test_target}..."
    docker tag nginx:latest "${test_target}"
    
    log "[TEST] Pushing to GCP (verifying CLI connectivity)..."
    if docker push "${test_target}" 2>&1 | grep -q "Repository not found\|denied\|Permission"; then
        log "[TEST] SUCCESS: Docker CLI correctly reached GCP and verified authentication."
    else
        log "[TEST] SUCCESS: Push completed."
    fi
}

configure_aws() {
    local ak=$1 sk=$2
    log "Configuring AWS CLI..."
    aws configure set aws_access_key_id "$ak"
    aws configure set aws_secret_access_key "$sk"
    aws configure set region "$ECR_REGION"
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
    echo "$pass" | docker login --username AWS --password-stdin "${ECR_URL}" &> /dev/null
}

mirror_image() {
    local gcp_target=$1
    log "Mirroring: [AWS] -> [GCP]"
    docker pull "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" > /dev/null
    docker tag "${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}" "${gcp_target}"
    docker push "${gcp_target}" > /dev/null
}

cleanup() {
    log "Cleaning up session artifacts and tools..."
    if [ -d "$HOME/.aws" ]; then rm -rf "$HOME/.aws" 2>/dev/null; fi
    
    log "Removing installations from ${INSTALL_BASE}..."
    if [[ $INSTALLED_TOOLS == *"aws"* ]]; then rm -rf "${INSTALL_BASE}/aws-cli" "${INSTALL_BASE}/bin/aws" 2>/dev/null; fi
    if [[ $INSTALLED_TOOLS == *"gcloud"* ]]; then rm -rf "${INSTALL_BASE}/google-cloud-sdk" 2>/dev/null; fi
    if [[ $INSTALLED_TOOLS == *"docker"* ]]; then rm -f "${INSTALL_BASE}/bin/docker" 2>/dev/null; fi
}

main() {
    local artifact_id="${1:-}"
    [[ -z "${artifact_id}" ]] && { echo "Usage: $0 <artifact-path>"; exit 1; }
    trap cleanup EXIT

    local gcp_host=""
    local gcp_target=""

    # Detect input format
    if [[ "${artifact_id}" == projects/* ]]; then
        # Format: projects/{project}/locations/{location}/repositories/{repo}
        local gcp_project=$(echo "${artifact_id}" | cut -d'/' -f2)
        local gcp_location=$(echo "${artifact_id}" | cut -d'/' -f4)
        local gcp_repo=$(echo "${artifact_id}" | cut -d'/' -f6)
        gcp_host="${gcp_location}-docker.pkg.dev"
        gcp_target="${gcp_host}/${gcp_project}/${gcp_repo}/${IMAGE_NAME}:${IMAGE_TAG}"
    else
        # Format: {region}-docker.pkg.dev/{project}/{repo}
        gcp_host=$(echo "${artifact_id}" | cut -d'/' -f1)
        gcp_target="${artifact_id}/${IMAGE_NAME}:${IMAGE_TAG}"
    fi

    log "Target GCP Host: $gcp_host"
    log "Target Image Path: $gcp_target"

    local ak=$(echo "${AWS_ACCESS_KEY_ID:-}" | tr -d '[:space:]')
    local sk=$(echo "${AWS_SECRET_ACCESS_KEY:-}" | tr -d '[:space:]')
    [[ -z "${ak}" || -z "${sk}" ]] && { log "Fatal: AWS credentials missing."; exit 1; }

    ensure_dependencies
    
    # Configure Auth BEFORE testing
    log "Configuring GCP Docker Auth..."
    gcloud auth configure-docker "${gcp_host}" --quiet > /dev/null 2>&1

    # --- TEMP TEST BLOCK ---
    test_docker_flow "$gcp_target"
    # --- END TEMP TEST BLOCK ---

    configure_aws "$ak" "$sk"
    # authenticate_registries is now partly redundant for GCP, but keeps AWS login logic
    authenticate_registries "$gcp_host" 
    mirror_image "$gcp_target"

    log "Operation complete."
}

main "$@"