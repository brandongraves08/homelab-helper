#!/usr/bin/env bash
#
# Fully Automated K3s Deployment
# Uses CentOS Stream 9 cloud images with cloud-init
# No manual installation required!
#

set -euo pipefail

PROXMOX_HOST="192.168.2.196"
CLOUD_IMAGE="/var/lib/vz/template/qcow/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"

# VM Configuration
declare -A VMS=(
    [9200]="k3s-server-1:192.168.2.250:BC:24:11:92:00:00"
    [9201]="k3s-server-2:192.168.2.251:BC:24:11:92:01:00"
    [9202]="k3s-server-3:192.168.2.252:BC:24:11:92:02:00"
)

SSH_KEY=$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "")

echo "================================================================"
echo "Fully Automated K3s Deployment with CentOS Stream 9"
echo "================================================================"
echo ""

if [ -z "$SSH_KEY" ]; then
    echo "⚠ No SSH key found. Generating one..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "k3s-homelab"
    SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
fi

echo "Creating and configuring VMs with cloud-init..."
echo ""

for vmid in "${!VMS[@]}"; do
    IFS=: read -r name ip mac <<< "${VMS[$vmid]}"
    
    echo "→ Configuring VM $vmid ($name)..."
    
    # Destroy existing VM if present
    ssh root@${PROXMOX_HOST} "qm stop $vmid 2>/dev/null || true; qm destroy $vmid 2>/dev/null || true"
    
    # Create VM
    ssh root@${PROXMOX_HOST} <<EOF
# Create VM
qm create $vmid --name $name --memory 8192 --cores 4 --cpu host --net0 virtio,bridge=vmbr0,macaddr=$mac

# Import cloud image as disk
qm set $vmid --scsi0 local-lvm:0,import-from=$CLOUD_IMAGE
qm disk resize $vmid scsi0 80G

# Add cloud-init drive
qm set $vmid --ide2 local-lvm:cloudinit

# Configure cloud-init
qm set $vmid --boot order=scsi0
qm set $vmid --serial0 socket --vga serial0
qm set $vmid --agent enabled=1

# Network configuration
qm set $vmid --ipconfig0 ip=$ip/24,gw=192.168.2.1
qm set $vmid --nameserver 192.168.2.1
qm set $vmid --searchdomain thelab.lan

# User configuration
qm set $vmid --ciuser centos
qm set $vmid --cipassword centos123
qm set $vmid --sshkeys <(echo '$SSH_KEY')

# Custom cloud-init for K3s prerequisites
qm set $vmid --cicustom "vendor=local:snippets/k3s-prep.yml"

echo "✓ VM $vmid configured"
EOF
    
done

echo ""
echo "Creating cloud-init vendor config for K3s..."

# Create vendor cloud-init for K3s prerequisites
ssh root@${PROXMOX_HOST} 'cat > /var/lib/vz/snippets/k3s-prep.yml' <<'CLOUDCONFIG'
#cloud-config
package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - git
  - vim
  - firewalld

runcmd:
  # Disable firewall (K3s handles networking)
  - systemctl disable --now firewalld
  # Enable IP forwarding
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  - echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
  - sysctl -p
  # SELinux permissive (K3s will install policies)
  - setenforce 0 || true
  - sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
  # Add centos to sudoers
  - echo "centos ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/centos
  - chmod 440 /etc/sudoers.d/centos

power_state:
  mode: reboot
  timeout: 300
  condition: True
CLOUDCONFIG

echo "✓ Cloud-init configuration created"
echo ""
echo "Starting all VMs..."

# Start VMs
ssh root@${PROXMOX_HOST} 'for vmid in 9200 9201 9202; do qm start $vmid && echo "Started VM $vmid"; done'

echo ""
echo "================================================================"
echo "VMs Starting - Waiting for Cloud-Init (~2-3 minutes)"
echo "================================================================"
echo ""
echo "Cloud-init will automatically:"
echo "  ✓ Configure network with static IPs"
echo "  ✓ Create 'centos' user with SSH access"
echo "  ✓ Install required packages"
echo "  ✓ Configure firewall and IP forwarding"
echo "  ✓ Set up SELinux for K3s"
echo "  ✓ Reboot to apply changes"
echo ""
echo "Waiting for VMs to complete initialization..."

# Wait for SSH to become available
for i in {1..180}; do
    ready=0
    for vmid in "${!VMS[@]}"; do
        IFS=: read -r name ip mac <<< "${VMS[$vmid]}"
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no centos@$ip true 2>/dev/null; then
            ((ready++))
        fi
    done
    
    if [ $ready -eq 3 ]; then
        echo ""
        echo "✓ All VMs are ready!"
        break
    fi
    
    if [ $((i % 15)) -eq 0 ]; then
        echo "  Still waiting... ($ready/3 VMs ready)"
    fi
    sleep 2
done

echo ""
echo "================================================================"
echo "Automated VM Setup Complete!"
echo "================================================================"
echo ""
echo "Installing K3s cluster..."
echo ""

# Run K3s installation
cd /home/brandon/projects/homelab-helper/proxmox/k3s
./install-k3s.sh

echo ""
echo "================================================================"
echo "K3s Deployment Complete!"
echo "================================================================"
