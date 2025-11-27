#!/bin/bash
set -e

AUTHENTIK_URL="https://authentik.thelab.lan"
AUTHENTIK_TOKEN=$(cat /home/brandon/projects/homelab-helper/.authentik-api-token)

echo "Setting up Authentik Forward Authentication for Traefik..."

# Create proxy provider for forward auth
echo "Creating proxy provider..."
PROVIDER_RESPONSE=$(curl -s -k -X POST "$AUTHENTIK_URL/api/v3/providers/proxy/" \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "traefik-forward-auth",
    "authorization_flow": "824ebfb4-fe69-4d8e-a2bc-8419896fb1fd",
    "mode": "forward_single",
    "external_host": "https://auth.thelab.lan"
  }')

PROVIDER_ID=$(echo "$PROVIDER_RESPONSE" | jq -r '.pk // .id')
echo "Provider created with ID: $PROVIDER_ID"

# Create application for forward auth
echo "Creating application..."
APP_RESPONSE=$(curl -s -k -X POST "$AUTHENTIK_URL/api/v3/core/applications/" \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Traefik Forward Auth\",
    \"slug\": \"traefik-forward-auth\",
    \"provider\": $PROVIDER_ID,
    \"meta_launch_url\": \"https://dashboard.thelab.lan\",
    \"policy_engine_mode\": \"any\"
  }")

APP_SLUG=$(echo "$APP_RESPONSE" | jq -r '.slug')
echo "Application created: $APP_SLUG"

# Create outpost for forward auth
echo "Creating outpost..."
OUTPOST_RESPONSE=$(curl -s -k -X POST "$AUTHENTIK_URL/api/v3/outposts/instances/" \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"traefik-forward-auth-outpost\",
    \"type\": \"proxy\",
    \"providers\": [$PROVIDER_ID],
    \"config\": {
      \"authentik_host\": \"$AUTHENTIK_URL/\",
      \"authentik_host_insecure\": true,
      \"log_level\": \"info\",
      \"docker_labels\": null,
      \"docker_network\": null,
      \"container_image\": null,
      \"kubernetes_replicas\": 1,
      \"kubernetes_namespace\": \"authentik\"
    }
  }")

OUTPOST_ID=$(echo "$OUTPOST_RESPONSE" | jq -r '.pk // .id')
echo "Outpost created with ID: $OUTPOST_ID"

echo ""
echo "Forward auth setup complete!"
echo "Provider ID: $PROVIDER_ID"
echo "Application: $APP_SLUG"
echo "Outpost ID: $OUTPOST_ID"
echo ""
echo "Next steps:"
echo "1. Deploy the outpost to K3s"
echo "2. Create Traefik middleware"
echo "3. Apply middleware to service ingresses"
