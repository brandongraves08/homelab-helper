#!/bin/bash
set -euo pipefail

# Deploy OKD Assisted Service to Ubuntu Bastion Host
# This script copies files to ubuntu.thelab.lan (192.168.2.205) and deploys there

BASTION_HOST="${BASTION_HOST:-ubuntu.thelab.lan}"
BASTION_USER="${BASTION_USER:-brandon}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

log_info "Deploying OKD Assisted Service to Ubuntu bastion: $BASTION_HOST (192.168.2.205)"

# Check SSH connectivity
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$BASTION_USER@$BASTION_HOST" "echo 'SSH OK'" &>/dev/null; then
    log_error "Cannot connect to $BASTION_HOST via SSH"
    log_info "Ensure SSH key is configured or use: ssh-copy-id $BASTION_USER@$BASTION_HOST"
    exit 1
fi

log_info "✓ SSH connection successful"

# Create directory on bastion
log_info "Creating deployment directory on bastion..."
ssh -o StrictHostKeyChecking=no "$BASTION_USER@$BASTION_HOST" "mkdir -p ~/okd-assisted-service"

# Update configmap with bastion IP
log_info "Updating configuration for bastion deployment..."
sed "s/192.168.2.1/192.168.2.205/g" "$SCRIPT_DIR/okd-configmap.yml" > /tmp/okd-configmap-bastion.yml

# Copy files to bastion
log_info "Copying files to bastion..."
scp -o StrictHostKeyChecking=no \
    /tmp/okd-configmap-bastion.yml \
    "$SCRIPT_DIR/pod.yml" \
    "$BASTION_USER@$BASTION_HOST:~/okd-assisted-service/"

# Create remote deployment script
cat > /tmp/deploy-remote.sh << 'REMOTESCRIPT'
#!/bin/bash
set -euo pipefail

cd ~/okd-assisted-service

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "Installing podman..."
    sudo apt-get update && sudo apt-get install -y podman
fi

# Stop existing pod if running
podman pod rm -f assisted-installer 2>/dev/null || true

# Deploy the pod
echo "Deploying assisted installer pod..."
mv okd-configmap-bastion.yml okd-configmap.yml
podman play kube --configmap okd-configmap.yml pod.yml

echo ""
echo "Deployment complete!"
echo "Service endpoints:"
echo "  - UI:            http://192.168.2.205:8080"
echo "  - API:           http://192.168.2.205:8090"
echo "  - Image Service: http://192.168.2.205:8888"
echo ""
echo "To check status: podman pod ps"
echo "To view logs:    podman pod logs assisted-installer"
echo "To stop:         podman play kube --down ~/okd-assisted-service/pod.yml"
REMOTESCRIPT

chmod +x /tmp/deploy-remote.sh

# Copy and execute deployment script
log_info "Executing deployment on bastion..."
scp -o StrictHostKeyChecking=no /tmp/deploy-remote.sh "$BASTION_USER@$BASTION_HOST:~/okd-assisted-service/"
ssh -o StrictHostKeyChecking=no "$BASTION_USER@$BASTION_HOST" "bash ~/okd-assisted-service/deploy-remote.sh"

# Cleanup temp files
rm -f /tmp/okd-configmap-bastion.yml /tmp/deploy-remote.sh

log_info "✓ Deployment complete!"
echo ""
log_info "Access the UI at: http://192.168.2.205:8080"
log_info "API endpoint: http://192.168.2.205:8090"
