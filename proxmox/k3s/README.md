# K3s Kubernetes Cluster on Proxmox

**Status:** ✅ **OPERATIONAL** (2-node HA cluster)  
**Deployment Date:** November 24, 2025  
**Current State:** See [K3S_DEPLOYMENT_STATE.md](./K3S_DEPLOYMENT_STATE.md) for full details

**Deployment Method:** K3s Lightweight Kubernetes  
**Version:** v1.33.6+k3s1  
**Active Nodes:** 2 servers (k3s-server-1, k3s-server-2)  
**Target:** 3-node High Availability cluster with embedded etcd  
**Hypervisor:** Proxmox VE 8.x  
**Bastion:** rhel-01.thelab.lan (192.168.2.79)

## Why K3s Instead of OKD?

After extensive troubleshooting with OKD 4.20:
- ❌ OKD agent-based installation has circular dependency issues
- ❌ OKD UPI requires complex ignition configuration with UEFI/fw_cfg issues
- ❌ OKD bootstrap process is fragile and difficult to troubleshoot
- ✅ K3s is battle-tested, lightweight (<100MB binary)
- ✅ K3s installation is simple: one curl command
- ✅ K3s has embedded etcd for HA without external datastore
- ✅ K3s includes Traefik ingress and local storage out of the box
- ✅ K3s is perfect for homelab environments

## Architecture

### Cluster Topology
```
3-Node HA Cluster with Embedded etcd:
- k3s-server-1: 192.168.2.250 (control plane + worker)
- k3s-server-2: 192.168.2.251 (control plane + worker)
- k3s-server-3: 192.168.2.252 (control plane + worker)

API Load Balancer: 192.168.2.196 (HAProxy on Proxmox host)
```

### Network Configuration
- Cluster CIDR: 10.42.0.0/16 (pods)
- Service CIDR: 10.43.0.0/16 (services)
- API Port: 6443
- Node IP Range: 192.168.2.250-252

### DNS Requirements
```
# API endpoint (load balanced)
api.k3s.thelab.lan          → 192.168.2.196

# Server nodes
k3s-server-1.thelab.lan     → 192.168.2.250
k3s-server-2.thelab.lan     → 192.168.2.251
k3s-server-3.thelab.lan     → 192.168.2.252

# Wildcard for ingress (optional)
*.k3s.thelab.lan            → 192.168.2.196
```

## VM Specifications

Each server node:
- **CPU:** 4 cores (host type with nested virtualization)
- **RAM:** 8192 MB (8 GB)
- **Disk:** 80 GB
- **OS:** CentOS Stream 9
- **Network:** DHCP reservation or static IP
- **QEMU Guest Agent:** Enabled

## Deployment Steps

### 1. Prepare VMs
```bash
# Run deployment script
./deploy-vms.sh
```

### 2. Install K3s on First Server (with cluster-init)
```bash
# SSH to first server
ssh centos@192.168.2.250

# Install K3s with embedded etcd
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --token k3s-homelab-token \
  --tls-san api.k3s.thelab.lan \
  --tls-san 192.168.2.196

# Get node token for additional servers
sudo cat /var/lib/rancher/k3s/server/node-token
```

### 3. Join Additional Servers
```bash
# SSH to second server
ssh centos@192.168.2.251

# Join cluster
curl -sfL https://get.k3s.io | K3S_TOKEN=<node-token> sh -s - server \
  --server https://192.168.2.250:6443 \
  --tls-san api.k3s.thelab.lan \
  --tls-san 192.168.2.196

# Repeat for third server
ssh centos@192.168.2.252
curl -sfL https://get.k3s.io | K3S_TOKEN=<node-token> sh -s - server \
  --server https://192.168.2.250:6443 \
  --tls-san api.k3s.thelab.lan \
  --tls-san 192.168.2.196
```

### 4. Configure kubectl Access
```bash
# From first server, copy kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > ~/k3s-kubeconfig.yaml

# Transfer to bastion
scp centos@192.168.2.250:~/k3s-kubeconfig.yaml ~/.kube/k3s-config

# Update server URL in kubeconfig
sed -i 's/127.0.0.1/api.k3s.thelab.lan/g' ~/.kube/k3s-config

# Export kubeconfig
export KUBECONFIG=~/.kube/k3s-config

# Verify cluster
kubectl get nodes
```

### 5. Configure HAProxy Load Balancer
```bash
# On Proxmox host (192.168.2.196)
./configure-haproxy.sh
```

## Included Features

K3s includes out-of-the-box:
- ✅ **Traefik Ingress Controller** - HTTP/HTTPS routing
- ✅ **Local Path Provisioner** - Dynamic PV provisioning
- ✅ **CoreDNS** - Cluster DNS
- ✅ **ServiceLB** - Basic load balancer (MetalLB alternative)
- ✅ **Network Policy Controller** - Basic network policies
- ✅ **Embedded etcd** - No external database needed

## Optional: Add Worker Nodes

K3s can scale with dedicated worker nodes:
```bash
# On worker node
curl -sfL https://get.k3s.io | K3S_URL=https://api.k3s.thelab.lan:6443 \
  K3S_TOKEN=<node-token> sh -
```

## Verification

```bash
# Check all nodes are Ready
kubectl get nodes

# Check system pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info

# Test with sample deployment
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc nginx
```

## Upgrade Procedure

```bash
# Automated upgrades with system-upgrade-controller
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/crd.yaml
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml

# Create upgrade plan
kubectl apply -f upgrade-plan.yaml
```

## Backup and Restore

K3s etcd snapshots:
```bash
# Manual snapshot
k3s etcd-snapshot save --name backup-$(date +%Y%m%d-%H%M%S)

# Automated snapshots (enabled by default every 12 hours)
# Snapshots stored in /var/lib/rancher/k3s/server/db/snapshots/

# Restore from snapshot
k3s server --cluster-reset --cluster-reset-restore-path=<snapshot-file>
```

## Monitoring

Optional monitoring stack:
```bash
# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

## Advantages Over OKD

1. **Installation:** Single curl command vs complex ignition files
2. **Size:** <100MB binary vs multi-GB ISO images
3. **Memory:** 8GB per node vs 16GB+ per node
4. **Maintenance:** Simple upgrades vs complex bootstrap/CSR processes
5. **Debugging:** Clear logs and systemd service vs opaque bootstrap failures
6. **Storage:** Built-in local-path provisioner vs manual CSI setup
7. **Ingress:** Traefik included vs manual HAProxy/router configuration

## Next Steps

1. Deploy VMs with `./deploy-vms.sh`
2. Install K3s on all three nodes
3. Configure HAProxy load balancer
4. Set up monitoring (optional)
5. Deploy applications

## References

- [K3s Official Documentation](https://docs.k3s.io/)
- [K3s Quick Start](https://docs.k3s.io/quick-start)
- [K3s HA with Embedded etcd](https://docs.k3s.io/datastore/ha-embedded)
- [K3s Architecture](https://docs.k3s.io/architecture)
