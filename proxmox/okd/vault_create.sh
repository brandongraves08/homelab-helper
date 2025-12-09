#!/usr/bin/env bash
set -euo pipefail

# Helper to create an Ansible Vault file with Proxmox credentials.
# This script must be run locally (it calls `ansible-vault`).

VAULT_FILE="$(dirname "$0")/vault.yml"

if ! command -v ansible-vault >/dev/null 2>&1; then
  echo "error: ansible-vault is not installed or not on PATH"
  echo "Run 'bash proxmox/okd/install_deps.sh' to see install commands."
  exit 2
fi

read -sp "Enter Ansible Vault password to use: " VAULT_PASS
echo

TMP_PASS_FILE=$(mktemp)
trap 'rm -f "$TMP_PASS_FILE"' EXIT
printf "%s" "$VAULT_PASS" > "$TMP_PASS_FILE"

echo "Encrypting proxmox credentials into $VAULT_FILE"

# Replace the values below with the correct username/password if different.
# IMPORTANT: Use your actual credentials, not hardcoded examples
read -sp "Enter Proxmox username (e.g., root@pam): " PROXMOX_USER_RAW
echo
read -sp "Enter Proxmox password: " PROXMOX_PASS_RAW
echo

USER_ENC=$(ansible-vault encrypt_string "$PROXMOX_USER_RAW" --name 'proxmox_api_user' --vault-password-file "$TMP_PASS_FILE")
PW_ENC=$(ansible-vault encrypt_string "$PROXMOX_PASS_RAW" --name 'proxmox_api_password' --vault-password-file "$TMP_PASS_FILE")

cat > "$VAULT_FILE" <<EOF
$USER_ENC

$PW_ENC
EOF

echo "Wrote $VAULT_FILE (do not commit)."
echo "Use the same vault password to run the playbook, or supply --vault-password-file when running ansible-playbook."
