#!/bin/bash
set -euo pipefail

# OKD Assisted Service Deployment Script
# This script deploys the OpenShift Assisted Installer service using Podman

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    log_error "Podman is not installed. Please install podman first."
    log_info "On Fedora/RHEL: sudo dnf install podman"
    log_info "On Ubuntu/Debian: sudo apt install podman"
    exit 1
fi

# Verify podman version (require 3.3+)
PODMAN_VERSION=$(podman --version | awk '{print $3}')
log_info "Detected Podman version: $PODMAN_VERSION"

# Check if pod is already running
if podman pod exists assisted-installer 2>/dev/null; then
    log_warn "Assisted installer pod already exists."
    read -p "Do you want to remove it and redeploy? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping and removing existing pod..."
        podman play kube --down pod.yml || true
        podman pod rm -f assisted-installer 2>/dev/null || true
    else
        log_info "Deployment cancelled."
        exit 0
    fi
fi

# Verify configuration files exist
if [[ ! -f "okd-configmap.yml" ]]; then
    log_error "okd-configmap.yml not found in $SCRIPT_DIR"
    exit 1
fi

if [[ ! -f "pod.yml" ]]; then
    log_error "pod.yml not found in $SCRIPT_DIR"
    exit 1
fi

# Display configuration
log_info "Deployment Configuration:"
echo "  - Service URL: $(grep SERVICE_BASE_URL okd-configmap.yml | awk '{print $2}')"
echo "  - Image Service URL: $(grep IMAGE_SERVICE_BASE_URL okd-configmap.yml | awk '{print $2}')"
echo "  - UI URL: http://$(hostname -I | awk '{print $1}'):8080"

# Deploy the pod
log_info "Deploying assisted installer pod..."
log_warn "Note: This requires root privileges for network configuration"
if sudo podman play kube --configmap okd-configmap.yml pod.yml; then
    log_info "✓ Assisted installer pod deployed successfully!"
    echo
    log_info "Service endpoints:"
    echo "  - UI:            http://$(hostname -I | awk '{print $1}'):8080"
    echo "  - API:           http://$(hostname -I | awk '{print $1}'):8090"
    echo "  - Image Service: http://$(hostname -I | awk '{print $1}'):8888"
    echo
    log_info "To check pod status: podman pod ps"
    log_info "To check container logs: podman logs <container-name>"
    log_info "To stop the pod: podman play kube --down pod.yml"
    echo
    log_warn "Note: It may take a few minutes for all services to become ready."
    log_info "Monitor with: podman pod logs assisted-installer"
else
    log_error "Failed to deploy assisted installer pod"
    exit 1
fi
