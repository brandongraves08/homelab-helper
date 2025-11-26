# Dashy Dashboard

Centralized homelab dashboard with links to all services and infrastructure.

## Deployment

```bash
# Deploy to K3s
ssh centos@192.168.2.250 'cat > /tmp/dashy-deployment.yml' < infrastructure/dashboard/dashy-deployment.yml
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl apply -f /tmp/dashy-deployment.yml'

# Check status
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl get pods -n dashboard'
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl logs -n dashboard deployment/dashy'
```

## Access

- **URL**: https://dashboard.thelab.lan
- **Namespace**: dashboard
- **Port**: 8080 (internal), 80/443 (ingress)

## Configuration

The dashboard configuration is stored in a ConfigMap (`dashy-config`) with the following sections:

### Infrastructure
- Proxmox VE (https://192.168.2.196:8006)
- UniFi Controller (https://192.168.2.1)
- Synology NAS (https://192.168.2.220:5001)

### Kubernetes
- K3s Dashboard
- Traefik Dashboard

### Monitoring
- Grafana
- Prometheus
- Loki

### Security & Authentication
- Authentik (SSO)
- Vault (Secret Management)

### Container Registry
- Harbor

## Customization

To update the dashboard configuration:

1. Edit the ConfigMap in `dashy-deployment.yml`
2. Apply changes:
   ```bash
   ssh centos@192.168.2.250 'cat > /tmp/dashy-deployment.yml' < infrastructure/dashboard/dashy-deployment.yml
   ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl apply -f /tmp/dashy-deployment.yml'
   ```
3. Restart the pod to pick up changes:
   ```bash
   ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl rollout restart deployment/dashy -n dashboard'
   ```

## Features

- **Status Checks**: Automatic health checks for all services (60s interval)
- **Dark Theme**: Nord Frost theme enabled by default
- **Search**: Full-text search across all services
- **Auto Layout**: Responsive layout adapting to screen size
- **Icons**: Homelab-specific icons for common services

## Troubleshooting

### Pod Restarts / Long Startup Times

**Issue**: Dashy's default entrypoint runs `yarn build` on every startup which takes 60-120 seconds and causes pod restarts.

**Solution**: The deployment uses `command: ["node", "server"]` to skip the build process and start the server immediately.

**Required Probe Timings**:
- Liveness Probe: `initialDelaySeconds: 120` (allows time for server startup)
- Readiness Probe: `initialDelaySeconds: 60` (allows time for server to be ready)

### Common Commands

```bash
# Check pod logs
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl logs -n dashboard deployment/dashy'

# Check ingress
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl get ingress -n dashboard'

# Restart deployment
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl rollout restart deployment/dashy -n dashboard'

# Delete and redeploy
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl delete -f /tmp/dashy-deployment.yml'
ssh centos@192.168.2.250 'sudo /usr/local/bin/k3s kubectl apply -f /tmp/dashy-deployment.yml'
```

### DNS Issues

If `dashboard.thelab.lan` doesn't resolve, verify the UniFi DNS record is enabled:
- API endpoint: `https://192.168.2.1/proxy/network/v2/api/site/default/static-dns`
- Required field: `"enabled": true`
- See `proxmox/k3s/UNIFI_DNS_AUTOMATION.md` for automation details

## Adding New Services

To add new services to the dashboard:

1. Edit the `conf.yml` section in the ConfigMap
2. Add new items under the appropriate section or create a new section:
   ```yaml
   - name: New Section
     icon: fas fa-icon-name
     items:
       - title: Service Name
         description: Service description
         url: https://service.thelab.lan
         icon: hl-icon-name
         statusCheck: true
   ```
3. Apply the updated ConfigMap
4. Restart the deployment

## Resources

- **Memory**: 256Mi request, 512Mi limit
- **CPU**: 100m request, 500m limit
- **Storage**: 1Gi PVC for configuration persistence

## Documentation

- Dashy Documentation: https://dashy.to/docs/
- Icon Sets: https://dashy.to/docs/icons
- Themes: https://dashy.to/docs/theming
