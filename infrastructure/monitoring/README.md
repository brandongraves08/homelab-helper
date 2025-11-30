# Monitoring Configuration

Helm values and manifests in this directory configure Grafana and Prometheus for the homelab. Secrets must not be stored in plaintext—use Kubernetes secrets for sensitive data.

## Secure Grafana OAuth Setup

1. Create a secret containing the Authentik OAuth client secret:
   ```bash
   kubectl create secret generic grafana-oauth-secret \
     -n monitoring \
     --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET='<client-secret>'
   ```
2. Deploy Grafana with the provided values file. Choose the command that matches the chart you use:
   - Standalone Grafana chart:
     ```bash
     helm upgrade --install grafana grafana/grafana \
       -n monitoring \
       -f infrastructure/monitoring/grafana-oauth-values.yml
     ```
   - kube-prometheus-stack (applies the same OAuth block under the `grafana` key):
     ```bash
     helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
       -n monitoring \
       -f infrastructure/monitoring/prometheus-values.yaml \
       -f infrastructure/monitoring/grafana-oauth-values.yml
     ```
3. Verify login via Authentik at https://grafana.thelab.lan.

The values file references the secret via `envFromSecret` and reads the secret through the `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` environment variable, preventing the client secret from being committed to the repository.
