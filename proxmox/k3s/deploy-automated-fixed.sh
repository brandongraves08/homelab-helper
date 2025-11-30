#!/usr/bin/env bash
#
# Fixed Automated K3s Deployment
# Uses proper disk import and boot configuration
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROXMOX_HOST="192.168.2.196"
CLOUD_IMAGE="/var/lib/vz/template/qcow/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"

declare -A VMS=(
    [9200]="k3s-server-1:192.168.2.250:BC:24:11:92:00:00"
    [9201]="k3s-server-2:192.168.2.251:BC:24:11:92:01:00"
    [9202]="k3s-server-3:192.168.2.252:BC:24:11:92:02:00"
)

SSH_KEY=$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "")

echo "================================================================"
echo "Fully Automated K3s Deployment - Fixed Boot Configuration"
echo "================================================================"
echo ""

if [ -z "$SSH_KEY" ]; then
    echo "⚠ No SSH key found. Generating one..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "k3s-homelab"
    SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
fi

# Create cloud-init vendor config first
echo "Creating cloud-init vendor config..."
ssh root@${PROXMOX_HOST} 'cat > /var/lib/vz/snippets/k3s-prep.yml' <<'CLOUDCONFIG'
#cloud-config
package_update: true
package_upgrade: false
packages:
  - qemu-guest-agent

runcmd:
  # Start qemu-guest-agent
  - systemctl enable --now qemu-guest-agent
  # Disable firewall
  - systemctl disable --now firewalld || true
  # Enable IP forwarding
  - sysctl -w net.ipv4.ip_forward=1
  - sysctl -w net.ipv6.conf.all.forwarding=1
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-k3s.conf
  - echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-k3s.conf
  # SELinux permissive
  - setenforce 0 || true
  - sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config || true
  # Add centos to sudoers
  - echo "centos ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/centos
  - chmod 440 /etc/sudoers.d/centos

final_message: "Cloud-init complete, system ready for K3s installation"
CLOUDCONFIG

echo "✓ Cloud-init config created"
echo ""

for vmid in "${!VMS[@]}"; do
    IFS=: read -r name ip mac <<< "${VMS[$vmid]}"
    
    echo "→ Creating VM $vmid ($name)..."
    
    ssh root@${PROXMOX_HOST} <<EOF
# Create VM
qm create $vmid \
  --name $name \
  --memory 8192 \
  --cores 4 \
  --cpu host \
  --net0 virtio,bridge=vmbr0,macaddr=$mac \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1 \
  --bios ovmf

# Add EFI disk
qm set $vmid --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0

# Import cloud image to unused disk
qm importdisk $vmid $CLOUD_IMAGE local-lvm

# Attach imported disk as scsi0
qm set $vmid --scsihw virtio-scsi-pci
qm set $vmid --scsi0 local-lvm:vm-$vmid-disk-1

# Resize to 80GB
qm disk resize $vmid scsi0 80G

# Set boot disk
qm set $vmid --boot order=scsi0

# Add cloud-init drive
qm set $vmid --ide2 local-lvm:cloudinit

# Configure cloud-init
qm set $vmid --ipconfig0 ip=$ip/24,gw=192.168.2.1
qm set $vmid --nameserver 192.168.2.1
qm set $vmid --searchdomain thelab.lan
qm set $vmid --ciuser centos
qm set $vmid --cipassword centos123
qm set $vmid --sshkeys <(echo '$SSH_KEY')
qm set $vmid --cicustom "vendor=local:snippets/k3s-prep.yml"

echo "✓ VM $vmid created"
EOF
    
done

echo ""
echo "Starting VMs..."
ssh root@${PROXMOX_HOST} 'for vmid in 9200 9201 9202; do qm start $vmid && echo "Started VM $vmid"; sleep 2; done'

echo ""
echo "================================================================"
echo "VMs Starting - Waiting for SSH (~2 minutes)"
echo "================================================================"
echo ""

# Wait for SSH
for i in {1..120}; do
    ready=0
    for vmid in "${!VMS[@]}"; do
        IFS=: read -r name ip mac <<< "${VMS[$vmid]}"
        if timeout 2 ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null centos@$ip true 2>/dev/null; then
            ((ready++))
        fi
    done
    
    if [ $ready -eq 3 ]; then
        echo ""
        echo "✓ All VMs are ready!"
        break
    fi
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "  Waiting for SSH access... ($ready/3 VMs ready)"
    fi
    sleep 3
done

if [ $ready -lt 3 ]; then
    echo ""
    echo "⚠ Warning: Only $ready/3 VMs are accessible via SSH"
    echo "You can check VM consoles and try SSH manually:"
    for vmid in "${!VMS[@]}"; do
        IFS=: read -r name ip mac <<< "${VMS[$vmid]}"
        echo "  ssh centos@$ip"
    done
    exit 1
fi

echo ""
echo "================================================================"
echo "Installing K3s Cluster..."
echo "================================================================"
echo ""

cd "$SCRIPT_DIR"
./install-k3s.sh
