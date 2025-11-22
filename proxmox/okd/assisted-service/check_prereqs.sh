#!/bin/bash
set -euo pipefail

# Prerequisites Check Script for OKD Assisted Service Deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((ERRORS++))
}

echo "==================================="
echo "OKD Assisted Service Prerequisites"
echo "==================================="
echo

# Check for Podman
echo "Checking Podman installation..."
if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version | awk '{print $3}')
    REQUIRED_VERSION="3.3.0"
    
    # Simple version comparison (major.minor)
    PODMAN_MAJOR=$(echo "$PODMAN_VERSION" | cut -d. -f1)
    PODMAN_MINOR=$(echo "$PODMAN_VERSION" | cut -d. -f2)
    
    if [[ $PODMAN_MAJOR -gt 3 ]] || [[ $PODMAN_MAJOR -eq 3 && $PODMAN_MINOR -ge 3 ]]; then
        log_info "Podman $PODMAN_VERSION is installed (>= $REQUIRED_VERSION required)"
    else
        log_warn "Podman $PODMAN_VERSION is installed but version >= $REQUIRED_VERSION is recommended"
    fi
else
    log_error "Podman is not installed"
    echo "  Install: sudo dnf install podman (Fedora/RHEL)"
    echo "           sudo apt install podman (Ubuntu/Debian)"
fi

# Check for required ports
echo
echo "Checking required ports..."
for PORT in 8080 8090 8888 5432; do
    if ss -tuln | grep -q ":$PORT "; then
        log_warn "Port $PORT is already in use"
    else
        log_info "Port $PORT is available"
    fi
done

# Check system resources
echo
echo "Checking system resources..."

# Memory check (recommend at least 4GB free)
if command -v free &> /dev/null; then
    FREE_MEM=$(free -m | awk '/^Mem:/{print $7}')
    if [[ $FREE_MEM -gt 4096 ]]; then
        log_info "Available memory: ${FREE_MEM}MB (>4GB recommended)"
    elif [[ $FREE_MEM -gt 2048 ]]; then
        log_warn "Available memory: ${FREE_MEM}MB (4GB+ recommended for OKD deployment)"
    else
        log_error "Available memory: ${FREE_MEM}MB (insufficient, need at least 4GB)"
    fi
fi

# Disk space check
AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $AVAILABLE_SPACE -gt 50 ]]; then
    log_info "Available disk space: ${AVAILABLE_SPACE}GB (>50GB recommended)"
elif [[ $AVAILABLE_SPACE -gt 20 ]]; then
    log_warn "Available disk space: ${AVAILABLE_SPACE}GB (50GB+ recommended)"
else
    log_error "Available disk space: ${AVAILABLE_SPACE}GB (insufficient, need at least 20GB)"
fi

# Check for SELinux (if applicable)
echo
echo "Checking SELinux status..."
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
        log_info "SELinux is enforcing (podman supports this)"
    else
        log_info "SELinux is $SELINUX_STATUS"
    fi
else
    log_info "SELinux not detected (not required)"
fi

# Check network connectivity
echo
echo "Checking network connectivity..."
if curl -s --max-time 5 https://quay.io &> /dev/null; then
    log_info "Can reach quay.io (container registry)"
else
    log_error "Cannot reach quay.io - check network/firewall"
fi

if curl -s --max-time 5 https://registry.ci.openshift.org &> /dev/null; then
    log_info "Can reach registry.ci.openshift.org (OKD registry)"
else
    log_warn "Cannot reach registry.ci.openshift.org - may affect OKD deployment"
fi

if curl -s --max-time 5 https://builds.coreos.fedoraproject.org &> /dev/null; then
    log_info "Can reach builds.coreos.fedoraproject.org (Fedora CoreOS)"
else
    log_error "Cannot reach builds.coreos.fedoraproject.org - needed for FCOS images"
fi

# Check configuration files
echo
echo "Checking configuration files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/okd-configmap.yml" ]]; then
    log_info "okd-configmap.yml exists"
else
    log_error "okd-configmap.yml not found in $SCRIPT_DIR"
fi

if [[ -f "$SCRIPT_DIR/pod.yml" ]]; then
    log_info "pod.yml exists"
else
    log_error "pod.yml not found in $SCRIPT_DIR"
fi

# Summary
echo
echo "==================================="
echo "Prerequisites Check Summary"
echo "==================================="
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    log_info "All prerequisites met! Ready to deploy."
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo "You can proceed but review warnings above."
    exit 0
else
    echo -e "${RED}Errors: $ERRORS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo "Please resolve errors before deploying."
    exit 1
fi
