#!/bin/bash
set -euo pipefail

# Create OKD Cluster via Assisted Service API
# This script creates a cluster configuration using the assisted-service REST API

API_URL="http://192.168.2.205:8090/api/assisted-install/v2"
CLUSTER_NAME="okd"
BASE_DOMAIN="thelab.lan"
OCP_VERSION="4.16.0-0.okd-scos-2024-11-16-051944"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Read SSH public key
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa.pub}"
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    log_error "SSH public key not found at $SSH_KEY_PATH"
    log_info "Generate one with: ssh-keygen -t rsa -b 4096"
    exit 1
fi

SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")
log_info "Using SSH key from: $SSH_KEY_PATH"

# Get pull secret (required format for API)
PULL_SECRET='{"auths":{"cloud.openshift.com":{"auth":"","email":""}}}'

log_info "Creating OKD cluster: $CLUSTER_NAME.$BASE_DOMAIN"

# Create cluster
CLUSTER_JSON=$(cat <<EOF
{
  "name": "$CLUSTER_NAME",
  "openshift_version": "$OCP_VERSION",
  "base_dns_domain": "$BASE_DOMAIN",
  "cpu_architecture": "x86_64",
  "high_availability_mode": "None",
  "pull_secret": "$PULL_SECRET",
  "ssh_public_key": "$SSH_PUBLIC_KEY",
  "vip_dhcp_allocation": false,
  "network_type": "OVNKubernetes",
  "cluster_networks": [
    {
      "cidr": "10.128.0.0/14",
      "host_prefix": 23
    }
  ],
  "service_networks": [
    {
      "cidr": "172.30.0.0/16"
    }
  ],
  "machine_networks": [
    {
      "cidr": "192.168.2.0/24"
    }
  ]
}
EOF
)

log_info "Creating cluster via API..."
RESPONSE=$(curl -s -X POST "$API_URL/clusters" \
  -H "Content-Type: application/json" \
  -d "$CLUSTER_JSON")

CLUSTER_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -z "$CLUSTER_ID" ]]; then
    log_error "Failed to create cluster"
    echo "API Response: $RESPONSE"
    exit 1
fi

log_info "✓ Cluster created with ID: $CLUSTER_ID"

# Get discovery ISO URL
log_info "Generating discovery ISO..."
ISO_RESPONSE=$(curl -s -X POST "$API_URL/clusters/$CLUSTER_ID/downloads/image" \
  -H "Content-Type: application/json" \
  -d '{
    "image_type": "full-iso",
    "ssh_public_key": "'"$SSH_PUBLIC_KEY"'"
  }')

# Get ISO download URL
ISO_URL="$API_URL/clusters/$CLUSTER_ID/downloads/image"

log_info "✓ Discovery ISO ready!"
echo ""
echo "====================================="
echo "Cluster Information"
echo "====================================="
echo "Cluster ID: $CLUSTER_ID"
echo "Cluster Name: $CLUSTER_NAME.$BASE_DOMAIN"
echo "UI: http://192.168.2.205:8080/assisted-installer/clusters/$CLUSTER_ID"
echo ""
echo "====================================="
echo "Download Discovery ISO"
echo "====================================="
echo "ISO URL: $ISO_URL"
echo ""
echo "Download with:"
echo "  curl -o okd-discovery.iso '$ISO_URL'"
echo ""
echo "Or use wget:"
echo "  wget -O okd-discovery.iso '$ISO_URL'"
echo ""
echo "====================================="
echo "Next Steps"
echo "====================================="
echo "1. Download the ISO"
echo "2. Upload to Proxmox storage"
echo "3. Create a new VM and attach the ISO"
echo "4. Boot the VM - it will register with assisted-service"
echo "5. Monitor installation at: http://192.168.2.205:8080"
echo ""
