# Homelab Helper

Homelab Helper is an automation tool designed to simplify and secure the management of your homelab infrastructure. It leverages Ansible Vault for secret management and integrates with Proxmox to automate virtual machine and infrastructure tasks.

## Recent Success 🎉
**OKD Single Node OpenShift** successfully deployed on Proxmox in 20 minutes using Assisted Service method! See [proxmox/okd/SUCCESSFUL_DEPLOYMENT.md](./proxmox/okd/SUCCESSFUL_DEPLOYMENT.md) for the complete proven workflow.

## Features
- **Automated Homelab Management:** Streamline common tasks such as VM creation, backup, and monitoring.
- **Secure Secret Handling:** All passwords and sensitive data are managed using Ansible Vault—never stored in plaintext.
- **Proxmox Integration:** Connects to Proxmox via API or CLI (`pvesh`, `qm`, or `proxmoxer` Python library) to manage VMs and resources.
- **Minimal User Prompts:** Only asks for user input when absolutely necessary; defaults to automation and self-service.
- **Self-Learning:** Learns from actions and updates itself to reduce manual steps over time.
 - **Do It Yourself:** Never ask the user to do something you can do yourself. Attempt to perform actions automatically when safe; for privileged operations, prompt for confirmation or credentials instead of asking the user to perform the step manually.

## Getting Started
1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd homelab-helper
   ```
2. **Set up Ansible Vault:**
   - Ensure you have Ansible installed and initialize your vault password file.
   - Store all secrets using `ansible-vault encrypt`.
3. **Configure Proxmox Access:**
   - Provide API credentials or CLI access as required (never in plaintext).
   - Update configuration files as needed.
4. **Run automation tasks:**
   - Use provided scripts or playbooks to manage your homelab.

## Example Usage
- Encrypt a password:
  ```bash
  ansible-vault encrypt_string 'yourpassword' --name 'proxmox_password'
  ```
- Run a Proxmox VM task (example):
  ```bash
  python scripts/manage_vm.py --action start --vmid 100
  ```

## Contributing
- Follow the conventions in `.github/copilot-instructions.md`.
- Document new workflows, integrations, or patterns as the project evolves.

## License
MIT License
