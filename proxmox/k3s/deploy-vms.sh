#!/usr/bin/env bash
#
# Deploy K3s VMs on Proxmox
# Creates 3 Ubuntu VMs for K3s HA cluster with embedded etcd
#

set -euo pipefail

# Configuration
PROXMOX_HOST="192.168.2.196"
VMID_START=9200
CENTOS_TEMPLATE_ID=9001  # Adjust to your CentOS Stream cloud-init template ID
CENTOS_ISO="local:iso/CentOS-Stream-9-latest-x86_64-dvd1.iso"  # Fallback if no template

# VM Specifications
VM_MEMORY=8192      # 8 GB RAM
VM_CORES=4
VM_DISK_SIZE=80     # GB
BRIDGE="vmbr0"

# IP Configuration (DHCP reservations recommended)
declare -A VM_CONFIG=(
    [9200]="k3s-server-1:192.168.2.250:BC:24:11:92:00:00"
    [9201]="k3s-server-2:192.168.2.251:BC:24:11:92:01:00"
    [9202]="k3s-server-3:192.168.2.252:BC:24:11:92:02:00"
)

echo "================================================"
echo "K3s VM Deployment on Proxmox (CentOS Stream 9)"
echo "================================================"
echo ""

# Function to create VM from template (preferred method)
create_vm_from_template() {
    local vmid=$1
    local name=$2
    local ip=$3
    local mac=$4
    
    echo "Creating VM $vmid ($name) from template..."
    
    # Clone template
    ssh root@${PROXMOX_HOST} "qm clone ${CENTOS_TEMPLATE_ID} ${vmid} --name ${name} --full"
    
    # Configure VM
    ssh root@${PROXMOX_HOST} <<EOF
# Set CPU and memory
qm set ${vmid} --cores ${VM_CORES} --memory ${VM_MEMORY}

# Set CPU type to host for better performance
qm set ${vmid} --cpu host

# Resize disk
qm resize ${vmid} scsi0 ${VM_DISK_SIZE}G

# Configure network with fixed MAC
qm set ${vmid} --net0 virtio,bridge=${BRIDGE},firewall=0,macaddr=${mac}

# Enable QEMU guest agent
qm set ${vmid} --agent enabled=1

# Set cloud-init
qm set ${vmid} --ipconfig0 ip=${ip}/24,gw=192.168.2.1
qm set ${vmid} --nameserver 192.168.2.1
qm set ${vmid} --searchdomain thelab.lan
qm set ${vmid} --ciuser centos
qm set ${vmid} --cipassword centos123
qm set ${vmid} --sshkeys /root/.ssh/authorized_keys

echo "✓ VM ${vmid} (${name}) created"
EOF
}

# Function to create VM manually (if no template)
create_vm_manual() {
    local vmid=$1
    local name=$2
    local ip=$3
    local mac=$4
    
    echo "Creating VM $vmid ($name) manually..."
    
    ssh root@${PROXMOX_HOST} <<EOF
# Create VM
qm create ${vmid} --name ${name} --memory ${VM_MEMORY} --cores ${VM_CORES} --cpu host

# Add disk
qm set ${vmid} --scsi0 local-lvm:${VM_DISK_SIZE},format=raw

# Add network
qm set ${vmid} --net0 virtio,bridge=${BRIDGE},firewall=0,macaddr=${mac}

# Add CD-ROM with CentOS ISO
qm set ${vmid} --ide2 ${CENTOS_ISO},media=cdrom

# Set boot order
qm set ${vmid} --boot order=scsi0

# Enable QEMU guest agent
qm set ${vmid} --agent enabled=1

# Set VGA
qm set ${vmid} --vga std

# Set BIOS to OVMF (UEFI)
qm set ${vmid} --bios ovmf
qm set ${vmid} --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0

echo "✓ VM ${vmid} (${name}) created - requires manual OS installation"
EOF
}

# Check if CentOS template exists
echo "Checking for CentOS Stream cloud-init template..."
TEMPLATE_EXISTS=$(ssh root@${PROXMOX_HOST} "qm list | grep -c ${CENTOS_TEMPLATE_ID} || true")

if [ "$TEMPLATE_EXISTS" -gt 0 ]; then
    echo "✓ Found template ${CENTOS_TEMPLATE_ID}, using cloud-init"
    USE_TEMPLATE=true
else
    echo "⚠ No template found (ID ${CENTOS_TEMPLATE_ID})"
    echo "  VMs will be created but require manual OS installation"
    echo "  See: https://pve.proxmox.com/wiki/Cloud-Init_Support"
    USE_TEMPLATE=false
fi

echo ""

# Create VMs
for vmid in "${!VM_CONFIG[@]}"; do
    IFS=: read -r name ip mac <<< "${VM_CONFIG[$vmid]}"
    
    # Check if VM already exists
    if ssh root@${PROXMOX_HOST} "qm status ${vmid} 2>/dev/null" > /dev/null 2>&1; then
        echo "⚠ VM ${vmid} already exists, skipping..."
        continue
    fi
    
    if [ "$USE_TEMPLATE" = true ]; then
        create_vm_from_template "$vmid" "$name" "$ip" "$mac"
    else
        create_vm_manual "$vmid" "$name" "$ip" "$mac"
    fi
    
    echo ""
done

echo "================================================"
echo "VM Creation Complete"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
if [ "$USE_TEMPLATE" = true ]; then
    echo "1. Start VMs:"
    echo "   ssh root@${PROXMOX_HOST} 'for vmid in 9200 9201 9202; do qm start \$vmid; done'"
    echo ""
    echo "2. Wait for cloud-init to complete (~2 minutes)"
    echo ""
    echo "3. SSH to first server and install K3s:"
    echo "   ssh centos@192.168.2.250"
    echo "   curl -sfL https://get.k3s.io | sh -s - server --cluster-init --token k3s-homelab-token --tls-san api.k3s.thelab.lan --tls-san 192.168.2.196"
    echo ""
    echo "4. Get node token:"
    echo "   sudo cat /var/lib/rancher/k3s/server/node-token"
    echo ""
    echo "5. Join additional servers (repeat for .251 and .252):"
    echo "   ssh centos@192.168.2.251"
    echo "   curl -sfL https://get.k3s.io | K3S_TOKEN=<token> sh -s - server --server https://192.168.2.250:6443 --tls-san api.k3s.thelab.lan --tls-san 192.168.2.196"
else
    echo "1. Start VMs and install CentOS Stream 9:"
    echo "   ssh root@${PROXMOX_HOST} 'for vmid in 9200 9201 9202; do qm start \$vmid; done'"
    echo ""
    echo "2. Access console and complete CentOS installation:"
    echo "   - Hostname: k3s-server-1/2/3"
    echo "   - User: centos / Password: centos123"
    echo "   - Install OpenSSH server"
    echo "   - Set static IP or configure DHCP reservation"
    echo ""
    echo "3. After OS installation, run ./install-k3s.sh"
fi

echo ""
echo "See README.md for complete deployment guide"
