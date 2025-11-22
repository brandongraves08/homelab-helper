#!/usr/bin/env bash
set -euo pipefail

echo "This helper prints and can optionally run commands to install dependencies for Proxmox → OKD automation."
echo
echo "If you prefer, inspect this script and run the commands manually."
echo
read -rp "Do you want this script to attempt installing packages (requires sudo)? [y/N] " DO_INSTALL

run_cmd() {
  echo "+ $*"
  if [[ "$DO_INSTALL" =~ ^[Yy]$ ]]; then
    sudo bash -c "$*"
  fi
}

if command -v dnf >/dev/null 2>&1; then
  echo "Detected DNF/Fedora/RHEL"
  echo "Recommended commands:"
  echo "  sudo dnf install -y python3 python3-pip python3-venv openssl"
  echo "  sudo dnf install -y ansible || sudo pip3 install --upgrade 'ansible'"
  echo "  pip3 install --user proxmoxer"
  if [[ "$DO_INSTALL" =~ ^[Yy]$ ]]; then
    run_cmd "dnf install -y python3 python3-pip python3-venv openssl"
    if ! command -v ansible >/dev/null 2>&1; then
      run_cmd "dnf install -y ansible || pip3 install --user ansible"
    fi
    run_cmd "pip3 install --user proxmoxer"
  fi
elif command -v apt-get >/dev/null 2>&1; then
  echo "Detected Debian/Ubuntu"
  echo "Recommended commands:"
  echo "  sudo apt-get update"
  echo "  sudo apt-get install -y python3 python3-pip python3-venv openssl"
  echo "  sudo apt-get install -y ansible || sudo pip3 install --upgrade 'ansible'"
  echo "  pip3 install --user proxmoxer"
  if [[ "$DO_INSTALL" =~ ^[Yy]$ ]]; then
    run_cmd "apt-get update"
    run_cmd "apt-get install -y python3 python3-pip python3-venv openssl"
    if ! command -v ansible >/dev/null 2>&1; then
      run_cmd "apt-get install -y ansible || pip3 install --user ansible"
    fi
    run_cmd "pip3 install --user proxmoxer"
  fi
elif command -v brew >/dev/null 2>&1; then
  echo "Detected Homebrew (macOS)"
  echo "Recommended commands:"
  echo "  brew update"
  echo "  brew install python openssl"
  echo "  pip3 install --user proxmoxer ansible"
  if [[ "$DO_INSTALL" =~ ^[Yy]$ ]]; then
    run_cmd "brew update"
    run_cmd "brew install python openssl"
    run_cmd "pip3 install --user proxmoxer ansible"
  fi
else
  echo "Unknown package manager. Please install the following manually:"
  echo "  - Python 3, pip, and virtualenv"
  echo "  - Ansible (ansible-vault)"
  echo "  - proxmoxer (pip: proxmoxer)"
fi

echo
echo "After installing, you can create a Python virtualenv and install Python deps locally:"
echo "  python3 -m venv .venv && source .venv/bin/activate && pip install -r proxmox/okd/requirements.txt"

echo "Install helper finished."
