# Homelab Helper - Architecture Documentation

## Overview

Homelab Helper is an infrastructure automation system designed to manage and deploy homelab resources, with a primary focus on deploying OKD (OpenShift Kubernetes Distribution) on Proxmox virtualization platform. The system emphasizes security through Ansible Vault, automation over manual intervention, and self-service workflows.

## System Topology

```
┌─────────────────┐
│   Workstation   │
│  (WSL/Linux)    │
│                 │
│  Development    │
│  Environment    │
└────────┬────────┘
         │ SSH
         │ (port 22)
         ▼
┌─────────────────┐     ┌─────────────────┐
│  Bastion Host   │     │    Proxmox VE   │
│  (TBD IP)       │────▶│  192.168.2.196  │
│                 │ SSH │                 │
│  Management &   │     │  ┌───────────┐  │
│  Automation     │     │  │ Assisted  │  │ ← Podman containers
│  Jump Server    │     │  │ Service   │  │   - PostgreSQL (5432)
│                 │     │  │           │  │   - UI (8080)
│                 │     │  │ :8080 UI  │  │   - API (8090)
│                 │     │  │ :8090 API │  │   - Image Service (8888)
│                 │     │  │ :8888 ISO │  │
│                 │     │  └───────────┘  │
│                 │     │                 │
│                 │     │  VMs:           │
│                 │     │  ┌───────────┐  │
│                 │     │  │ OKD Node  │  │
│                 │────▶│  │ VM 150    │  │
│                 │ SSH │  │ 192.168   │  │
│                 │     │  │ .2.252    │  │
│                 │     │  └───────────┘  │
└─────────────────┘     └─────────────────┘
         │
         │ Network: 192.168.2.0/24
         │ Gateway: 192.168.2.1 (UDM)
         │ Domain: thelab.lan
         ▼
    [Internet/DNS]
```

## Network Configuration

| Component | IP Address | Hostname | Purpose |
|-----------|------------|----------|---------|
| Bastion Host | TBD | bastion.thelab.lan | Management jump server and automation host |
| Proxmox Host | 192.168.2.196 | pve | Hypervisor and assisted-service host |
| OKD Node 1 | 192.168.2.252 | okd-node-1 | Single-node OKD cluster (VM 150) |
| Gateway | 192.168.2.1 | - | UDM (UniFi Dream Machine) |
| DNS Domain | - | thelab.lan | Internal DNS zone |

### Network Details
- **Subnet**: 192.168.2.0/24
- **DHCP**: Managed by UDM
- **DNS**: Managed by UDM for thelab.lan domain
- **Cluster Network** (OKD internal): 10.128.0.0/14
- **Service Network** (OKD internal): 172.30.0.0/16

## Core Components

### 1. Workstation (Development Environment)

**Location**: WSL or Linux workstation

**Role**: Development, orchestration, and remote management interface

**Components**:
- Git repository (homelab-helper)
- Python virtualenv (`.venv/`)
- Ansible for automation
- SSH client for bastion and Proxmox access
- Scripts for deployment orchestration

**Key Files**:
- `.venv/` - Python virtual environment
- `proxmox/okd/` - OKD deployment automation
- `.github/copilot-instructions.md` - AI agent guidance

**Access Pattern**:
- SSH to bastion host for infrastructure operations
- Direct SSH to Proxmox for hypervisor management (if needed)
- All automation runs through bastion host

### 2. Bastion Host (Management & Automation Server)

**IP**: TBD  
**Hostname**: bastion.thelab.lan  
**OS**: Linux (Ubuntu/Fedora/RHEL)

**Role**: Centralized management and jump server for all homelab operations

**Services Running**:
1. **Ansible Control Node**
   - Ansible playbooks and roles
   - Vault password file (local only)
   - Inventory files for infrastructure

2. **Automation Scripts**
   - Bash scripts for common operations
   - Python automation tools
   - Cron jobs for scheduled tasks

3. **CLI Tools**
   - `kubectl`/`oc` for OKD management
   - `proxmoxer` Python library
   - Monitoring agents
   - Backup scripts

4. **Development Tools**
   - Git client
   - Text editors (vim, nano)
   - Python virtual environments

**Access Patterns**:
```bash
# From workstation to bastion
ssh user@bastion.thelab.lan

# From bastion to Proxmox
ssh root@192.168.2.196

# From bastion to OKD node
ssh core@192.168.2.252

# Run automation from bastion
ansible-playbook -i inventory.ini playbook.yml
```

**Key Directories**:
- `/opt/homelab-helper/` - Cloned automation repository
- `/etc/ansible/` - Ansible configuration
- `~/.kube/` - Kubernetes config files
- `/var/log/homelab/` - Automation logs

**Benefits**:
- Single point of access for all infrastructure
- Persistent environment for long-running operations
- Centralized credential management
- Logging and audit trail of operations
- Can run 24/7 for scheduled tasks
- Network-local for faster operations

### 3. Proxmox VE (Hypervisor & Service Host)

**IP**: 192.168.2.196  
**Hostname**: pve  
**OS**: Proxmox Virtual Environment  
**Version**: (to be documented)

**Role**: Virtualization platform and assisted-service host

**Hypervisor Technology**: KVM/QEMU-based virtualization

**Services Running**:
1. **Proxmox Hypervisor**
   - VM management via `qm` CLI
   - API endpoint (port 8006)
   - Storage: local-lvm for VMs

2. **OpenShift Assisted Installer** (Podman)
   - **PostgreSQL**: Port 5432 (cluster state database)
   - **Assisted Installer UI**: Port 8080 (web interface)
   - **Assisted Service API**: Port 8090 (REST API)
   - **Image Service**: Port 8888 (ISO generation and serving)

**Storage**:
- `/var/lib/vz/template/iso/` - ISO images
- `local-lvm` - VM disk storage

**VM Management Commands**:
```bash
# Create VM with guest agent and serial console
qm create <vmid> --name <name> --agent enabled=1 --serial0 socket ...

# Access serial console
qm terminal <vmid>

# Check guest agent status
qm guest exec <vmid> -- <command>

# VM lifecycle management
qm start <vmid>
qm stop <vmid>
qm shutdown <vmid>
qm status <vmid>

# Monitor VM resources
qm monitor <vmid>
```

**Access Patterns**:
```bash
# Direct SSH access
ssh root@192.168.2.196

# API access (from within Proxmox)
curl http://127.0.0.1:8090/api/assisted-install/v2/clusters

# UI access (via SSH tunnel from workstation)
ssh -L 8080:127.0.0.1:8080 root@192.168.2.196
# Then browse to: http://localhost:8080

# Serial console access (for troubleshooting)
ssh root@192.168.2.196 "qm terminal <vmid>"
```

### 4. OKD Virtual Machines

**Current Deployment**: Single-node cluster

| VM ID | Name | vCPU | RAM | Disk | IP | Purpose |
|-------|------|------|-----|------|----|----|
| 150 | okd-node-1 | 8 | 16GB | 100GB | 192.168.2.252 | OKD control plane & compute |

**VM Configuration**:
- **OS**: Fedora CoreOS (installed via discovery ISO)
- **Boot Order**: scsi0 (disk), ide2 (ISO)
- **Network**: virtio NIC on vmbr0
- **SCSI Controller**: virtio-scsi-single
- **Guest Agent**: QEMU guest agent enabled (`--agent enabled=1`)
- **Serial Console**: Serial0 configured as socket for console access

**VM Management Best Practices**:
- Enable QEMU guest agent for all VMs for better integration and monitoring
- Configure serial console for emergency access and troubleshooting
- Use virtio drivers for optimal performance (network, disk)
- Set appropriate CPU type (host for best performance)
- Configure automatic start order if needed

## Data Flows

### OKD Deployment Flow

```
1. Developer Workstation
   ↓ (SSH to Proxmox)
   
2. Proxmox: Deploy Assisted Service
   - Start Podman containers
   - Services listen on localhost
   ↓
   
3. Create Cluster via API
   - POST to http://127.0.0.1:8090/api/.../clusters
   - Configure network, domain, SSH keys
   - Returns CLUSTER_ID
   ↓
   
4. Generate Discovery ISO
   - POST to http://127.0.0.1:8090/api/.../infra-envs
   - ISO generated at /var/lib/vz/template/iso/
   ↓
   
5. Create VM on Proxmox
   - qm create with ISO attached
   - Boot from discovery ISO
   ↓
   
6. VM Boots and Registers
   - Boots Fedora CoreOS live
   - Agent contacts 192.168.2.196:8090
   - Reports hardware inventory
   ↓
   
7. Start Installation
   - POST to .../clusters/{id}/actions/install
   - Writes FCOS + ignition to disk
   - VM reboots into installed system
   ↓
   
8. OKD Bootstrap
   - Bootkube starts
   - Cluster operators deploy
   - Installation completes (30-60 min)
   ↓
   
9. Access Cluster
   - Download kubeconfig from API
   - Access via kubectl/oc CLI
```

### Secret Management Flow

```
1. Developer creates vault
   bash proxmox/okd/vault_create.sh
   ↓
   
2. Vault password stored locally
   .vault_pass.txt (gitignored)
   ↓
   
3. Secrets encrypted in vault.yml
   ansible-vault encrypt_string
   ↓
   
4. Ansible playbooks decrypt at runtime
   --vault-password-file .vault_pass.txt
   ↓
   
5. Secrets used for Proxmox API access
   Never stored in plaintext
```

## Component Interactions

### Workstation ↔ Bastion Host

**Protocol**: SSH (port 22)

**Operations**:
- SSH login: `ssh user@bastion.thelab.lan`
- File transfer: `scp file user@bastion.thelab.lan:/path/`
- Run playbooks remotely: `ssh user@bastion.thelab.lan 'ansible-playbook ...'`
- Port forwarding through bastion: `ssh -L 8080:192.168.2.196:8080 user@bastion.thelab.lan`

### Bastion Host ↔ Proxmox

**Protocol**: SSH (port 22)

**Operations**:
- VM management: `ssh root@192.168.2.196 "qm create|start|stop|status <vmid>"`
- File transfer: `scp file root@192.168.2.196:/path/`
- Remote script execution: `ssh root@192.168.2.196 'bash -s' < script.sh`
- API access via SSH tunnel: Monitor cluster via localhost:8080

**Automation**:
- Ansible playbooks run from bastion
- Cron jobs for scheduled operations
- Monitoring agents reporting back to bastion

### Assisted Service ↔ OKD VM

**Protocol**: HTTP (API on port 8090)

**Discovery Phase**:
- VM boots from ISO
- Agent reports to http://192.168.2.196:8090
- Hardware inventory transmitted
- Validation checks performed

**Installation Phase**:
- Ignition config downloaded from API
- Progress updates sent to API
- Installation logs streamed

### Proxmox ↔ OKD VM

**Protocol**: QEMU/KVM hypervisor interface

**Management**:
- Start/stop via `qm` commands
- Console access via VNC
- Resource allocation (CPU, RAM, disk)
- Network bridging (vmbr0)

## Automation Approaches

### 1. Assisted Service Method (Preferred)

**Location**: `proxmox/okd/assisted-service/`

**Components**:
- `deploy.sh` - Deploy Podman containers on Proxmox
- `create-cluster.sh` - Create cluster via API
- `monitor-install.sh` - Monitor installation progress
- `pod.yml` - Podman pod manifest
- `okd-configmap.yml` - OKD configuration

**Advantages**:
- Web UI for monitoring
- Automatic validation
- Built-in health checks
- No manual ignition generation

**Workflow**:
```bash
# 1. SSH to Proxmox and deploy service
ssh root@192.168.2.196
cd /path/to/assisted-service
podman play kube pod.yml

# 2. Create cluster (from Proxmox)
curl -X POST http://127.0.0.1:8090/api/assisted-install/v2/clusters ...
# Save CLUSTER_ID to ~/cluster-id.txt

# 3. Create VM
qm create 150 --name okd-node-1 --memory 16384 --cores 8 ...

# 4. Monitor
curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID
```

### 2. Ansible Playbook Method (Alternative)

**Location**: `proxmox/okd/`

**Components**:
- `playbook.yml` - Main orchestration
- `roles/` - Modular tasks
  - `upload_image/` - ISO preparation
  - `clone_vms/` - VM creation
  - `okd_install/` - Installation monitoring
  - `okd_health/` - Health checks
  - `okd_report/` - Final report
- `inventory.ini` - Host inventory
- `vault.yml` - Encrypted secrets

**Workflow**:
```bash
# From workstation
ansible-playbook -i proxmox/okd/inventory.ini \
  proxmox/okd/playbook.yml \
  --vault-password-file proxmox/okd/.vault_pass.txt
```

## Security Architecture

### Secret Management

**Tool**: Ansible Vault

**Protected Assets**:
- Proxmox API credentials
- SSH private keys
- OKD pull secrets
- Administrative passwords

**Storage**:
- Encrypted: `vault.yml` (committed to git)
- Password: `.vault_pass.txt` (gitignored, local only)

**Usage**:
```bash
# Create vault
bash proxmox/okd/vault_create.sh

# Encrypt new secret
ansible-vault encrypt_string 'secret_value' --name 'var_name'

# Decrypt at runtime
ansible-playbook --vault-password-file .vault_pass.txt
```

### Access Control

**Proxmox Access**:
- Root SSH key authentication
- No password authentication
- Firewall rules limiting SSH to trusted networks

**OKD Cluster Access**:
- Kubeconfig with client certificates
- SSH access via authorized_keys
- RBAC policies within Kubernetes

## Key Design Decisions

### Why Bastion Host for Management?

**Decision**: Use dedicated bastion host for automation and management

**Reasoning**:
- Single point of access for all infrastructure operations
- Persistent environment for long-running tasks and cron jobs
- Centralized location for credentials and secrets (vault password)
- Network-local for faster operations (no remote SSH latency)
- Dedicated resources for automation without impacting workstation
- Can remain running 24/7 for scheduled operations
- Audit trail and logging of all infrastructure changes
- Jump server pattern for secure multi-hop access

**Trade-offs**:
- Additional VM/system to maintain
- Need to keep bastion host secure and updated
- Extra network hop for operations

### Why Assisted Service on Proxmox (not bastion)?

**Decision**: Run assisted-service directly on Proxmox host

**Reasoning**:
- Direct access to VM creation and ISO storage
- ISO storage co-located with VMs (no network transfer)
- Reduced network latency for VM operations
- Simplifies OKD deployment workflow

**Trade-offs**:
- Proxmox has additional services running
- Requires SSH tunnel for UI access from workstation or bastion

### Why Single-Node OKD?

**Decision**: Deploy OKD as single-node cluster (SNO)

**Reasoning**:
- Homelab resource constraints
- Development/testing environment
- Reduced complexity
- Lower hardware requirements (8 cores, 16GB RAM)

**Trade-offs**:
- No high availability
- Single point of failure
- Not production-ready

### Why Ansible Vault?

**Decision**: Use Ansible Vault for all secrets

**Reasoning**:
- Industry standard tool
- Integrates with Ansible playbooks
- Allows encrypted files in git
- Local password file prevents accidental commits

**Trade-offs**:
- Requires vault password management
- Setup step before use

## File Organization

```
homelab-helper/
├── .github/
│   └── copilot-instructions.md    # AI agent guidance
├── .venv/                          # Python virtualenv
├── proxmox/
│   └── okd/
│       ├── assisted-service/       # Podman-based deployment
│       │   ├── deploy.sh
│       │   ├── create-cluster.sh
│       │   ├── monitor-install.sh
│       │   ├── pod.yml
│       │   └── okd-configmap.yml
│       ├── roles/                  # Ansible roles
│       │   ├── upload_image/
│       │   ├── clone_vms/
│       │   ├── okd_install/
│       │   ├── okd_health/
│       │   └── okd_report/
│       ├── playbook.yml            # Ansible orchestration
│       ├── inventory.ini           # Ansible inventory
│       ├── vault.yml               # Encrypted secrets
│       ├── .vault_pass.txt         # Vault password (gitignored)
│       ├── vault_create.sh         # Vault initialization
│       ├── install_deps.sh         # Dependency installer
│       ├── requirements.txt        # Python dependencies
│       ├── DEPLOYMENT.md           # Deployment guide
│       └── README.md               # Quick start
├── ARCHITECTURE.md                 # This file
└── README.md                       # Project overview
```

## Monitoring and Observability

### Cluster Status Monitoring

**Via API** (from Proxmox):
```bash
CLUSTER_ID=$(cat ~/cluster-id.txt)
curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID | jq
```

**Via UI** (from workstation via SSH tunnel):
```bash
ssh -L 8080:127.0.0.1:8080 root@192.168.2.196
# Browse to: http://localhost:8080
```

### Installation Progress Stages

1. **Starting installation** - Initial setup
2. **Installing** - Writing to disk
3. **Waiting for bootkube** - Bootstrap starting
4. **Writing image to disk** - OS installation
5. **Rebooting** - First reboot
6. **Joined** - Node joined cluster
7. **Done** - Installation complete

### VM Monitoring

```bash
# VM status
ssh root@192.168.2.196 "qm status 150"

# VM resource usage
ssh root@192.168.2.196 "qm monitor 150"
```

## Existing Infrastructure

### Network Infrastructure (Ubiquiti UniFi)

**Primary Gateway**: UniFi Dream Machine (UDM)  
**IP Address**: 192.168.2.1  
**Role**: Core network gateway, router, firewall, and controller

#### Network Services

**DNS Management**
- Internal DNS domain: `thelab.lan`
- DNS resolution for all lab services
- Custom DNS records for OKD and services
- Split DNS configuration (internal vs external)
- DNS forwarding and caching

**DHCP Services**
- Primary subnet: 192.168.2.0/24
- DHCP range: 192.168.2.100-192.168.2.250 (typical)
- Static DHCP reservations for infrastructure:
  - Proxmox: 192.168.2.196
  - OKD Node: 192.168.2.252
  - Synology NAS: (to be documented)
- DHCP lease time and options configured via UDM

**Firewall & Security**
- Stateful firewall rules
- Network segmentation via firewall policies
- Port forwarding rules (if external access needed)
- Intrusion Detection/Prevention (IDS/IPS) capabilities
- Traffic inspection and logging
- Guest network isolation (if configured)

**VPN & Remote Access**
- Site-to-site VPN capabilities
- Remote access VPN for secure external connectivity
- WireGuard or OpenVPN protocols
- VPN client access to homelab resources

#### Network Topology

**Physical Network**
- Managed switches (UniFi Switch models - to be documented)
- Wireless access points (UniFi AP models - to be documented)
- Uplink to ISP modem/router
- Internal network: 1 Gbps LAN
- Uplink speed: (to be documented)

**VLANs** (if configured)
- Default/Management VLAN: (to be documented)
- IoT VLAN: (if segregated)
- Guest VLAN: (if configured)
- Lab/Infrastructure VLAN: (current configuration)

**Network Monitoring**
- UniFi Controller for device management
- Network statistics and traffic analysis
- Client device tracking
- Application identification and QoS

#### Integration with Homelab

**DNS for OKD**
- A records for cluster nodes
- Wildcard DNS for OKD routes: `*.apps.okd.thelab.lan` → 192.168.2.252
- API endpoint: `api.okd.thelab.lan` → 192.168.2.252
- Internal service discovery

**Firewall Rules for Services**
- Allow HTTP/HTTPS to OKD node (80, 443)
- Allow Proxmox web UI (8006)
- Allow SSH to infrastructure (22)
- Allow Kubernetes API (6443)
- Allow NFS to Synology (2049)
- Block unauthorized external access

**QoS/Traffic Shaping** (if configured)
- Prioritize OKD API traffic
- Bandwidth limits for media streaming
- Prioritize management traffic

#### UniFi Controller

**Access**
- Controller URL: (to be documented - typically on UDM or separate)
- Controller version: (to be documented)
- Admin access for configuration

**Features in Use**
- Device adoption and management
- Network configuration
- Firewall rule management
- VPN configuration
- Traffic statistics and insights
- Topology mapping

**API Integration**
- UniFi Controller REST API available
- Authentication via API token or username/password
- Automation capabilities:
  - Query network statistics and device status
  - Retrieve client information and DHCP leases
  - Pull firewall rules and configuration
  - Monitor bandwidth usage and traffic patterns
  - Export network topology data
  - Automated DNS record management
- Use cases for homelab automation:
  - Dynamic inventory updates (IP addresses, hostnames)
  - Network monitoring integration with Prometheus/Grafana
  - Automated documentation updates
  - Alert on network anomalies
  - Configuration drift detection

#### Backup & Disaster Recovery

**Network Configuration Backup**
- UniFi Controller auto-backup enabled
- Configuration export capability
- Backup location: (to be documented)
- Recovery procedure documented
- API-based backup automation possible

### Storage (Synology NAS)
- **Shared Storage**: NFS/SMB shares available
- **Backup Target**: Available for VM and application backups

## Future Enhancements

### Planned Improvements
- Multi-node OKD cluster support
- Automated backup and restore (to Synology NAS)
- Infrastructure as Code with Terraform
- GitOps-based cluster configuration
- Monitoring with Prometheus/Grafana
- Automated certificate management
- NFS/SMB integration with Synology for OKD persistent volumes
- **UniFi API Integration**: Automated network data collection and monitoring
  - Pull latest DHCP leases and device status
  - Monitor bandwidth and traffic statistics
  - Integrate with monitoring dashboards
  - Automate DNS record updates
  - Dynamic infrastructure inventory updates

### Documentation Improvements
- Troubleshooting runbook
- Performance tuning guide
- Disaster recovery procedures
- Synology NAS integration guide
- UniFi API usage and automation guide

## References

- **OKD Documentation**: https://docs.okd.io/
- **Assisted Installer**: https://github.com/openshift/assisted-service
- **Proxmox Documentation**: https://pve.proxmox.com/pve-docs/
- **Ansible Vault**: https://docs.ansible.com/ansible/latest/user_guide/vault.html
- **Fedora CoreOS**: https://docs.fedoraproject.org/en-US/fedora-coreos/

## Appendix: Quick Command Reference

```bash
# === Workstation Commands ===

# Activate Python environment
source .venv/bin/activate

# Create vault
bash proxmox/okd/vault_create.sh

# Run Ansible playbook
ansible-playbook -i proxmox/okd/inventory.ini proxmox/okd/playbook.yml \
  --vault-password-file proxmox/okd/.vault_pass.txt

# === Proxmox Commands (via SSH) ===

# Check cluster status
ssh root@192.168.2.196 'bash -s' <<'EOF'
CLUSTER_ID=$(cat ~/cluster-id.txt)
curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID | \
  jq -r '.status, .status_info'
EOF

# Create VM
ssh root@192.168.2.196 "qm create 150 --name okd-node-1 --memory 16384 --cores 8 ..."

# Start/Stop VM
ssh root@192.168.2.196 "qm start 150"
ssh root@192.168.2.196 "qm stop 150"

# VM status
ssh root@192.168.2.196 "qm status 150"

# === Assisted Service API Commands ===

# List clusters
curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters | jq

# Get cluster details
curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID | jq

# Start installation
curl -X POST http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID/actions/install

# Download kubeconfig
curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID/downloads/files?file_name=kubeconfig -o kubeconfig
```
