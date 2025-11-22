#!/bin/bash
set -euo pipefail

# Deploy and install assisted-service as a systemd service

cd ~/okd-assisted-service

# Stop any existing deployment
podman pod rm -f assisted-installer 2>/dev/null || true
systemctl --user stop pod-assisted-installer.service 2>/dev/null || true

# Deploy with podman play kube to generate the pod
podman play kube --configmap okd-configmap.yml pod.yml

# Generate systemd service files
cd ~ 
podman generate systemd --files --name assisted-installer

# Install systemd service
mkdir -p ~/.config/systemd/user/
mv -f pod-assisted-installer.service ~/.config/systemd/user/ 2>/dev/null || true
mv -f container-assisted-installer-*.service ~/.config/systemd/user/ 2>/dev/null || true

# Enable lingering so services start on boot
loginctl enable-linger $USER

# Reload and enable the service
systemctl --user daemon-reload
systemctl --user enable pod-assisted-installer.service
systemctl --user restart pod-assisted-installer.service

echo "✓ Assisted Installer installed as systemd service"
echo ""
echo "Service endpoints:"
echo "  - UI:            http://192.168.2.205:8080"
echo "  - API:           http://192.168.2.205:8090"
echo "  - Image Service: http://192.168.2.205:8888"
echo ""
echo "Manage service:"
echo "  Status: systemctl --user status pod-assisted-installer"
echo "  Logs:   journalctl --user -u pod-assisted-installer -f"
echo "  Stop:   systemctl --user stop pod-assisted-installer"
echo "  Start:  systemctl --user start pod-assisted-installer"
