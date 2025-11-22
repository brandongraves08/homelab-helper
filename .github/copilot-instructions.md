

# Copilot Instructions for AI Coding Agents

## Project Overview
Homelab Helper automates homelab infrastructure management, focusing on:
- Secure secret handling with Ansible Vault (never store secrets in plaintext)
- Proxmox integration for VM and resource automation (via API, `pvesh`, `qm`, or `proxmoxer`)
- Minimal user prompts—default to automation and self-service
- Self-updating/learning to reduce manual steps over time

## Architecture & Patterns
- **Secrets:** All passwords and sensitive data must be managed with Ansible Vault. Use `ansible-vault encrypt` for new secrets. Vault files are stored as `vault.yml` with password in `.vault_pass.txt` (both gitignored).
- **Proxmox Automation:** Interact with Proxmox using:
  - SSH commands: `ssh root@192.168.2.196 "qm create/start/stop <vmid>"`
  - Ansible module: `community.general.proxmox_kvm`
  - API via `proxmoxer` Python library
- **OKD Deployment:** Uses OpenShift Assisted Installer service running on Proxmox host (192.168.2.196):
  - **UI**: http://192.168.2.196:8080 (via SSH tunnel: `ssh -L 8080:127.0.0.1:8080 root@192.168.2.196`)
  - **API**: http://127.0.0.1:8090 (accessed via SSH on Proxmox)
  - **Image Service**: http://127.0.0.1:8888
  - Deployment steps: Deploy assisted-service via Podman on Proxmox → Create cluster via API → Generate discovery ISO → Upload to Proxmox storage → Create VM → Monitor installation
  - Access monitoring: SSH to Proxmox and run commands locally, or use SSH tunneling for web UI
  - See `proxmox/okd/DEPLOYMENT.md` for complete workflow and `proxmox/okd/README.md` for alternatives
- **Folder Structure:** Environment-specific folders (`proxmox/okd/`) contain scripts, Ansible roles, playbooks, and documentation
- **Network Topology:** Workstation → Bastion Host → Proxmox (192.168.2.196) → VMs (e.g., 192.168.2.252)
- **Bastion Host:** Dedicated management server for running automation, scripts, and serving as jump server. All infrastructure operations should be executed from bastion when possible.
- **User Prompts:** Only prompt for essential info. Default to automated flows.
 - **Do It Yourself:** Never ask the user to do something you can do yourself. Attempt to perform actions automatically when safe; for privileged operations prompt for confirmation or credentials instead of asking the user to perform the step manually.

## Developer Workflows
- **Setup (on bastion host):** 
  - Clone repository: `git clone <repo-url> /opt/homelab-helper`
  - Install dependencies: `bash proxmox/okd/install_deps.sh` (installs Ansible, Python, proxmoxer)
  - Create vault: `bash proxmox/okd/vault_create.sh` (generates vault password and `vault.yml`)
  - Activate Python virtualenv: `source .venv/bin/activate`
  - Configure SSH keys for Proxmox and OKD node access
- **OKD Deployment (Assisted Service method - preferred):**
  - Deploy service on Proxmox: SSH to Proxmox and run assisted-service via Podman
  - Create cluster: Run commands via SSH on Proxmox accessing localhost API (127.0.0.1:8090)
  - Generate and access ISO: ISO is generated and stored locally on Proxmox at `/var/lib/vz/template/iso/`
  - Create VM: Use `qm create` commands via SSH: `ssh root@192.168.2.196 "qm create ..."`
  - Monitor: SSH to Proxmox and check status via local API: `curl -s http://127.0.0.1:8090/api/assisted-install/v2/clusters/$CLUSTER_ID`
  - Store cluster ID on Proxmox: `echo $CLUSTER_ID > ~/cluster-id.txt` for easy retrieval
- **OKD Deployment (Ansible method - alternative):**
  - Run playbook: `ansible-playbook -i proxmox/okd/inventory.ini proxmox/okd/playbook.yml --vault-password-file proxmox/okd/.vault_pass.txt`
- **Proxmox VM Management:**
  - Create: `ssh root@192.168.2.196 "qm create <vmid> --name <name> --memory <mb> --cores <n> --agent enabled=1 --serial0 socket ..."`
  - Start/Stop: `ssh root@192.168.2.196 "qm start|stop <vmid>"`
  - Status: `ssh root@192.168.2.196 "qm status <vmid>"`
  - Serial Console: `ssh root@192.168.2.196 "qm terminal <vmid>"` (Ctrl+O to exit)
- **Documentation:** Update `DEPLOYMENT.md`, `README.md`, and this file as workflows evolve.

## Integration Points
- **Proxmox:** Use API credentials or CLI tools. Never store credentials in plaintext.
- **Ansible Vault:** Required for all secret management.
- **Context7 Documentation:** When working with external tools, libraries, or frameworks (e.g., Kubernetes, Ansible, Prometheus, Grafana, Tekton, Harbor, PostgreSQL operators), use Context7 tools to fetch up-to-date official documentation. Always resolve library ID first with `mcp_context7_resolve-library-id` or `mcp_io_github_ups_resolve-library-id`, then fetch docs with `mcp_context7_get-library-docs` or `mcp_io_github_ups_get-library-docs`. This ensures you have the latest API references, configuration examples, and best practices.

## Conventions
- Scripts and automation should be organized by environment type.
- Document new patterns and workflows as the project evolves.
- **Hypervisor**: All VMs run on Proxmox VE (KVM/QEMU). Always enable QEMU guest agent (`--agent enabled=1`) and serial console (`--serial0 socket`) when creating VMs for better management and troubleshooting.
- **Do It Yourself:** Never ask the user to do something you can do yourself. Attempt to perform actions automatically when safe; for privileged operations prompt for confirmation or credentials instead of asking the user to perform the step manually.
- **Install Dependencies Automatically:** When a tool, package, or application is needed for a task, install it automatically using the appropriate package manager or installation method. Use `run_in_terminal` to install Python packages (`pip install`), system packages (`apt`, `dnf`, `brew`), or other tools. Only prompt the user if elevated privileges are required and not available.

## Information Gathering
If required information (such as credentials) is not available, the agent must prompt the user for it. Never assume or invent unknown values—always ask if something is missing or unclear.

## OKD Deployment Caveat
When deploying OKD:
- If a VM is booted once and does not use the ignition file, it cannot be reused for OKD deployment.
- The VM must be shut down and deleted, and a new VM deployed to ensure proper ignition configuration.

## Documentation
See `ARCHITECTURE.md` for detailed system architecture, component interactions, data flows, and design decisions.
See `ACTION_PLAN.md` for phased enhancement roadmap including storage integration, monitoring, backups, GitOps, and self-hosted applications.
