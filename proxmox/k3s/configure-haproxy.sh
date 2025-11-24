#!/usr/bin/env bash
#
# Configure HAProxy on Proxmox host for K3s API load balancing
#

set -euo pipefail

PROXMOX_HOST="192.168.2.196"

echo "================================================"
echo "HAProxy Configuration for K3s"
echo "================================================"
echo ""

# Check if HAProxy is installed
echo "Checking if HAProxy is installed on Proxmox host..."
if ! ssh root@${PROXMOX_HOST} "which haproxy" > /dev/null 2>&1; then
    echo "Installing HAProxy..."
    ssh root@${PROXMOX_HOST} "apt update && apt install -y haproxy"
else
    echo "✓ HAProxy is already installed"
fi

# Backup existing configuration
echo ""
echo "Backing up existing HAProxy configuration..."
ssh root@${PROXMOX_HOST} "cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup-\$(date +%Y%m%d-%H%M%S)"

# Create K3s HAProxy configuration
echo ""
echo "Creating HAProxy configuration for K3s..."
ssh root@${PROXMOX_HOST} <<'EOF'
cat > /etc/haproxy/haproxy-k3s.cfg <<'HAPROXY_CFG'
# HAProxy configuration for K3s Kubernetes Cluster
# Load balances API server traffic across 3 control plane nodes

global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# K3s API Server (6443)
frontend k3s-api
    bind *:6443
    mode tcp
    option tcplog
    default_backend k3s-api-servers

backend k3s-api-servers
    mode tcp
    option tcp-check
    balance roundrobin
    server k3s-server-1 192.168.2.250:6443 check fall 3 rise 2
    server k3s-server-2 192.168.2.251:6443 check fall 3 rise 2
    server k3s-server-3 192.168.2.252:6443 check fall 3 rise 2

# HAProxy Statistics (optional)
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /
    stats refresh 10s
    stats admin if TRUE
HAPROXY_CFG

echo "✓ HAProxy configuration created"
EOF

# Test configuration
echo ""
echo "Testing HAProxy configuration..."
if ssh root@${PROXMOX_HOST} "haproxy -c -f /etc/haproxy/haproxy-k3s.cfg"; then
    echo "✓ Configuration is valid"
else
    echo "✗ Configuration has errors"
    exit 1
fi

# Update main configuration to include K3s config
echo ""
echo "Updating main HAProxy configuration..."
ssh root@${PROXMOX_HOST} <<'EOF'
# Check if k3s config is already included
if ! grep -q "haproxy-k3s.cfg" /etc/haproxy/haproxy.cfg; then
    # Append include directive
    echo "" >> /etc/haproxy/haproxy.cfg
    echo "# K3s Kubernetes Cluster" >> /etc/haproxy/haproxy.cfg
    echo "include /etc/haproxy/haproxy-k3s.cfg" >> /etc/haproxy/haproxy.cfg
    echo "✓ K3s configuration included in main config"
else
    echo "✓ K3s configuration already included"
fi
EOF

# Restart HAProxy
echo ""
echo "Restarting HAProxy..."
ssh root@${PROXMOX_HOST} "systemctl restart haproxy && systemctl status haproxy --no-pager -l"

echo ""
echo "================================================"
echo "HAProxy Configuration Complete"
echo "================================================"
echo ""
echo "Load balancer is now active on ${PROXMOX_HOST}:6443"
echo ""
echo "Backends:"
echo "  - k3s-server-1: 192.168.2.250:6443"
echo "  - k3s-server-2: 192.168.2.251:6443"
echo "  - k3s-server-3: 192.168.2.252:6443"
echo ""
echo "HAProxy stats: http://${PROXMOX_HOST}:8404"
echo ""
echo "Verify load balancer:"
echo "  curl -k https://${PROXMOX_HOST}:6443/healthz"
echo ""
echo "Test from local machine:"
echo "  kubectl --kubeconfig ~/.kube/k3s-config get nodes"
