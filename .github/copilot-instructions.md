

# Copilot Instructions for AI Coding Agents

## Project Overview
Homelab Helper automates homelab infrastructure management, focusing on:
- Secure secret handling with Ansible Vault (never store secrets in plaintext)
- Proxmox integration for VM and resource automation (via API, `pvesh`, `qm`, or `proxmoxer`)
- Minimal user prompts—default to automation and self-service
- Self-updating/learning to reduce manual steps over time

## Self-Learning and Adaptation
As an AI coding agent, you must continuously learn from interactions and improve:
- **Document Patterns**: When you discover new workflows, API behaviors, or solutions, update relevant documentation (README.md, ARCHITECTURE.md, deployment guides)
- **Update Instructions**: When the user corrects you or provides new information (credentials, API usage, configuration patterns), immediately update this copilot-instructions.md file to remember the lesson
- **Store Credentials Securely**: 
  - API keys and tokens: Store in dedicated files (.unifi_api_key, .authentik-api-token) with permissions 600
  - Passwords and sensitive data: MUST be encrypted with Ansible Vault and stored in vault.yml files
  - NEVER store passwords in clear text in any file, script, or configuration
  - Use vault password file (.vault_pass.txt) for automation, kept gitignored
- **Learn from Errors**: When an approach fails, document why it failed and what worked instead. Update scripts and documentation to reflect the working solution
- **Adapt Workflows**: If the user repeatedly corrects the same behavior, it means your approach is wrong. Update instructions to reflect the correct approach
- **Create Helper Scripts**: When you solve a problem programmatically, save the working code as a reusable script in the appropriate directory
- **Improve Automation**: Each time you perform a manual step, consider how to automate it next time and implement that automation
- **Track Dependencies**: Document required packages, tools, and configurations needed for each workflow
- **Version Compatibility**: Track which versions of software work together and document any version-specific requirements
- **Use Documentation Tools**: When uncertain about APIs, configurations, or best practices, use Context7 MCP tools (`mcp_context7_resolve-library-id` and `mcp_context7_get-library-docs`) or Microsoft Docs tools (`mcp_microsoftdocs_microsoft_docs_search`) to fetch official documentation. This ensures accurate, up-to-date information instead of guessing or using outdated knowledge

**Learned Solutions:**
- **Dashy Dashboard**: Default entrypoint runs `yarn build` on every startup (60-120s), causing pod restarts. Solution: Override with `command: ["node", "server"]` to skip build. Requires increased probes: 120s liveness, 60s readiness.
- **UniFi DNS**: Records MUST have `"enabled": true` field set via API or they won't resolve. API endpoint: `https://192.168.2.1/proxy/network/v2/api/site/default/static-dns` with X-API-KEY header.
- **Grafana SSO**: generic_oauth provider has hardcoded /emails endpoint bug. azuread provider requires JWKS validation. Consider using Authentik proxy provider instead of OAuth for SSO.

The goal is to become more autonomous and accurate over time, requiring less correction from the user.

## Architecture & Patterns
- **Secrets:** All passwords and sensitive data must be managed with Ansible Vault. Use `ansible-vault encrypt` for new secrets. Vault files are stored as `vault.yml` with password in `.vault_pass.txt` (both gitignored).
- **Proxmox Automation:** Interact with Proxmox using:
  - SSH commands: `ssh root@192.168.2.196 "qm create/start/stop <vmid>"`
  - Ansible module: `community.general.proxmox_kvm`
  - API via `proxmoxer` Python library
- **OKD Deployment:** CRITICAL: Always use OKD 4.20 or newer. Never deploy versions older than 4.20.
  - **Preferred Method**: Use `openshift-install` on bastion host (rhel-01.thelab.lan) for SNO deployments
  - **Version**: OKD 4.20.0-okd-scos.9 or newer from https://github.com/okd-project/okd/releases
  - **Network Configuration**: MUST configure DHCP reservation BEFORE VM first boot
    - VM MAC address must be noted from `qm config <vmid> | grep net0`
    - DHCP reservation assigns static IP (e.g., 192.168.2.252 for MAC BC:24:11:E2:D1:D0)
    - DNS entries required: api.okd.thelab.lan, *.apps.okd.thelab.lan → VM IP
    - See `proxmox/okd/DHCP_CONFIGURATION.md` for detailed setup
  - **Deployment Steps**: Download OKD 4.20 tools → Create install-config.yaml → Generate ignition → Embed in FCOS ISO → Create VM with UEFI → Configure DHCP/DNS → Boot and monitor
  - **Alternative Method**: Assisted Installer service (see `proxmox/okd/DEPLOYMENT.md`)
  - Complete guide: `proxmox/okd/OKD_4.20_DEPLOYMENT.md`
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
- **OKD 4.20 Deployment (Preferred - openshift-install method):**
  - Run from bastion (rhel-01.thelab.lan): Download OKD 4.20 tools, create install-config.yaml, generate ignition
  - Embed ignition in FCOS ISO: `podman run quay.io/coreos/coreos-installer:release iso ignition embed -fi bootstrap-in-place-for-live-iso.ign fcos-live.iso`
  - Upload ISO to Proxmox: `scp fcos-live.iso root@192.168.2.196:/var/lib/vz/template/iso/`
  - Create VM with UEFI: `qm create <vmid> --bios ovmf --efidisk0 local-lvm:1,efitype=4m --memory 32768 --cores 8 --cpu host --scsi0 local-lvm:120 --ide2 local:iso/<iso-name> --boot order=ide2`
  - **CRITICAL**: Get VM MAC address: `qm config <vmid> | grep net0`
  - **CRITICAL**: Configure DHCP reservation for MAC → IP (e.g., BC:24:11:E2:D1:D0 → 192.168.2.252) BEFORE starting VM
  - **CRITICAL**: Configure DNS records BEFORE starting VM and VERIFY with nslookup:
    - `api.okd.thelab.lan` → VM IP (192.168.2.252)
    - `api-int.okd.thelab.lan` → VM IP (192.168.2.252)
    - `*.apps.okd.thelab.lan` → VM IP (192.168.2.252) (wildcard for web console and apps)
    - Verify: `nslookup api.okd.thelab.lan && nslookup api-int.okd.thelab.lan && nslookup console-openshift-console.apps.okd.thelab.lan`
  - Monitor: `openshift-install wait-for bootstrap-complete` then `wait-for install-complete`
  - See `proxmox/okd/OKD_4.20_DEPLOYMENT.md` and `proxmox/okd/DHCP_CONFIGURATION.md`
- **OKD Deployment (Alternative methods):**
  - Assisted Service: See `proxmox/okd/DEPLOYMENT.md`
  - Ansible: `ansible-playbook -i proxmox/okd/inventory.ini proxmox/okd/playbook.yml --vault-password-file proxmox/okd/.vault_pass.txt`
- **Proxmox VM Management:**
  - Create: `ssh root@192.168.2.196 "qm create <vmid> --name <name> --memory <mb> --cores <n> --agent enabled=1 --serial0 socket ..."`
  - Start/Stop: `ssh root@192.168.2.196 "qm start|stop <vmid>"`
  - Status: `ssh root@192.168.2.196 "qm status <vmid>"`
  - Serial Console: `ssh root@192.168.2.196 "qm terminal <vmid>"` (Ctrl+O to exit)
- **Documentation:** Update `DEPLOYMENT.md`, `README.md`, and this file as workflows evolve.

## Integration Points
- **Proxmox:** Use API credentials or CLI tools. Never store credentials in plaintext.
- **Ansible Vault:** Required for all secret management.
- **UniFi DNS Automation:** 
  - Static DNS records are created via UniFi controller REST API using API key authentication stored in `.unifi_api_key`
  - **CRITICAL**: DNS records must be created with `"enabled": true` or they will not resolve
  - **Required fields** for A records: `enabled` (true), `key` (FQDN), `record_type` ("A"), `value` (IP), `port` (0), `priority` (0), `ttl` (0 for default), `weight` (0)
  - API endpoint: `https://192.168.2.1/proxy/network/v2/api/site/default/static-dns`
  - Headers: `X-API-KEY: <api_key>`, `Content-Type: application/json`
  - See `proxmox/k3s/UNIFI_DNS_AUTOMATION.md` for complete implementation details
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
