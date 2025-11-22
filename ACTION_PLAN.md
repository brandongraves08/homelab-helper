# Homelab Enhancement Action Plan

## Phase 1: Foundation - Storage & Observability

### 1.1 Synology NAS Integration with OKD

**Objective**: Connect existing Synology NAS to provide persistent storage for OKD workloads

**Prerequisites**:
- Synology NAS IP address and credentials
- NFS enabled on Synology
- Network connectivity between OKD node (192.168.2.252) and Synology

**Required Information** (to gather):
- [ ] Synology NAS IP address
- [ ] NFS export paths configured on Synology
- [ ] SMB/CIFS share details (if using SMB)
- [ ] Synology admin credentials for configuration
- [ ] Storage quota limits per share

**Tasks**:
1. **Configure NFS Exports on Synology**
   - Create dedicated NFS share for OKD persistent volumes
   - Set permissions for OKD node IP
   - Configure export options (rw,sync,no_subtree_check)
   - Document share paths

2. **Install NFS CSI Driver on OKD**
   - Deploy NFS Subdir External Provisioner
   - Create StorageClass for dynamic provisioning
   - Set as default storage class (optional)
   - Test with sample PVC

3. **Create Storage Classes**
   - `nfs-synology` - General purpose storage
   - `nfs-synology-retain` - For persistent data (retain policy)
   - `nfs-synology-backup` - For backup volumes

4. **Validate Storage**
   - Deploy test pod with PVC
   - Verify data persistence
   - Test read/write performance
   - Document IOPS and throughput benchmarks

**Deliverables**:
- `storage/synology-nfs/` directory with:
  - `deployment.yml` - NFS provisioner deployment
  - `storageclass.yml` - Storage class definitions
  - `test-pvc.yml` - Test persistent volume claim
  - `README.md` - Setup and usage documentation
- Updated `ARCHITECTURE.md` with storage topology

**Estimated Time**: 2-3 hours

---

### 1.2 Monitoring Stack (Prometheus + Grafana)

**Objective**: Deploy comprehensive monitoring for Proxmox, OKD cluster, and workloads

**Prerequisites**:
- OKD cluster accessible via kubectl/oc
- Sufficient resources on OKD node (will use ~2GB RAM, 2 vCPU)

**Required Information** (to gather):
- [ ] Proxmox API token for metrics collection
- [ ] UniFi Controller URL and admin credentials
- [ ] UniFi API credentials (username/password or API token)
- [ ] Alert notification preferences (email, Slack, etc.)
- [ ] Retention period for metrics (default: 15 days)
- [ ] Grafana admin password preference

**Tasks**:

1. **Deploy kube-prometheus-stack**
   - Install via Helm or OpenShift Operator
   - Configure persistent storage (using Synology NFS)
   - Set resource limits and requests
   - Configure service monitors

2. **Deploy Netdata**
   - Install Netdata on Proxmox host for real-time system monitoring
   - Deploy Netdata agent on OKD node
   - Configure Netdata parent-child streaming
   - Set up Netdata dashboard access
   - Configure alerts and notifications
   - Integrate with Prometheus (export metrics)

3. **Proxmox Monitoring**
   - Deploy Proxmox exporter (on Proxmox host or sidecar)
   - Configure metrics scraping
   - Create Proxmox dashboard in Grafana
   - Monitor: CPU, RAM, disk, network, VM status
   - Integrate Netdata metrics

3a. **UniFi Network Monitoring**
   - Deploy UniFi Poller or similar exporter
   - Configure UniFi Controller API access
   - Pull network statistics and device metrics
   - Create UniFi dashboard in Grafana
   - Monitor: bandwidth usage, connected clients, device health, WAN status
   - Track DHCP lease information
   - Visualize network topology

4. **OKD Cluster Monitoring**
   - Enable built-in OpenShift monitoring (if not already)
   - Configure cluster metrics retention
   - Create cluster health dashboard
   - Monitor: node resources, pod status, etcd health, API latency
   - Deploy Netdata DaemonSet for per-pod visibility

5. **Custom Dashboards**
   - Homelab Overview (all infrastructure)
   - OKD Workload Dashboard
   - Storage Usage Dashboard
   - Network Traffic Dashboard (UniFi data)
   - UniFi Network Health Dashboard
   - Netdata integration dashboard

6. **Alerting Rules**
   - Node down alerts
   - High CPU/memory usage
   - Disk space warnings (>80%, >90%)
   - OKD pod restart loops
   - Certificate expiration warnings

7. **Grafana Setup**
   - Configure authentication
   - Set up dashboards
   - Configure alert channels
   - Create API keys for automation
   - Add Netdata as data source

**Deliverables**:
- `monitoring/netdata/` directory with:
  - `install-proxmox.sh` - Netdata installation for Proxmox host
  - `daemonset.yml` - Netdata DaemonSet for OKD
  - `config/` - Netdata configuration files
  - `README.md` - Setup and access guide
- `monitoring/prometheus/` directory with:
  - `kube-prometheus-stack-values.yml` - Helm values
  - `proxmox-exporter.yml` - Proxmox metrics exporter
  - `unifi-poller.yml` - UniFi metrics exporter
  - `servicemonitor-*.yml` - Service monitor configs
  - `servicemonitor-netdata.yml` - Netdata metrics integration
  - `servicemonitor-unifi.yml` - UniFi metrics integration
  - `alertrules.yml` - Custom alert rules
- `monitoring/grafana/dashboards/` - JSON dashboard exports
  - `homelab-overview.json` - Main dashboard
  - `unifi-network.json` - Network monitoring dashboard
- `monitoring/unifi/` directory with:
  - `api-credentials.yml` - UniFi API credentials (vault encrypted)
  - `data-collector.py` - Script to pull UniFi data
  - `README.md` - API usage guide
- `monitoring/README.md` - Access info and usage guide

**Estimated Time**: 6-8 hours

---

### 1.3 Automated Backups to Synology

**Objective**: Implement automated backup strategy for VMs, OKD etcd, and critical data

**Prerequisites**:
- Synology NAS with backup target share
- Sufficient storage space on NAS
- Backup credentials

**Required Information** (to gather):
- [ ] Synology backup share path
- [ ] Backup retention policy (how many backups to keep)
- [ ] Backup schedule preferences (daily? weekly?)
- [ ] Backup notification email/webhook

**Tasks**:

1. **Proxmox VM Backups**
   - Create backup script using `vzdump`
   - Configure backup to NFS mount (Synology)
   - Set compression and retention policy
   - Create systemd timer for scheduling
   - Test backup and restore procedure

2. **OKD etcd Backups**
   - Create CronJob for etcd snapshots
   - Store backups on Synology NFS PVC
   - Implement backup rotation (keep last 7 daily, 4 weekly)
   - Document restore procedure

3. **Application Data Backups**
   - Velero installation for cluster backups
   - Configure Synology as backup target
   - Schedule cluster resource backups
   - Test application restore scenarios

4. **Configuration Backups**
   - Ansible playbooks backup
   - Vault files backup (encrypted)
   - Scripts and automation backup
   - Git-based backup for code (already covered by git)

5. **Backup Monitoring**
   - Prometheus metrics for backup jobs
   - Grafana dashboard for backup status
   - Alert on backup failures
   - Weekly backup report

**Deliverables**:
- `backup/proxmox/` directory with:
  - `vm-backup.sh` - VM backup script
  - `vm-backup.timer` - Systemd timer unit
  - `restore-vm.md` - Restore documentation
- `backup/okd/etcd/` directory with:
  - `etcd-backup-cronjob.yml` - Kubernetes CronJob
  - `etcd-restore.md` - Restore procedure
- `backup/velero/` directory with:
  - `velero-install.sh` - Velero installation
  - `backup-schedule.yml` - Backup schedules
- `backup/README.md` - Backup strategy overview

**Estimated Time**: 4-5 hours

---

### 1.4 Certificate Management (cert-manager)

**Objective**: Automate TLS certificate management for OKD services

**Prerequisites**:
- OKD cluster with ingress/routes
- Domain name (thelab.lan)
- DNS control for validation

**Required Information** (to gather):
- [ ] External domain name (if using Let's Encrypt)
- [ ] DNS provider credentials (for DNS-01 challenge)
- [ ] Or: HTTP-01 challenge preference (if ports 80/443 accessible)
- [ ] Certificate notification email

**Tasks**:

1. **Install cert-manager**
   - Deploy cert-manager operator on OKD
   - Create ClusterIssuer resources
   - Configure ACME/Let's Encrypt (if external domain)
   - Or: Create self-signed CA for internal lab

2. **Configure Issuers**
   - ClusterIssuer for Let's Encrypt (production)
   - ClusterIssuer for Let's Encrypt (staging/testing)
   - ClusterIssuer for internal CA (lab services)

3. **Certificate Automation**
   - Annotate ingress/routes for auto-cert
   - Create Certificate resources for services
   - Configure automatic renewal
   - Set up expiration monitoring

4. **Internal CA Setup** (for lab domain)
   - Generate root CA certificate
   - Store CA cert in OKD secrets
   - Distribute CA cert to workstations
   - Document CA trust installation

5. **Certificate Monitoring**
   - Prometheus metrics for cert expiration
   - Grafana dashboard for certificate status
   - Alerts for expiring certificates (30 days)

**Deliverables**:
- `certs/cert-manager/` directory with:
  - `install.sh` - cert-manager installation
  - `clusterissuer-letsencrypt.yml` - Let's Encrypt issuer
  - `clusterissuer-internal.yml` - Internal CA issuer
  - `example-certificate.yml` - Sample certificate request
- `certs/internal-ca/` - Internal CA setup scripts
- `certs/README.md` - Usage documentation

**Estimated Time**: 3-4 hours

---

## Phase 2: Development Platform

### 2.1 GitOps with ArgoCD

**Objective**: Implement GitOps workflow for declarative OKD application deployment

**Prerequisites**:
- OKD cluster accessible
- Git repository for manifests
- Basic understanding of Kubernetes resources

**Required Information** (to gather):
- [ ] Git repository URL for app manifests
- [ ] Git credentials/SSH key
- [ ] Webhook URL for auto-sync (optional)
- [ ] RBAC/access control requirements

**Tasks**:

1. **Install ArgoCD**
   - Deploy ArgoCD on OKD
   - Configure ingress/route
   - Set admin password
   - Configure SSO (optional)

2. **Repository Setup**
   - Create Git repo structure for apps
   - Define directory structure (apps/, clusters/, base/, overlays/)
   - Create initial application manifests
   - Set up branch protection

3. **Application Configuration**
   - Create ArgoCD Application resources
   - Configure sync policies (auto vs manual)
   - Set up health checks
   - Define sync waves for dependencies

4. **Project Structure**
   - ArgoCD Projects for namespaces
   - RBAC policies
   - Resource whitelist/blacklist
   - Source repository restrictions

5. **CI/CD Integration**
   - Webhook configuration for auto-sync
   - Image updater setup (optional)
   - Notification configuration
   - Integration with monitoring

**Deliverables**:
- `gitops/argocd/` directory with:
  - `install.yml` - ArgoCD installation
  - `projects/` - Project definitions
  - `applications/` - App definitions
  - `README.md` - GitOps workflow guide
- Separate Git repo for manifests (or subdirectory)

**Estimated Time**: 3-4 hours

---

### 2.2 Container Registry (Harbor)

**Objective**: Deploy self-hosted container registry for private images

**Prerequisites**:
- OKD cluster with sufficient storage
- Synology NFS storage configured
- TLS certificates (from cert-manager)

**Required Information** (to gather):
- [ ] Registry hostname (e.g., registry.thelab.lan)
- [ ] Admin password preference
- [ ] Storage quota for registry
- [ ] Image retention policy

**Tasks**:

1. **Deploy Harbor**
   - Install Harbor operator or Helm chart
   - Configure PostgreSQL backend
   - Set up Redis cache
   - Configure persistent storage (Synology NFS)

2. **TLS Configuration**
   - Create certificate via cert-manager
   - Configure Harbor ingress with TLS
   - Trust internal CA on build machines

3. **Project Setup**
   - Create registry projects
   - Configure access control
   - Set up robot accounts
   - Define vulnerability scanning policies

4. **Integration**
   - Configure OKD to pull from Harbor
   - Create image pull secrets
   - Set up replication (if multi-cluster later)
   - Configure webhook notifications

5. **Vulnerability Scanning**
   - Enable Trivy scanner
   - Configure scan policies
   - Set up scan schedules
   - Create alerts for critical CVEs

**Deliverables**:
- `registry/harbor/` directory with:
  - `harbor-values.yml` - Helm values
  - `projects.yml` - Project configurations
  - `robot-accounts.sh` - Account creation script
  - `README.md` - Usage guide

**Estimated Time**: 4-5 hours

---

### 2.3 CI/CD Pipeline (Tekton)

**Objective**: Deploy cloud-native CI/CD pipeline on OKD

**Prerequisites**:
- OKD cluster
- Harbor registry deployed
- ArgoCD deployed
- Git repository for source code

**Required Information** (to gather):
- [ ] Git repository URLs for projects
- [ ] Build resource requirements
- [ ] Pipeline trigger preferences (webhook, polling)
- [ ] Notification preferences

**Tasks**:

1. **Install Tekton**
   - Deploy Tekton Pipelines operator
   - Install Tekton Triggers
   - Install Tekton Dashboard
   - Configure RBAC

2. **Create Pipeline Templates**
   - Clone task
   - Build image task (buildah/kaniko)
   - Push to Harbor task
   - Deploy via ArgoCD task
   - Test task templates

3. **Pipeline Examples**
   - Simple web app pipeline
   - Microservice pipeline
   - Helm chart pipeline
   - Pipeline with quality gates

4. **Trigger Configuration**
   - GitHub/GitLab webhook triggers
   - EventListeners
   - TriggerBindings and TriggerTemplates
   - Secret management for webhooks

5. **Pipeline Storage**
   - Configure workspace PVCs
   - Set up caching for builds
   - Configure artifact retention
   - Cleanup policies

**Deliverables**:
- `cicd/tekton/` directory with:
  - `tasks/` - Reusable task definitions
  - `pipelines/` - Pipeline definitions
  - `triggers/` - Webhook trigger configs
  - `examples/` - Sample pipelines
  - `README.md` - Pipeline usage guide

**Estimated Time**: 5-6 hours

---

## Phase 3: Applications & Media Services

### 3.1 Database Operator (PostgreSQL)

**Objective**: Deploy PostgreSQL operator for managed database instances

**Prerequisites**:
- OKD cluster
- Synology NFS storage
- Backup strategy

**Required Information** (to gather):
- [ ] Database resource requirements
- [ ] Backup retention for databases
- [ ] High availability requirements (single vs replicated)

**Tasks**:

1. **Install PostgreSQL Operator**
   - Deploy CloudNativePG or Crunchy operator
   - Configure storage class
   - Set resource defaults
   - Configure backup storage

2. **Create Database Templates**
   - Development database template
   - Production database template
   - Backup and restore procedures
   - Connection pooling configuration

3. **Backup Configuration**
   - Configure WAL archiving to Synology
   - Set up scheduled backups
   - Test restore procedures
   - Document recovery time objectives

4. **Monitoring Integration**
   - PostgreSQL exporter deployment
   - Grafana dashboards for databases
   - Alert rules for database health
   - Query performance monitoring

5. **Example Deployments**
   - Sample application with PostgreSQL
   - Connection secret management
   - Migration job examples

**Deliverables**:
- `databases/postgresql/` directory with:
  - `operator-install.yml` - Operator deployment
  - `cluster-templates/` - Database cluster templates
  - `backup-config.yml` - Backup configuration
  - `monitoring/` - Prometheus rules and Grafana dashboards
  - `README.md` - Usage guide

**Estimated Time**: 4-5 hours

---

### 3.2 Media Management Stack

**Objective**: Deploy media automation and streaming services on OKD

**Prerequisites**:
- OKD cluster with storage
- Certificate management
- Ingress configured
- Synology NFS storage mounted
- Sufficient storage for media library

**Applications to Deploy**:

#### 3.2.1 Jellyfin (Media Server)
- Video streaming and transcoding
- Persistent storage for media library (Synology NFS)
- Hardware acceleration (if available)
- Multi-user support with authentication

#### 3.2.2 Sonarr (TV Series Management)
- Automated TV show downloading
- Integration with download clients
- Calendar and episode tracking
- Metadata management

#### 3.2.3 Radarr (Movie Management)
- Automated movie downloading
- Quality profiles and monitoring
- Integration with download clients
- Collection management

**Required Information** (to gather):
- [ ] Media library location on Synology NAS
- [ ] Download client details (transmission, qbittorrent, etc.)
- [ ] Indexer/tracker credentials
- [ ] Preferred quality profiles
- [ ] Storage quotas for media
- [ ] Transcoding preferences for Jellyfin

**Tasks**:

1. **Storage Configuration**
   - Create NFS PVCs for media libraries
   - Set up download directories
   - Configure permissions for media access
   - Plan directory structure (tv/, movies/, downloads/)

2. **Deploy Jellyfin**
   - Create namespace: `media-jellyfin`
   - Deploy Jellyfin with persistent storage
   - Configure media library paths
   - Set up transcoding cache
   - Configure user accounts

3. **Deploy Sonarr**
   - Create namespace: `media-sonarr`
   - Deploy Sonarr with config storage
   - Configure root folders on Synology
   - Connect to download client
   - Add indexers/trackers
   - Configure quality profiles

4. **Deploy Radarr**
   - Create namespace: `media-radarr`
   - Deploy Radarr with config storage
   - Configure root folders on Synology
   - Connect to download client
   - Add indexers/trackers
   - Configure quality profiles

5. **Integration**
   - Connect Sonarr/Radarr to Jellyfin libraries
   - Test automatic media import
   - Configure post-processing
   - Set up file permissions

6. **TLS & Access**
   - Request certificates via cert-manager
   - Configure routes/ingress:
     - jellyfin.thelab.lan
     - sonarr.thelab.lan
     - radarr.thelab.lan
   - Test HTTPS access

7. **Monitoring**
   - Add to Prometheus monitoring
   - Create Grafana dashboard for media services
   - Set up alerts for service health
   - Monitor storage usage

**Deliverables**:
- `apps/media/jellyfin/` directory with:
  - `deployment.yml` - Jellyfin deployment
  - `pvc.yml` - Storage claims
  - `route.yml` - Ingress configuration
  - `README.md` - Setup and usage guide
- `apps/media/sonarr/` directory with similar structure
- `apps/media/radarr/` directory with similar structure
- `apps/media/README.md` - Media stack overview and integration guide

**Estimated Time**: 6-8 hours

**Notes**:
- Consider deploying a download client (qBittorrent, Transmission) if not already available
- May need VPN integration for download client depending on use case
- Hardware transcoding in Jellyfin requires GPU passthrough to container (advanced topic)

---

### 3.3 Development Namespaces

**Objective**: Create isolated development environments in OKD

**Prerequisites**:
- OKD cluster
- RBAC understanding
- Resource quota planning

**Tasks**:

1. **Namespace Templates**
   - Create namespace with quotas
   - Set up network policies
   - Configure default limits
   - Add service accounts

2. **Developer Access**
   - Create developer role bindings
   - Set up kubeconfig contexts
   - Document access procedures
   - Create onboarding guide

3. **Resource Quotas**
   - CPU limits per namespace
   - Memory limits per namespace
   - Storage limits per namespace
   - Pod count limits

4. **Network Policies**
   - Isolate namespace traffic
   - Allow egress to specific services
   - Document network rules

5. **Tools and Utilities**
   - Deploy sample applications
   - Set up debug pods
   - Install CLI tools
   - Create helper scripts

**Deliverables**:
- `environments/dev-namespaces/` directory with:
  - `namespace-template.yml` - Template with quotas
  - `rbac.yml` - Role bindings
  - `network-policies.yml` - Network isolation
  - `tools/` - Helper scripts
  - `README.md` - Developer guide

**Estimated Time**: 3-4 hours

---

## Phase 4: Advanced Topics (Future)

### 4.1 Multi-Cluster Setup
- Additional OKD cluster for HA testing
- Cluster federation
- Multi-cluster service mesh

### 4.2 Chaos Engineering
- LitmusChaos deployment
- Resilience testing
- Failure scenario automation

### 4.3 Advanced Networking
- Service mesh (Istio/Linkerd)
- VLAN segmentation
- Advanced ingress patterns

---

## Resource Requirements Summary

### Storage (Synology NFS)
- Persistent volumes: ~100GB initial, expandable
- Backups: ~200GB (VM backups + etcd + apps)
- Container registry: ~50GB initial
- Application data: ~50GB
- Media library: Variable (plan for 500GB-2TB+ depending on collection size)

**Total**: ~400GB base + media storage (recommend 1TB+ available for media)

### OKD Node Resources
Current: 8 cores, 16GB RAM, 100GB disk

Additional recommended:
- Monitoring stack: 2 cores, 4GB RAM
- Harbor registry: 1 core, 2GB RAM
- Tekton pipelines: 2 cores (burst), 2GB RAM
- Applications: 2 cores, 4GB RAM

**Recommendation**: Consider increasing to 12-16 cores, 24-32GB RAM for Phase 2+

### Network
- Bandwidth: Gigabit LAN sufficient
- Latency: <1ms to Synology NAS
- Firewall rules: May need UDM configuration for external access

---

## Prerequisites Checklist

Before starting Phase 1:

- [ ] Bastion host deployed and accessible (IP address assigned)
- [ ] Bastion host has SSH keys configured for Proxmox and OKD access
- [ ] homelab-helper repository cloned on bastion host
- [ ] Python and Ansible installed on bastion host
- [ ] OKD cluster is healthy and accessible from bastion
- [ ] `oc` or `kubectl` CLI configured on bastion
- [ ] Synology NAS accessible from OKD node and bastion
- [ ] Proxmox API access credentials
- [ ] DNS records can be created/modified on UDM
- [ ] Sufficient storage on Synology (~400GB free)
- [ ] Git repository for configuration (can use existing homelab-helper)
- [ ] Backup strategy agreed upon (retention, schedules)

---

## Risk Assessment

### High Risk
- **OKD cluster instability**: Single node = single point of failure
  - Mitigation: Comprehensive backups, documented restore procedures
  
### Medium Risk
- **Storage performance**: NFS latency for database workloads
  - Mitigation: Benchmark before deploying databases, consider local storage for high I/O
  
- **Resource exhaustion**: Limited CPU/RAM on single node
  - Mitigation: Resource quotas, monitoring, alerts

### Low Risk
- **Certificate expiration**: Automated renewals may fail
  - Mitigation: Monitoring and alerts, manual renewal procedures

---

## Success Metrics

### Phase 1
- [ ] OKD can provision PVCs on Synology NFS
- [ ] Netdata deployed on Proxmox and OKD nodes with real-time monitoring
- [ ] Grafana dashboards showing cluster and Proxmox metrics
- [ ] Netdata metrics integrated with Prometheus
- [ ] Automated daily backups running successfully
- [ ] TLS certificates issued and auto-renewing

### Phase 2
- [ ] Application deployed via ArgoCD GitOps
- [ ] Container image built and pushed to Harbor
- [ ] Tekton pipeline executing successfully
- [ ] All components integrated and monitored

### Phase 3
- [ ] Media stack deployed (Jellyfin, Sonarr, Radarr)
- [ ] PostgreSQL operator managing database instances
- [ ] Development namespaces in use
- [ ] All services accessible via HTTPS with valid certificates
- [ ] Media automation working end-to-end

---

## Estimated Total Time

- **Phase 1**: 15-20 hours
- **Phase 2**: 12-15 hours
- **Phase 3**: 14-18 hours

**Total**: 41-53 hours of focused work

Suggested schedule: 2-3 hours per session, 2-3 sessions per week = 6-8 weeks to complete all phases

**Note**: Wiki, password manager, and Git services are hosted in cloud, not included in this plan.

---

## Next Steps

1. **Review this plan** - Validate assumptions and requirements
2. **Gather prerequisites** - Collect all required information (IPs, credentials, etc.)
3. **Set up project structure** - Create directories in homelab-helper repo
4. **Begin Phase 1.1** - Start with Synology NFS integration
5. **Document as you go** - Update docs with actual IPs, configurations, gotchas

---

## Questions to Answer Before Starting

1. What is your Synology NAS IP address and model?
2. Do you have an external domain name, or only using thelab.lan internally?
3. What are your backup retention preferences (daily for X days, weekly for Y weeks)?
4. Do you want email/Slack notifications for alerts, or just Grafana dashboards?
5. Is the OKD cluster installation complete and stable?
6. Can you allocate more resources to the OKD VM if needed?
7. What applications are highest priority for Phase 3?

---

_This action plan will be updated as work progresses and new requirements are discovered._
