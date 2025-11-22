
Proxmox → OKD automation

This folder contains automation scaffolding to provision OKD on Proxmox.

**📖 NEW: See [SUCCESSFUL_DEPLOYMENT.md](./SUCCESSFUL_DEPLOYMENT.md) for the proven deployment method that worked on November 21, 2025. Uses Assisted Service on Proxmox - ~20 minute deployment time.**

Important: do NOT commit `vault.yml` (it contains sensitive credentials).

Dependencies
 - System package manager or Python + pip
 - Ansible (for playbooks / ansible-vault)
 - Python 3 and `proxmoxer` (optional, for direct Proxmox API scripting)
 - `openssl` (used by helper scripts to generate secrets)

Recommended local setup
 - Run the `install_deps.sh` script in this directory to install or print the commands
	 needed for your platform. The script will not commit or change repo files — it
	 only installs tools on your machine (requires `sudo` for system package installs).

Create the Ansible vault (local)
1. Ensure `ansible-vault` is available (see the install script below).
2. Run the helper script to create the vault file locally (it will generate a
	 random local vault password file and write `proxmox/okd/vault.yml`):

```bash
bash proxmox/okd/vault_create.sh
```

Notes about the install script
 - The script `install_deps.sh` contains platform-specific commands for Fedora/RHEL,
	 Debian/Ubuntu and macOS. It attempts to be helpful but will prompt before making
	 any privileged changes. If your environment uses a different package manager,
	 run the equivalent commands manually.
 - You can also install Python dependencies into a virtualenv using `requirements.txt`:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r proxmox/okd/requirements.txt
```

Next steps (after vault is created):
 - Populate `inventory.ini` with your control host if needed.
 - Edit `playbook.yml` with the Proxmox node, storage, and networking details.
 - Run the playbook from a machine with network access to Proxmox; include the
	 vault password file if you used the helper script:

```bash
ansible-playbook -i proxmox/okd/inventory.ini proxmox/okd/playbook.yml \
	--vault-password-file proxmox/okd/.vault_pass.txt
```

See `playbook.yml` for a starting point and `install_deps.sh` for install commands.

---

## Alternative: OKD Deployment with Assisted Service (Podman)

A simpler approach using OpenShift's Assisted Installer service running on ubuntu.thelab.lan bastion host:

### Prerequisites
- Podman 3.3+ on ubuntu.thelab.lan (192.168.2.205)
- SSH access to ubuntu.thelab.lan from your workstation
- DNS configured on UDM for thelab.lan domain

### Quick Start

1. **Deploy Assisted Service to Bastion**
   ```bash
   cd proxmox/okd/assisted-service
   ./deploy-to-proxmox.sh
   ```

   This deploys the assisted installer pod on ubuntu.thelab.lan with:
   - **UI**: http://192.168.2.205:8080 (or http://ubuntu.thelab.lan:8080)
   - **API**: http://192.168.2.205:8090
   - **Image Service**: http://192.168.2.205:8888

2. **Configure OKD Cluster via UI**
   - Open http://192.168.2.205:8080 in your browser
   - Create new cluster:
     - **Cluster Name**: okd
     - **Base Domain**: thelab.lan
     - **OpenShift Version**: 4.16.0-0.okd-scos-2024-11-16-051944
   - Download discovery ISO
   - Create VM on Proxmox with ISO attached
   - Boot and complete installation via UI

3. **Stop Assisted Service** (when done)
   ```bash
   ssh brandon@ubuntu.thelab.lan
   cd ~/okd-assisted-service
   podman play kube --down pod.yml
   ```

### Network Configuration

The assisted service runs on the bastion host within the lab network:
- **Subnet**: 192.168.2.0/24
- **DNS Domain**: thelab.lan
- **Bastion Host**: ubuntu.thelab.lan (192.168.2.205) - runs assisted-service
- **Proxmox**: 192.168.2.196
- **Target OKD Node**: 192.168.2.50
- **Gateway**: 192.168.2.1 (UDM)

### Files

- `assisted-service/okd-configmap.yml` - OKD configuration with network settings
- `assisted-service/pod.yml` - Podman pod manifest
- `assisted-service/deploy-to-proxmox.sh` - Remote deployment script to bastion
- `assisted-service/check_prereqs.sh` - Prerequisites validation

### Advantages

- ✅ Web-based UI for cluster configuration
- ✅ Automatic validation of hardware requirements
- ✅ Built-in monitoring and health checks
- ✅ Discovery ISO automatically generated
- ✅ No manual ignition file generation needed
- ✅ Step-by-step guided installation

### Documentation

Based on: https://github.com/openshift/assisted-service/tree/master/deploy/podman

See `assisted-service/` directory for implementation details.


````

