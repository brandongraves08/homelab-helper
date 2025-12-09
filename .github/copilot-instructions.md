

# Copilot Instructions for AI Coding Agents

## Quick Decision Tree
**When the user asks to deploy something:**
1. **Kubernetes cluster?** → Use **K3s** (proxmox/k3s/, 10 min, proven)
2. **OpenShift?** → Use **Assisted Service** (proxmox/okd/assisted-service/, 20 min, GUI-based)
3. **Single VM on Proxmox?** → Use `qm create` with `--agent enabled=1 --serial0 socket`
4. **Service deployment?** → Check `infrastructure/` folder for pattern (ConfigMap-based, OAuth via Authentik)
5. **Credentials needed?** → **NEVER hardcode.** Use Ansible Vault (vault.yml) or dedicated files (.unifi_api_key, 600 perms)

## Key Constraints (Non-negotiable)
- ❌ **Never store passwords in plaintext** - Vault or dedicated files only
- ❌ **Never deploy without `--agent enabled=1 --serial0 socket`** on Proxmox VMs
- ❌ **Never skip DHCP/DNS config before first boot** of OKD/K3s nodes
- ❌ **Never reuse VM for OKD if already booted without ignition** - must delete and redeploy
- ✅ **Always use Context7 docs** when working with external APIs/frameworks
- ✅ **Always ask if credentials/IPs unknown** - never invent values
- ✅ **Auto-install missing tools** via apt/dnf/pip unless elevated privs required

## Learned Workarounds (Update if proven wrong)
| Issue | Root Cause | Solution |
|-------|-----------|----------|
| Dashy pod restarts every 60s | `yarn build` runs on every startup | Override entrypoint: `command: ["node", "server"]` + 120s liveness probe |
| UniFi DNS records not resolving | API missing `"enabled": true` field | Always include `"enabled": true` in static DNS POST |
| Grafana OAuth fails | generic_oauth has /emails endpoint bug | Use Authentik OAuth/OIDC providers instead |
| OKD deployment fails | Circular dependencies in agent installer | Don't use. Use **K3s** or **Assisted Service** instead |

## Project Autonomy Goals
- **Self-Learning**: When corrected, update this file immediately with the lesson
- **Auto-Improve**: Create helper scripts for repeated manual tasks
- **Smart Decisions**: Use Context7 docs for APIs, not guessing
- **Auto-Dependencies**: Install missing tools without asking (unless sudo needed)

## Action Patterns (Copy & Adapt)

### Secrets Pattern
```bash
# Passwords/sensitive data
ansible-vault encrypt_string 'password' --name 'variable_name' >> vault.yml

# API keys/tokens (file-based)
echo 'your-api-key' > .unifi_api_key
chmod 600 .unifi_api_key
# Add to .gitignore
```

### Proxmox VM Creation
```bash
# Standard pattern - ALWAYS include agent + serial
ssh root@192.168.2.196 "qm create <VMID> \
  --name <name> \
  --bios ovmf --efidisk0 local-lvm:1,efitype=4m \
  --memory <MB> --cores <N> --cpu host \
  --scsi0 local-lvm:<GB> \
  --agent enabled=1 --serial0 socket"
```

### Kubernetes Cluster Deployment
**K3s (PICK THIS - 10 min, proven):**
```bash
cd proxmox/k3s
./deploy-vms.sh
ssh centos@192.168.2.250
curl -sfL https://get.k3s.io | sh -s - server --cluster-init --token k3s-homelab-token
# Get node token, join others, export KUBECONFIG=./kubeconfig
```

**OKD Assisted Service (alternative - 20 min, GUI):**
```bash
cd proxmox/okd/assisted-service && ./deploy-to-proxmox.sh
# UI at http://bastion-ip:8080 - download ISO, create VM, boot
```

### Kubernetes Service Deployment
```bash
export KUBECONFIG=./proxmox/k3s/kubeconfig
kubectl apply -f infrastructure/dashboard/dashy-deployment.yml    # Dashboard
kubectl apply -f infrastructure/authentik/forward-auth-outpost.yml # OAuth
kubectl apply -f infrastructure/monitoring/prometheus-values.yaml  # Monitoring
```

### UniFi DNS (Critical Fields)
```bash
curl -k -X POST "https://192.168.2.1/proxy/network/v2/api/site/default/static-dns" \
  -H "X-API-KEY: $(cat .unifi_api_key)" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "key": "api.k3s.thelab.lan",
    "record_type": "A",
    "value": "192.168.2.196",
    "port": 0, "priority": 0, "ttl": 0, "weight": 0
  }'
```

## System Architecture Reference

| Component | Address | Purpose |
|-----------|---------|---------|
| Proxmox Hypervisor | 192.168.2.196 | VMs, qm CLI |
| K3s API (HAProxy) | 192.168.2.196:6443 | Kubernetes API |
| K3s Servers | 192.168.2.250-252 | Control plane + workers |
| Bastion Host | ubuntu/rhel-01.thelab.lan | SSH jump, Ansible controller |
| UniFi Controller | 192.168.2.1 | DHCP, DNS, WiFi |
| Domain | thelab.lan | Internal DNS zone |

## Folder Reference (Quick Lookup)
- `proxmox/k3s/` → K3s deployment scripts, kubeconfig → **USE THIS FOR KUBERNETES**
- `proxmox/okd/` → OKD alternatives, Assisted Service
- `infrastructure/` → Kubernetes ConfigMaps & deployments for services
- `proxmox/okd/install_deps.sh` → Install Ansible/Python
- `proxmox/okd/vault_create.sh` → Create vault.yml

## Integration Endpoints (Copy-Paste Ready)

**Authentik OAuth** (in Kubernetes):
```yaml
env:
  - name: GF_AUTH_GENERIC_OAUTH_ENABLED
    value: "true"
  - name: GF_AUTH_GENERIC_OAUTH_CLIENT_ID
    value: "grafana"  # From Authentik provider
```
API endpoints: `/api/v3/providers/oauth2/`, `/api/v3/core/applications/` (see `infrastructure/authentik/README.md`)

**Ansible Vault** (in playbooks):
```yaml
vars_files:
  - vault.yml  # Contains encrypted variables
```
Run with: `ansible-playbook playbook.yml --vault-password-file .vault_pass.txt`

**K3s kubeconfig**:
```bash
export KUBECONFIG=$(pwd)/proxmox/k3s/kubeconfig
kubectl get nodes
```

## Task Execution Reference

### Task: Deploy K3s Cluster (10 min)
```bash
cd proxmox/k3s
./deploy-vms.sh                    # Creates 3 VMs
ssh centos@192.168.2.250
curl -sfL https://get.k3s.io | sh -s - server --cluster-init --token k3s-homelab-token
sudo cat /var/lib/rancher/k3s/server/node-token  # Save
# Back on workstation:
./start-vms.sh && ./deploy-automated-fixed.sh
export KUBECONFIG=./kubeconfig && kubectl get nodes
```

### Task: Deploy OKD via Assisted Service (20 min, GUI-driven)
```bash
cd proxmox/okd/assisted-service
./deploy-to-proxmox.sh             # Starts container
# Access http://bastion-ip:8080, create cluster, download ISO
# Create VM on Proxmox, attach ISO, boot
# Complete install via UI
```

### Task: Create Proxmox VM
```bash
ssh root@192.168.2.196 "qm create 150 \
  --name myvm --bios ovmf --efidisk0 local-lvm:1,efitype=4m \
  --memory 8192 --cores 4 --scsi0 local-lvm:80 \
  --agent enabled=1 --serial0 socket"
ssh root@192.168.2.196 "qm start 150"
```

### Task: Deploy Kubernetes Service
```bash
export KUBECONFIG=./proxmox/k3s/kubeconfig
kubectl apply -f infrastructure/dashboard/dashy-deployment.yml
```

### Task: Encrypt Credentials
```bash
# Vault: ansible-vault encrypt_string 'value' --name varname >> vault.yml
# File: echo 'key' > .unifi_api_key && chmod 600 .unifi_api_key
```

### Task: Get Cluster kubeconfig
```bash
export KUBECONFIG=./proxmox/k3s/kubeconfig
```

### Task: Access VM Serial Console
```bash
ssh root@192.168.2.196 "qm terminal <vmid>"  # Ctrl+O to exit
```

### Task: Configure UniFi DNS Record
```bash
curl -k -X POST "https://192.168.2.1/proxy/network/v2/api/site/default/static-dns" \
  -H "X-API-KEY: $(cat .unifi_api_key)" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "key": "api.k3s.thelab.lan", "record_type": "A", "value": "192.168.2.196", "port": 0, "priority": 0, "ttl": 0, "weight": 0}'
```

### Task: Run Ansible Playbook with Vault
```bash
ansible-playbook -i proxmox/okd/inventory.ini proxmox/okd/playbook.yml \
  --vault-password-file proxmox/okd/.vault_pass.txt
```

## External Dependencies & When to Use Them

| System | IP/URL | Auth | When to Use |
|--------|--------|------|-------------|
| Proxmox API | 192.168.2.196:8006 | root@pam + password (vault.yml) | VM management, resource queries |
| Ansible | Local | vault.yml for SSH keys | Automation playbooks |
| UniFi API | 192.168.2.1 | X-API-KEY (.unifi_api_key) | DNS automation, network config |
| Authentik | https://authentik.thelab.lan | API token | OAuth provider setup, user management |
| K3s API | 192.168.2.196:6443 | kubeconfig | kubectl commands, service deployments |
| Context7 Docs | MCP tool | N/A | Kubernetes, Ansible, Prometheus, Grafana APIs |

## Conventions & Style

| Aspect | Rule | Why |
|--------|------|-----|
| **Passwords** | Never in files. Vault/files only. | Security/compliance |
| **VM Creation** | Always `--agent enabled=1 --serial0 socket` | Management & troubleshooting |
| **Deployment** | **K3s** (not OKD) for Kubernetes | 10 min vs 20+ min, fewer failures |
| **Updates** | Update copilot-instructions.md when corrected | Self-learning from mistakes |
| **Scripts** | Save working solutions as reusable scripts | Avoid repeating manual steps |
| **Tools** | Auto-install missing dependencies | Reduce user prompts |
| **Unknown values** | Always ask user, never invent | Avoid invalid credentials/configs |

## Documentation
- **ARCHITECTURE.md** - System design, topology, components, data flows
- **ACTION_PLAN.md** - Roadmap: storage, monitoring, backups, GitOps, apps
- **proxmox/k3s/README.md** - K3s operational details
- **proxmox/okd/SUCCESSFUL_DEPLOYMENT.md** - Proven OKD workflow
- **infrastructure/authentik/README.md** - OAuth/OIDC setup patterns
