# Authentik OAuth SSO Setup

This directory contains configuration for setting up OAuth/OIDC Single Sign-On with Authentik for homelab services.

## Overview

Instead of using forward authentication (which had configuration issues), we use OAuth/OIDC providers for each service. This provides reliable SSO with proper token handling.

## Architecture

- **Authentik**: Central identity provider (IdP) at `https://authentik.thelab.lan`
- **OAuth Providers**: Individual OAuth2/OIDC providers configured in Authentik for each service
- **Client Applications**: Services (Grafana, Harbor, ArgoCD) configured as OAuth clients

## Deployed Services

### Grafana
- **Provider**: GRAFANA OIDC (ID: 1)
- **Client ID**: `grafana`
- **Redirect URIs**: 
  - `https://grafana.thelab.lan/login/generic_oauth`
- **Configuration**: Environment variables in deployment
  - `GF_AUTH_GENERIC_OAUTH_ENABLED=true`
  - Uses Authentik userinfo endpoint
  - Role mapping: Groups → Grafana roles
- **Status**: ✅ Working

### Harbor
- **Provider**: HARBOR OIDC (ID: 2)
- **Client ID**: `harbor`
- **Redirect URIs**: `https://harbor.thelab.lan/c/oidc/callback`
- **Status**: Configured

### ArgoCD
- **Provider**: ARGOCD OIDC (ID: 3)
- **Client ID**: `argocd`
- **Redirect URIs**: `https://argocd.thelab.lan/auth/callback`
- **Status**: Configured

## Setup Process

### 1. Create OAuth Provider in Authentik

```bash
curl -k -X POST "https://authentik.thelab.lan/api/v3/providers/oauth2/" \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "SERVICE_NAME OIDC",
    "client_id": "service-name",
    "authorization_flow": "a42f84e3-cbd5-4bbc-86dc-6fd7da02cce6",
    "invalidation_flow": "698cf862-34ef-4c24-8c3f-4d3a3338d907",
    "redirect_uris": ["https://service.thelab.lan/oauth/callback"]
  }'
```

### 2. Create Application in Authentik

```bash
curl -k -X POST "https://authentik.thelab.lan/api/v3/core/applications/" \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Service Name",
    "slug": "service-name",
    "provider": <provider_id>,
    "meta_launch_url": "https://service.thelab.lan"
  }'
```

### 3. Configure Service OAuth Client

Each service needs to be configured with:
- **Client ID**: From Authentik provider
- **Client Secret**: From Authentik provider
- **Issuer URL**: `https://authentik.thelab.lan/application/o/<application-slug>/`
- **Authorization URL**: `https://authentik.thelab.lan/application/o/authorize/`
- **Token URL**: `https://authentik.thelab.lan/application/o/token/`
- **UserInfo URL**: `https://authentik.thelab.lan/application/o/userinfo/`
- **Scopes**: `openid profile email`

## API Endpoints

- **Authorization**: `https://authentik.thelab.lan/application/o/authorize/`
- **Token**: `https://authentik.thelab.lan/application/o/token/`
- **UserInfo**: `https://authentik.thelab.lan/application/o/userinfo/`
- **JWKS**: `https://authentik.thelab.lan/application/o/<app-slug>/jwks/`

## Troubleshooting

### OAuth Login Not Appearing
1. Check service configuration has OAuth enabled
2. Verify client ID and secret are correct
3. Ensure redirect URIs match exactly
4. Check Authentik application is active

### Authentication Fails
1. Verify TLS skip verification is enabled (for self-signed certs)
2. Check Authentik logs: `kubectl logs -n authentik -l app.kubernetes.io/name=authentik-server`
3. Verify scopes include required claims
4. Check token endpoint is accessible from service pod

### Role Mapping Not Working
1. Verify groups exist in Authentik
2. Check role attribute path in service config
3. Ensure users are assigned to groups
4. Review service-specific role mapping syntax

## Files

- `forward-auth-outpost.yml`: Attempted forward auth setup (not used)
- `traefik-middleware.yml`: Attempted Traefik middleware (not used)
- `grafana-oauth-values.yml`: Grafana OAuth configuration values
- `setup-forward-auth.sh`: Script for forward auth setup (deprecated)

## Forward Auth Status

Forward authentication was attempted but encountered issues with `forward_domain` mode:
- Outpost deployed and connected via WebSocket
- Provider configured but returning 400 "no app for hostname"
- Decision: Use per-service OAuth providers instead (more reliable)

## Next Steps

1. Apply OAuth to remaining services (Prometheus, Vault)
2. Configure Authentik groups for role-based access
3. Set up Authentik backup/restore
4. Consider using Authentik Proxy Provider for services without native OAuth support
