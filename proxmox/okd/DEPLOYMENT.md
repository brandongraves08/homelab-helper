# OKD Deployment with Assisted Service - Complete Guide

## Current Deployment Status

- **Cluster ID**: 64de2825-c01b-4107-92f4-189901f665c5
- **Cluster Name**: okd.thelab.lan
- **VM ID**: 150 on Proxmox
- **VM IP**: 192.168.2.252
- **Assisted Service UI**: http://192.168.2.205:8080
- **API Endpoint**: http://192.168.2.205:8090
- **Installation Status**: In Progress

## Architecture

```
Workstation (WSL)          Bastion Host              Proxmox              OKD Node
172.28.219.100        →    192.168.2.205        →    192.168.2.196    →   192.168.2.252
                           ubuntu.thelab.lan          Proxmox VE           VM ID 150
                           (Assisted Service)         (Hypervisor)         (OKD SNO)
```

## Services Running on Bastion

- **PostgreSQL**: Port 5432 (database)
- **Assisted Installer UI**: Port 8080 (web interface)
- **Assisted Service API**: Port 8090 (REST API)
- **Image Service**: Port 8888 (ISO generation)

## Complete Deployment Steps

### 1. Deploy Assisted Service to Bastion
```bash
cd ~/projects/homelab-helper/proxmox/okd/assisted-service
./deploy-to-proxmox.sh
```

### 2. Create Cluster via API
```bash
curl -X POST "http://192.168.2.205:8090/api/assisted-install/v2/clusters" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\":\"okd\",
    \"base_dns_domain\":\"thelab.lan\",
    \"openshift_version\":\"4.16.0-0.okd-scos-2024-11-16-051944\",
    \"cpu_architecture\":\"x86_64\",
    \"high_availability_mode\":\"None\",
    \"pull_secret\":\"{\\\"auths\\\":{\\\"fake\\\":{\\\"auth\\\":\\\"dXNlcjpwYXNzd29yZA==\\\"}}}\",
    \"ssh_public_key\":\"$(cat ~/.ssh/id_rsa.pub)\",
    \"cluster_networks\":[{\"cidr\":\"10.128.0.0/14\",\"host_prefix\":23}],
    \"service_networks\":[{\"cidr\":\"172.30.0.0/16\"}],
    \"machine_networks\":[{\"cidr\":\"192.168.2.0/24\"}],
    \"vip_dhcp_allocation\":false
  }"
```

**Save the cluster ID from the response!**

### 3. Create InfraEnv for Discovery ISO
```bash
CLUSTER_ID="64de2825-c01b-4107-92f4-189901f665c5"

curl -X POST "http://192.168.2.205:8090/api/assisted-install/v2/infra-envs" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\":\"okd-infraenv\",
    \"cluster_id\":\"$CLUSTER_ID\",
    \"pull_secret\":\"{\\\"auths\\\":{\\\"fake\\\":{\\\"auth\\\":\\\"dXNlcjpwYXNzd29yZA==\\\"}}}\",
    \"ssh_authorized_key\":\"$(cat ~/.ssh/id_rsa.pub)\",
    \"openshift_version\":\"4.16\",
    \"cpu_architecture\":\"x86_64\",
    \"image_type\":\"full-iso\"
  }"
```

**Save the InfraEnv ID and download_url!**

### 4. Download Discovery ISO
```bash
INFRAENV_ID="9f5f6d81-3d7e-4c56-a192-469834edf717"
curl -L -o okd-discovery.iso "http://192.168.2.205:8888/byid/$INFRAENV_ID/4.16/x86_64/full.iso"
```

The ISO is approximately 975MB and contains Fedora CoreOS 43.20251024.3.0.

### 5. Upload ISO to Proxmox
```bash
scp okd-discovery.iso root@192.168.2.196:/var/lib/vz/template/iso/
```

### 6. Create and Start VM
```bash
# Create VM
ssh root@192.168.2.196 "qm create 150 \
  --name okd-node-1 \
  --memory 16384 \
  --cores 8 \
  --cpu host \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:100 \
  --boot order=scsi0 \
  --cdrom local:iso/okd-discovery.iso \
  --ostype l26 \
  --agent enabled=1"

# Set boot order and start
ssh root@192.168.2.196 "qm set 150 --boot order='ide2;scsi0' && qm start 150"
```

### 7. Wait for Host Registration
The VM boots from the ISO and registers with assisted-service (1-2 minutes).

Check status:
```bash
curl -s "http://192.168.2.205:8090/api/assisted-install/v2/clusters/$CLUSTER_ID" | \
  python3 -m json.tool | grep -E '(status|hostname)'
```

### 8. Start Installation
```bash
curl -X POST "http://192.168.2.205:8090/api/assisted-install/v2/clusters/$CLUSTER_ID/actions/install"
```

### 9. Monitor Progress
```bash
./monitor-install.sh
```

Or visit: http://192.168.2.205:8080

## Installation Timeline

1. **Preparing** (5 mins): Generating ignition configs
2. **Installing** (20-40 mins): Installing FCOS and bootstrapping
3. **Finalizing** (10-20 mins): Configuring cluster operators
4. **Installed** (Complete): Cluster ready

Total time: **30-60 minutes**

## Monitoring Commands

### Check Cluster Status
```bash
curl -s "http://192.168.2.205:8090/api/assisted-install/v2/clusters/$CLUSTER_ID" | \
  python3 -c "import sys, json; d=json.load(sys.stdin); print(f'Status: {d[\"status\"]} - {d[\"status_info\"]}')"
```

### Check Host Status
```bash
curl -s "http://192.168.2.205:8090/api/assisted-install/v2/clusters/$CLUSTER_ID" | \
  python3 -c "import sys, json; h=json.load(sys.stdin)['hosts'][0]; print(f'Host: {h[\"status\"]} - {h[\"status_info\"]}')"
```

### Check VM Status
```bash
ssh root@192.168.2.196 "qm status 150"
```

### View VM Console
```bash
ssh root@192.168.2.196 "qm monitor 150"
```

## Troubleshooting

### Assisted Service Not Responding
```bash
# Check pod status
ssh brandon@ubuntu.thelab.lan "podman pod ps"

# Restart service
ssh brandon@ubuntu.thelab.lan "cd ~/okd-assisted-service && podman play kube --down pod.yml && podman play kube pod.yml"
```

### Host Not Registering
- Verify VM is running: `ssh root@192.168.2.196 "qm status 150"`
- Check VM has network: VM should get IP via DHCP
- Verify assisted-service is accessible from 192.168.2.0/24 network

### ISO Download Failed (404 Error)
The FCOS ISO URL must use the correct filename format:
- ✅ Correct: `fedora-coreos-43.20251024.3.0-live-iso.x86_64.iso`
- ❌ Wrong: `fedora-coreos-43.20251024.3.0-live.x86_64.iso`

### Installation Stuck
- Check image-service logs: `ssh brandon@ubuntu.thelab.lan "podman logs assisted-installer-image-service"`
- Verify VM has sufficient resources (8 cores, 16GB RAM, 100GB disk)
- Check network connectivity between bastion and VM

## Post-Installation

Once installation completes, access the cluster:

### Get Kubeconfig
```bash
curl -s "http://192.168.2.205:8090/api/assisted-install/v2/clusters/$CLUSTER_ID/downloads/files?file_name=kubeconfig" -o kubeconfig
export KUBECONFIG=./kubeconfig
```

### Access Console
```bash
# Get console URL
kubectl get routes -n openshift-console

# Get kubeadmin password
curl -s "http://192.168.2.205:8090/api/assisted-install/v2/clusters/$CLUSTER_ID/downloads/credentials" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['password'])"
```

## Network Configuration

- **Cluster Networks**: 10.128.0.0/14 (Pod network)
- **Service Networks**: 172.30.0.0/16 (Service network)
- **Machine Networks**: 192.168.2.0/24 (Node network)
- **DNS Domain**: thelab.lan
- **Mode**: Single Node OpenShift (SNO)

## Resource Requirements

### Bastion Host (ubuntu.thelab.lan)
- CPU: 4+ cores
- RAM: 8GB+
- Disk: 50GB+ (for ISO cache)
- Network: Access to 192.168.2.0/24

### OKD Node (VM 150)
- CPU: 8 cores
- RAM: 16GB
- Disk: 100GB
- Network: 192.168.2.0/24 with internet access

## Key Files

- `okd-configmap.yml` - Service configuration
- `pod.yml` - Podman pod manifest
- `deploy-to-proxmox.sh` - Deployment automation
- `monitor-install.sh` - Installation monitoring
- `okd-discovery.iso` - Discovery/installation ISO (975MB)

## API Reference

Base URL: `http://192.168.2.205:8090/api/assisted-install/v2`

- List clusters: `GET /clusters`
- Get cluster: `GET /clusters/{cluster_id}`
- Install cluster: `POST /clusters/{cluster_id}/actions/install`
- Create InfraEnv: `POST /infra-envs`
- Get InfraEnv: `GET /infra-envs/{infraenv_id}`

## Support

- OpenShift Assisted Service: https://github.com/openshift/assisted-service
- OKD Documentation: https://docs.okd.io/
- Fedora CoreOS: https://fedoraproject.org/coreos/
