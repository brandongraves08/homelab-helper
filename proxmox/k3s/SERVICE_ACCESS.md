# K3s Homelab Services - Access Guide

**Cluster:** K3s v1.33.6+k3s1 (3-node HA)  
**Last Updated:** November 25, 2025  
**Status:** ✅ All services operational and accessible

## 🌐 Service URLs

All services are accessible via DNS at `*.thelab.lan`:

| Service | URL | Purpose | Status |
|---------|-----|---------|--------|
| **Grafana** | https://grafana.thelab.lan | Monitoring dashboards | ✅ Running |
| **Prometheus** | https://prometheus.thelab.lan | Metrics collection | ✅ Running |
| **ArgoCD** | https://argocd.thelab.lan | GitOps deployment | ✅ Running |
| **Harbor** | https://harbor.thelab.lan | Container registry | ✅ Running |
| **Vault** | https://vault.thelab.lan | Secrets management | ✅ Running (HA mode) |
| **K8s Dashboard** | https://dashboard.k3s.thelab.lan:8443 | Kubernetes UI | ✅ Running (NodePort) |

## 🔐 Access Credentials

### Grafana
- **URL:** https://grafana.thelab.lan
- **Username:** `admin`
- **Password:** Stored in Ansible Vault (see vault.yml)
- **Features:**
  - Pre-configured dashboards for Kubernetes monitoring
  - Prometheus data source integrated
  - Loki for log aggregation
  - AlertManager for alerts

### ArgoCD
- **URL:** https://argocd.thelab.lan
- **Username:** `admin`
- **Password:** Stored in Ansible Vault (see vault.yml)
- **CLI Login:**
  ```bash
  ARGOCD_PASS=$(ansible-vault view vault.yml | grep argocd_admin_password | awk '{print $2}')
  argocd login argocd.thelab.lan --username admin --password "$ARGOCD_PASS" --insecure
  ```
- **Delete Initial Secret After First Login:**
  ```bash
  kubectl delete secret argocd-initial-admin-secret -n argocd
  ```

### Harbor
- **URL:** https://harbor.thelab.lan
- **Username:** `admin`
- **Password:** Stored in Ansible Vault (see vault.yml)
- **Features:**
  - Container image registry
  - Vulnerability scanning (Trivy)
  - Image signing and replication
  - Helm chart repository

### Vault
- **URL:** https://vault.thelab.lan
- **Root Token:** Stored in Ansible Vault (see vault.yml)
- **Unseal Key:** Stored in Ansible Vault (see vault.yml)
- **Status:** 3-node HA cluster (all pods unsealed)
  - vault-0: Active (leader)
  - vault-1: Standby
  - vault-2: Standby
- **CLI Access:**
  ```bash
  export VAULT_ADDR=https://vault.thelab.lan
  export VAULT_TOKEN=$(ansible-vault view vault.yml | grep vault_root_token | awk '{print $2}')
  vault status
  ```

### Kubernetes Dashboard
- **URL:** https://dashboard.k3s.thelab.lan:8443
- **Access Token:** Generate with:
  ```bash
  kubectl -n kubernetes-dashboard create token admin-user
  ```

### Prometheus
- **URL:** https://prometheus.thelab.lan
- **Authentication:** None (direct access)
- **Features:**
  - Metrics from all K3s nodes
  - Service discovery for pods and services
  - AlertManager integration

## 🔧 Technical Details

### Ingress Configuration
- **Controller:** Traefik (K3s default)
- **LoadBalancer IPs:** 192.168.2.250, 192.168.2.251, 192.168.2.252
- **HTTP Port:** 80
- **HTTPS Port:** 443
- **All ingresses use:** `ingressClassName: traefik`

### DNS Configuration
- **DNS Server:** UniFi Dream Machine (192.168.2.1)
- **Domain:** thelab.lan
- **Records:** Automated via UniFi REST API
- **Documentation:** See [UNIFI_DNS_AUTOMATION.md](./UNIFI_DNS_AUTOMATION.md)

### Network Topology
```
User Browser
    ↓
DNS Resolution (UniFi @ 192.168.2.1)
    ↓
service.thelab.lan → 192.168.2.250
    ↓
Traefik LoadBalancer (any K3s node: .250/.251/.252)
    ↓
Traefik Ingress Controller
    ↓
Service ClusterIP
    ↓
Application Pods
```

## 📦 Storage

### NFS Provisioner
- **StorageClass:** `nfs-client`
- **NFS Server:** 192.168.2.79 (bastion host)
- **Path:** `/mnt/nfs-storage`
- **Status:** ✅ Operational

### Persistent Volume Claims
```bash
# List all PVCs
kubectl get pvc -A

# Common PVCs:
# - Harbor: database, redis, registry, trivy
# - Grafana: storage
# - Prometheus: server, alertmanager
# - Vault: vault-data-vault-0/1/2
```

## 🔄 Service Management

### View All Services
```bash
export KUBECONFIG=~/.kube/k3s-config

# All pods
kubectl get pods -A

# All services
kubectl get svc -A

# All ingresses
kubectl get ingress -A
```

### Restart Services
```bash
# Restart deployment
kubectl rollout restart deployment <deployment-name> -n <namespace>

# Examples:
kubectl rollout restart deployment prometheus-grafana -n monitoring
kubectl rollout restart deployment argocd-server -n argocd
```

### Check Logs
```bash
# View logs
kubectl logs -n <namespace> <pod-name>

# Follow logs
kubectl logs -n <namespace> <pod-name> -f

# All containers in pod
kubectl logs -n <namespace> <pod-name> --all-containers
```

## 🚨 Vault Operations

### Seal/Unseal Vault
```bash
export KUBECONFIG=~/.kube/k3s-config
UNSEAL_KEY=$(ansible-vault view vault.yml | grep vault_unseal_key | awk '{print $2}')

# Check status
kubectl exec -n vault vault-0 -- vault status

# Unseal all pods (if sealed after restart)
for i in 0 1 2; do
  kubectl exec -n vault vault-$i -- vault operator unseal $UNSEAL_KEY
done
```

### Vault HA Status
```bash
# Check which pod is active
kubectl exec -n vault vault-0 -- vault status | grep "HA Mode"
kubectl exec -n vault vault-1 -- vault status | grep "HA Mode"
kubectl exec -n vault vault-2 -- vault status | grep "HA Mode"
```

## 🔐 Security Notes

**⚠️ IMPORTANT - Change Default Passwords!**

These services have default passwords that should be changed:

1. **Grafana:** Change `admin/admin` after first login
2. **Harbor:** Change `admin/admin` in Harbor UI → Users
3. **ArgoCD:** Change password with:
   ```bash
   argocd account update-password --current-password KaEttldtDQmUanKy
   ```

**🔒 Secure Credential Storage**

- Vault credentials stored in: `/tmp/vault-keys.json`, `/tmp/vault-unseal-key.txt`, `/tmp/vault-root-token.txt`
- **Action Required:** Move these to secure location (Ansible Vault, password manager, etc.)
- Consider using Kubernetes External Secrets Operator to sync from Vault

## 📊 Monitoring

### Grafana Dashboards

**35+ Pre-configured Dashboards Available!**

Access at: https://grafana.thelab.lan

#### Featured Dashboards:

**Cluster Overview:**
- **K3s Cluster Overview** - Custom K3s-specific metrics (nodes, pods, CPU, memory)
- **Kubernetes Cluster** - Overall cluster health and performance
- **Kubernetes Cluster (Prometheus)** - Detailed Prometheus metrics

**Compute Resources:**
- **Kubernetes / Compute Resources / Cluster** - Cluster-wide resource utilization
- **Kubernetes / Compute Resources / Namespace (Pods)** - Pod resources by namespace
- **Kubernetes / Compute Resources / Node (Pods)** - Per-node pod resources
- **Kubernetes / Compute Resources / Pod** - Individual pod metrics
- **Kubernetes / Compute Resources / Workload** - Deployment/StatefulSet/DaemonSet metrics

**Networking:**
- **Kubernetes / Networking / Cluster** - Cluster network bandwidth and errors
- **Kubernetes / Networking / Namespace (Pods)** - Network metrics by namespace
- **Kubernetes / Networking / Pod** - Per-pod network statistics

**Node Monitoring:**
- **Node Exporter Full** - Comprehensive node metrics (CPU, memory, disk, network)
- **Node Exporter / Nodes** - Multi-node overview
- **Node Exporter / USE Method / Cluster** - Utilization, Saturation, Errors methodology

**Infrastructure Components:**
- **Kubernetes / API server** - API server performance and requests
- **Kubernetes / Kubelet** - Kubelet metrics from all nodes
- **Kubernetes / Controller Manager** - Controller health
- **Kubernetes / Scheduler** - Scheduler performance
- **Kubernetes / Proxy** - kube-proxy metrics
- **Kubernetes / Persistent Volumes** - PV/PVC usage and performance
- **etcd** - Embedded etcd cluster metrics
- **CoreDNS** - DNS query performance

**Application Services:**
- **Kubernetes Deployment Statefulset Daemonset metrics** - Workload-specific dashboards
- **Prometheus / Overview** - Prometheus server performance
- **Alertmanager / Overview** - Alert status and history
- **Grafana Overview** - Grafana server metrics

#### Quick Start Guide:

1. **Login:** https://grafana.thelab.lan (admin/admin)
2. **Browse Dashboards:** Click "Dashboards" → "Browse"
3. **Start with:** "K3s Cluster Overview" or "Kubernetes Cluster"
4. **Explore by Category:** Filter by tags (kubernetes, node-exporter, prometheus)

#### Customization:

All dashboards are editable. To customize:
- Click dashboard title → "Settings" → "JSON Model"
- Save as new dashboard: "Save As..." → New name
- Create folders: "Dashboards" → "New Folder"

### Prometheus Targets
- K3s API server
- Kubelet (all nodes)
- cAdvisor (container metrics)
- Node exporters
- Application pods with `/metrics` endpoints

### AlertManager
- Integrated with Prometheus
- Alerts for node down, high memory/CPU, pod crashes
- Configure notifications in Grafana → Alerting

## 🔄 GitOps with ArgoCD

### Deploy Application
```bash
# Via CLI
argocd app create myapp \
  --repo https://github.com/user/repo \
  --path kubernetes/manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Via UI
# 1. Login to https://argocd.thelab.lan
# 2. Click "New App"
# 3. Fill in Git repo details
# 4. Click "Create"
```

### Sync Applications
```bash
# Sync specific app
argocd app sync myapp

# Sync all apps
argocd app sync --all
```

## 🐳 Container Registry (Harbor)

### Push Images
```bash
# Login
docker login harbor.thelab.lan -u admin -p admin

# Tag image
docker tag myimage:latest harbor.thelab.lan/library/myimage:latest

# Push
docker push harbor.thelab.lan/library/myimage:latest
```

### Configure K3s to Use Harbor
```bash
# Create registry secret
HARBOR_PASS=$(ansible-vault view vault.yml | grep harbor_admin_password | awk '{print $2}')
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.thelab.lan \
  --docker-username=admin \
  --docker-password="$HARBOR_PASS" \
  --docker-email=admin@thelab.lan

# Use in pod spec
spec:
  imagePullSecrets:
  - name: harbor-registry
  containers:
  - name: myapp
    image: harbor.thelab.lan/library/myimage:latest
```

## 🎯 Next Steps

### Immediate Actions
1. ✅ Change all default passwords
2. ✅ Securely store Vault credentials
3. ✅ Delete ArgoCD initial secret
4. ✅ Configure Grafana email notifications
5. ✅ Set up Harbor vulnerability scanning

### Short-term (Week 1)
- Deploy applications via ArgoCD
- Configure Vault policies and secrets
- Set up backup schedules for Vault and databases
- Configure AlertManager notifications
- Create custom Grafana dashboards

### Long-term (Month 1)
- Implement cert-manager for TLS certificates
- Deploy additional applications (Jellyfin, Sonarr, Radarr, etc.)
- Configure Vault Kubernetes auth
- Set up external-secrets-operator
- Implement proper RBAC policies
- Configure log aggregation with Loki

## 📚 Related Documentation

- [K3s Deployment Guide](./README.md)
- [UniFi DNS Automation](./UNIFI_DNS_AUTOMATION.md)
- [DNS and Ingress Status](./DNS_AND_INGRESS_STATUS.md)
- [Deployment State](./K3S_DEPLOYMENT_STATE.md)
- [Quick Reference](./QUICK_REFERENCE.md)

## 🆘 Troubleshooting

### Service Not Accessible
```bash
# Check DNS resolution
nslookup service.thelab.lan 192.168.2.1

# Check ingress
kubectl get ingress -n <namespace>

# Check service
kubectl get svc -n <namespace>

# Check pods
kubectl get pods -n <namespace>

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50
```

### Pod Not Starting
```bash
# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n <namespace>
```

### Storage Issues
```bash
# Check PVC status
kubectl get pvc -A

# Check NFS provisioner
kubectl logs -n kube-system -l app=nfs-client-provisioner

# Test NFS mount
ssh centos@192.168.2.250 "sudo mount -t nfs 192.168.2.79:/mnt/nfs-storage /mnt/test"
```

---

**Cluster Information:**
- Nodes: k3s-server-1 (192.168.2.250), k3s-server-2 (192.168.2.251), k3s-server-3 (192.168.2.252)
- Kubernetes Version: v1.33.6+k3s1
- CNI: Flannel
- Ingress: Traefik
- Storage: NFS (bastion) + Local
- Last Updated: November 25, 2025 03:55 UTC
