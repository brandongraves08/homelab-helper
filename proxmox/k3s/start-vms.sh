#!/usr/bin/env bash
#
# Quick Start K3s with existing VMs
# Uses RHEL 9 for installation
#

set -euo pipefail

PROXMOX_HOST="192.168.2.196"

echo "================================================"
echo "K3s Quick Start with RHEL 9"
echo "================================================"
echo ""
echo "Current VM Status:"
ssh root@${PROXMOX_HOST} "qm list | grep -E '(VMID|9200|9201|9202)'"

echo ""
echo "This will start all 3 VMs for manual RHEL 9 installation."
echo ""
echo "Installation steps per VM:"
echo "  1. Boot from RHEL 9 ISO"
echo "  2. Select 'Install Red Hat Enterprise Linux 9.5'"
echo "  3. Set hostname: k3s-server-1 / k3s-server-2 / k3s-server-3"
echo "  4. Configure network:"
echo "     - Set IP: 192.168.2.250 / .251 / .252"
echo "     - Gateway: 192.168.2.1"
echo "     - DNS: 192.168.2.1"
echo "  5. Create user 'centos' with password (enable sudo)"
echo "  6. Install 'Server' or 'Minimal Install'"
echo "  7. Wait for installation to complete (~5-10 minutes)"
echo ""
read -p "Start VMs now? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting VMs..."
ssh root@${PROXMOX_HOST} "for vmid in 9200 9201 9202; do qm start \$vmid; done"

echo ""
echo "✓ VMs started"
echo ""
echo "Next steps:"
echo ""
echo "1. Open Proxmox web console for each VM:"
echo "   https://192.168.2.196:8006"
echo "   - VM 9200 (k3s-server-1) → 192.168.2.250"
echo "   - VM 9201 (k3s-server-2) → 192.168.2.251"
echo "   - VM 9202 (k3s-server-3) → 192.168.2.252"
echo ""
echo "2. Complete RHEL 9 installation on each VM"
echo ""
echo "3. After all VMs are installed and rebooted, run:"
echo "   ./install-k3s.sh"
echo ""
echo "Tip: You can install all 3 VMs in parallel using separate console windows"
