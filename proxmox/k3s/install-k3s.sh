#!/usr/bin/env bash
#
# Install K3s on all server nodes
# Assumes VMs are already created and Ubuntu is installed
#

set -euo pipefail

# Configuration
FIRST_SERVER="192.168.2.250"
SECOND_SERVER="192.168.2.251"
THIRD_SERVER="192.168.2.252"
CLUSTER_TOKEN="k3s-homelab-token"
API_ENDPOINT="api.k3s.thelab.lan"
LB_IP="192.168.2.196"

SSH_USER="centos"
K3S_VERSION="${K3S_VERSION:-latest}"  # Override with K3S_VERSION=v1.31.0+k3s1

echo "================================================"
echo "K3s Cluster Installation"
echo "================================================"
echo ""
echo "This script will install K3s on three servers:"
echo "  - First server:  ${FIRST_SERVER} (cluster-init)"
echo "  - Second server: ${SECOND_SERVER}"
echo "  - Third server:  ${THIRD_SERVER}"
echo ""
echo "Cluster token: ${CLUSTER_TOKEN}"
echo "API endpoint:  ${API_ENDPOINT}"
echo "Load balancer: ${LB_IP}"
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Install K3s on first server
echo ""
echo "Step 1: Installing K3s on first server (${FIRST_SERVER})..."
echo "--------------------------------------------------------------"

ssh ${SSH_USER}@${FIRST_SERVER} <<EOF
set -euo pipefail

echo "Installing K3s with cluster-init..."
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --token ${CLUSTER_TOKEN} \
  --tls-san ${API_ENDPOINT} \
  --tls-san ${LB_IP} \
  --write-kubeconfig-mode 644

echo "Waiting for K3s to start..."
timeout=60
while [ \$timeout -gt 0 ]; do
    if sudo k3s kubectl get nodes 2>/dev/null | grep -q Ready; then
        echo "✓ K3s is ready"
        break
    fi
    timeout=\$((timeout - 1))
    sleep 1
done

if [ \$timeout -eq 0 ]; then
    echo "✗ K3s failed to start in time"
    exit 1
fi

echo ""
echo "First server installed successfully"
echo ""
echo "Node status:"
sudo k3s kubectl get nodes
EOF

if [ $? -ne 0 ]; then
    echo "✗ Failed to install K3s on first server"
    exit 1
fi

echo ""
echo "✓ First server ready"

# Get node token
echo ""
echo "Getting node token from first server..."
NODE_TOKEN=$(ssh ${SSH_USER}@${FIRST_SERVER} "sudo cat /var/lib/rancher/k3s/server/node-token")

if [ -z "$NODE_TOKEN" ]; then
    echo "✗ Failed to get node token"
    exit 1
fi

echo "✓ Node token retrieved"

# Step 2: Join second server
echo ""
echo "Step 2: Joining second server (${SECOND_SERVER})..."
echo "--------------------------------------------------------------"

ssh ${SSH_USER}@${SECOND_SERVER} <<EOFSECOND
set -euo pipefail

echo "Installing K3s and joining cluster..."
curl -sfL https://get.k3s.io | K3S_TOKEN=${NODE_TOKEN} sh -s - server \
  --server https://${FIRST_SERVER}:6443 \
  --tls-san ${API_ENDPOINT} \
  --tls-san ${LB_IP}

echo "Waiting for K3s to start..."
timeout=60
while [ \$timeout -gt 0 ]; do
    if sudo systemctl is-active k3s >/dev/null 2>&1; then
        echo "✓ K3s service is active"
        break
    fi
    timeout=\$((timeout - 1))
    sleep 1
done

echo ""
echo "Second server joined successfully"
EOFSECOND

if [ $? -ne 0 ]; then
    echo "✗ Failed to join second server"
    exit 1
fi

echo ""
echo "✓ Second server joined"

# Step 3: Join third server
echo ""
echo "Step 3: Joining third server (${THIRD_SERVER})..."
echo "--------------------------------------------------------------"

ssh ${SSH_USER}@${THIRD_SERVER} <<EOFTHIRD
set -euo pipefail

echo "Installing K3s and joining cluster..."
curl -sfL https://get.k3s.io | K3S_TOKEN=${NODE_TOKEN} sh -s - server \
  --server https://${FIRST_SERVER}:6443 \
  --tls-san ${API_ENDPOINT} \
  --tls-san ${LB_IP}

echo "Waiting for K3s to start..."
timeout=60
while [ \$timeout -gt 0 ]; do
    if sudo systemctl is-active k3s >/dev/null 2>&1; then
        echo "✓ K3s service is active"
        break
    fi
    timeout=\$((timeout - 1))
    sleep 1
done

echo ""
echo "Third server joined successfully"
EOFTHIRD

if [ $? -ne 0 ]; then
    echo "✗ Failed to join third server"
    exit 1
fi

echo ""
echo "✓ Third server joined"

# Step 4: Verify cluster
echo ""
echo "Step 4: Verifying cluster..."
echo "--------------------------------------------------------------"

ssh ${SSH_USER}@${FIRST_SERVER} <<'EOF'
echo "All nodes:"
sudo k3s kubectl get nodes

echo ""
echo "System pods:"
sudo k3s kubectl get pods -A
EOF

echo ""
echo "================================================"
echo "K3s Cluster Installation Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Copy kubeconfig to your local machine:"
echo "   scp centos@${FIRST_SERVER}:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config"
echo "   sed -i 's/127.0.0.1/${API_ENDPOINT}/g' ~/.kube/k3s-config"
echo "   export KUBECONFIG=~/.kube/k3s-config"
echo ""
echo "2. Verify access:"
echo "   kubectl get nodes"
echo "   kubectl cluster-info"
echo ""
echo "3. Configure HAProxy load balancer (if not already done):"
echo "   ./configure-haproxy.sh"
echo ""
echo "4. Deploy applications:"
echo "   kubectl create deployment nginx --image=nginx"
echo "   kubectl expose deployment nginx --port=80 --type=LoadBalancer"
echo ""
echo "Cluster ready for use!"
