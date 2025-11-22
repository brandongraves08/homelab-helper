# OKD Single Node OpenShift Deployment

This directory contains the generated configuration files for deploying OKD 4.20.0-okd-scos.9 as a Single Node OpenShift (SNO) cluster on Proxmox.

## Generated Files

- `bootstrap-in-place-for-live-iso.ign` - Ignition configuration for single-node bootstrap
- `metadata.json` - Cluster metadata
- `worker.ign` - Worker ignition configuration
- `auth/` - Contains kubeconfig and kubeadmin password (after installation)

## Deployment Steps

1. **Prepare install-config.yaml** (see install-config.yaml.example)
2. **Generate ignition config:**
   ```bash
   ../installer/openshift-install create single-node-ignition-config
   ```

3. **Embed ignition into ISO:**
   ```bash
   sudo podman run --privileged --pull always --rm \
     -v /dev:/dev -v /run/udev:/run/udev -v "$PWD":"$PWD" -w "$PWD" \
     quay.io/coreos/coreos-installer:release \
     iso ignition embed -fi bootstrap-in-place-for-live-iso.ign fcos-live.iso
   ```

4. **Upload ISO to Proxmox:**
   ```bash
   scp fcos-live.iso root@192.168.2.196:/var/lib/vz/template/iso/okd-sno-4.20.iso
   ```

5. **Create VM on Proxmox:**
   ```bash
   ssh root@192.168.2.196 "qm create 200 \
     --name okd4sno \
     --memory 32768 \
     --cores 8 \
     --cpu host \
     --net0 virtio,bridge=vmbr0 \
     --scsihw virtio-scsi-single \
     --scsi0 local-lvm:120 \
     --ide2 local:iso/okd-sno-4.20.iso,media=cdrom \
     --boot order=ide2 \
     --bios ovmf \
     --efidisk0 local-lvm:1 \
     --agent enabled=1 \
     --serial0 socket"
   ```

6. **Start VM:**
   ```bash
   ssh root@192.168.2.196 "qm start 200"
   ```

7. **Monitor installation:**
   ```bash
   ../installer/openshift-install wait-for bootstrap-complete --log-level=info
   ../installer/openshift-install wait-for install-complete --log-level=info
   ```

## DNS Requirements

Configure DNS entries for:
- `api.okd4sno.thelab.lan` → VM IP
- `console-openshift-console.apps.okd4sno.thelab.lan` → VM IP
- `oauth-openshift.apps.okd4sno.thelab.lan` → VM IP
- `*.apps.okd4sno.thelab.lan` → VM IP (wildcard)

## Network Configuration

- **Cluster Network:** 10.128.0.0/14
- **Service Network:** 172.30.0.0/16
- **Machine Network:** 192.168.2.0/24
- **Installation Disk:** /dev/vda
