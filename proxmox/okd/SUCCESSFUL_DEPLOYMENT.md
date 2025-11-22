# OKD Successful Deployment Guide

**Date**: November 21, 2025  
**Method**: Assisted Service on Proxmox  
**Version**: OKD 4.16.0-0.okd-2024-03-27-015536  
**Result**: ✅ Fully operational cluster in ~20 minutes

## What Worked

### 1. Deploy Assisted Service Directly on Proxmox

**Key Decision**: When bastion host (192.168.2.205) was unavailable, deployed Assisted Service directly on Proxmox host (192.168.2.196).

**Steps**:
```bash
# Install podman on Proxmox (Debian 12)
apt-get update
apt-get install -y podman jq curl

# Clone assisted-service repo
cd ~
git clone https://github.com/openshift/assisted-service.git
cd assisted-service/deploy/podman

# Configure for OKD
cp ../../internal/controller/config/okd-configmap.yml .

# CRITICAL: Update SERVICE_BASE_URL in okd-configmap.yml
# Change from localhost to Proxmox IP: 192.168.2.196:8090
sed -i 's|http://localhost:8090|http://192.168.2.196:8090|g' okd-configmap.yml

# Deploy the pod
./install-service.sh
```

**Why This Worked**:
- No need for separate bastion infrastructure
- Direct access to Proxmox APIs and storage
- Simplified networking (all on same host)
- ISO can be downloaded directly to `/var/lib/vz/template/iso/`

### 2. Create Cluster via API (NOT UI)

**Key Insight**: Use SSH to Proxmox and access API on localhost (127.0.0.1) - more reliable than remote access.

**Cluster Creation**:
```bash
ssh root@192.168.2.196

CLUSTER_ID=$(curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters \
  -H "Content-Type: application/json" \
  -d '{
    "name": "okd-sno",
    "openshift_version": "4.16",
    "cpu_architecture": "x86_64",
    "high_availability_mode": "None",
    "base_dns_domain": "thelab.lan",
    "pull_secret": "{\"auths\":{\"fake\":{\"auth\":\"aGVsbG86d29ybGQ=\"}}}",
    "ssh_public_key": "'"$(cat ~/.ssh/id_rsa.pub)"'"
  }' | jq -r '.id')

echo $CLUSTER_ID > ~/cluster-id.txt
```

**InfraEnv Creation**:
```bash
INFRAENV_ID=$(curl -s http://127.0.0.1:8090/api/assisted-install/v2/infra-envs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "okd-sno-infraenv",
    "cluster_id": "'"$CLUSTER_ID"'",
    "pull_secret": "{\"auths\":{\"fake\":{\"auth\":\"aGVsbG86d29ybGQ=\"}}}",
    "ssh_authorized_key": "'"$(cat ~/.ssh/id_rsa.pub)"'",
    "image_type": "full-iso",
    "cpu_architecture": "x86_64"
  }' | jq -r '.id')

echo $INFRAENV_ID > ~/infraenv-id.txt
```

**Download ISO**:
```bash
# Get ISO URL
ISO_URL=$(curl -s http://127.0.0.1:8090/api/assisted-install/v2/infra-envs/$INFRAENV_ID/downloads/image-url | jq -r '.url')

# Download to Proxmox storage
curl -L "$ISO_URL" -o /var/lib/vz/template/iso/okd-sno-discovery.iso
```

### 3. Network Configuration (CRITICAL)

**Pre-VM Configuration** (must be done BEFORE creating VM):

**DHCP Reservation**:
```bash
# On your router/DHCP server
# Reserve IP 192.168.2.252 for MAC BC:24:11:28:3D:D8
# This ensures consistent IP from first boot
```

**DNS Records** (on 192.168.2.1 or your DNS server):
```
api.okd-sno.thelab.lan          → 192.168.2.252
api-int.okd-sno.thelab.lan      → 192.168.2.252
*.apps.okd-sno.thelab.lan       → 192.168.2.252
```

**Why This Order Matters**:
- VM boots with discovery ISO
- Gets correct IP via DHCP immediately
- DNS validation happens early in installation
- No IP changes during installation

### 4. Create VM with Correct Specifications

**Command**:
```bash
ssh root@192.168.2.196

# Create VM
qm create 150 \
  --name okd-sno \
  --memory 16384 \
  --cores 8 \
  --cpu host \
  --net0 virtio,bridge=vmbr0,firewall=0 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:100 \
  --ide2 local:iso/okd-sno-discovery.iso,media=cdrom \
  --boot order=ide2 \
  --ostype l26

# Start VM
qm start 150
```

**Critical Settings**:
- **Memory**: 16GB minimum for SNO
- **CPU**: `host` passthrough for best performance
- **Network**: `virtio` driver, no firewall
- **Disk**: 100GB minimum, `virtio-scsi-single` controller
- **Boot**: Start with `ide2` (ISO) first

### 5. Monitor Installation (via SSH to Proxmox)

**Check Host Registration**:
```bash
ssh root@192.168.2.196

CLUSTER_ID=$(cat ~/cluster-id.txt)

# Wait for host to register
watch -n 10 "curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID | jq -r '.hosts[0].status'"
```

**Start Installation** (once host shows "ready"):
```bash
curl -X POST http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID/actions/install
```

**Monitor Progress**:
```bash
# Watch installation stages
watch -n 15 "curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID | jq '{status: .status, host_status: .hosts[0].status, stage: .hosts[0].progress.current_stage, percentage: .hosts[0].progress.installation_percentage}'"
```

### 6. Handle Boot Order Issue (POST-INSTALL CRITICAL)

**Problem**: After installation completes, VM kept booting from ISO instead of disk.

**Solution** (when host reaches "Done" stage):
```bash
# Get VM MAC address
qm config 150 | grep net0

# Wait for "Done" stage
curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID | jq '.hosts[0].progress.current_stage'

# When "Done", shut down VM
qm stop 150

# Remove ISO completely
qm set 150 --delete ide2

# Set boot order to disk only
qm set 150 --boot order=scsi0

# Start VM
qm start 150
```

**Why This Works**:
- Ignition configuration is already written to disk
- ISO is no longer needed
- VM boots from installed system
- Cluster finalization continues automatically

### 7. Access Cluster

**Wait for API to stabilize** (~2-3 minutes after boot):
```bash
# Test API from anywhere
curl -k https://api.okd-sno.thelab.lan:6443/version
```

**Get kubeconfig**:
```bash
# SSH to node and extract kubeconfig
ssh root@192.168.2.196 \
  "ssh -o StrictHostKeyChecking=no core@192.168.2.252 \
  'sudo cat /etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-ext.kubeconfig'" \
  > ~/.kube/config-okd-sno

# Test access
export KUBECONFIG=~/.kube/config-okd-sno
kubectl get nodes
kubectl get co
```

**Get Web Console Credentials**:
```bash
export KUBECONFIG=~/.kube/config-okd-sno

# Username: kubeadmin
# Password:
kubectl get secret kubeadmin -n kube-system -o jsonpath='{.data.kubeadmin}' | base64 -d

# URL:
echo "https://$(kubectl get route -n openshift-console console -o jsonpath='{.spec.host}')"
```

## Key Lessons Learned

### What Made This Work

1. **Deploy Assisted Service on Proxmox itself** - eliminates bastion dependency
2. **Configure network BEFORE VM creation** - DHCP reservation and DNS must exist first
3. **Use SSH to Proxmox for API calls** - access localhost:8090 for reliability
4. **Remove ISO after installation** - critical to prevent boot loops
5. **Wait for API after reboot** - kube-apiserver may restart during operator updates
6. **Extract kubeconfig from node** - more reliable than Assisted Service endpoint during finalization

### Critical Timing Issues Resolved

**Problem**: Cluster stuck at "Rebooting" stage  
**Cause**: VM kept booting from ISO  
**Solution**: Remove ISO, set boot order to disk only

**Problem**: kubeconfig endpoint returns 404  
**Cause**: Cluster still in "finalizing" status  
**Solution**: Extract from node filesystem via SSH

**Problem**: API connection refused after boot  
**Cause**: API server restarting during operator updates  
**Solution**: Wait 30-60 seconds, retry

### Installation Timeline

```
00:00 - Create cluster via API
00:02 - Create InfraEnv and download ISO (~820MB)
00:05 - Create VM and start with ISO
00:07 - Host registers with Assisted Service
00:08 - Start installation
00:15 - Installation reaches "Done" (100%)
00:16 - Stop VM, remove ISO, reboot
00:18 - VM boots from disk, cluster finalizing
00:20 - API accessible, kubectl works
00:25 - All operators stabilized
```

**Total time: ~25 minutes from start to fully operational cluster**

## Quick Reference Commands

### Cluster Status Check
```bash
ssh root@192.168.2.196 "curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/\$(cat ~/cluster-id.txt) | jq '{status, host_status: .hosts[0].status, stage: .hosts[0].progress.current_stage}'"
```

### VM Status
```bash
ssh root@192.168.2.196 "qm status 150"
```

### Check API Health
```bash
curl -k https://api.okd-sno.thelab.lan:6443/version
```

### SSH to Node
```bash
ssh core@192.168.2.252
```

### Monitor Cluster Operators
```bash
export KUBECONFIG=~/.kube/config-okd-sno
watch kubectl get co
```

## Environment Specifics

- **Proxmox Host**: 192.168.2.196 (Debian 12 bookworm)
- **OKD Node**: 192.168.2.252 (Fedora CoreOS 39)
- **Network**: 192.168.2.0/24, gateway .1, DNS .1
- **VM ID**: 150
- **Cluster Name**: okd-sno
- **Domain**: thelab.lan

## Files Created

On Proxmox (192.168.2.196):
- `~/cluster-id.txt` - Cluster UUID
- `~/infraenv-id.txt` - InfraEnv UUID
- `/var/lib/vz/template/iso/okd-sno-discovery.iso` - Discovery ISO

On Workstation:
- `~/.kube/config-okd-sno` - Cluster kubeconfig
- `/usr/local/bin/kubectl` - Kubernetes CLI

## Success Criteria

✅ Node status: Ready  
✅ All cluster operators: Available  
✅ API endpoint: Responding  
✅ Web console: Accessible  
✅ SSH access: Working  
✅ kubectl commands: Functional  

## Next Time Checklist

- [ ] Ensure DHCP reservation exists for target IP
- [ ] Create DNS records before VM creation
- [ ] Deploy Assisted Service on Proxmox (not bastion)
- [ ] Access API via SSH to Proxmox (localhost:8090)
- [ ] Create cluster and InfraEnv via API
- [ ] Download ISO directly to Proxmox storage
- [ ] Create VM with correct specs (16GB, 8 vCPU, 100GB)
- [ ] Monitor via API until "Done" stage
- [ ] **CRITICAL**: Remove ISO and reboot after "Done"
- [ ] Wait 2-3 minutes for API to stabilize
- [ ] Extract kubeconfig via SSH from node
- [ ] Verify all operators are Available
- [ ] Access web console

**Estimated total time: 20-30 minutes**
