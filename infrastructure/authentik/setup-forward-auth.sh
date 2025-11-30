#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOKEN_FILE="$REPO_ROOT/.authentik-api-token"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not found. Please install curl and retry." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not found. Please install jq and retry." >&2
  exit 1
fi

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Authentik API token file not found at $TOKEN_FILE. Create it with 600 permissions containing the bearer token." >&2
  exit 1
fi

AUTHENTIK_URL="https://authentik.thelab.lan"
AUTHENTIK_TOKEN=$(<"$TOKEN_FILE")
AUTHENTIK_TOKEN=$(echo "$AUTHENTIK_TOKEN" | tr -d '\r\n')

if [[ -z "$AUTHENTIK_TOKEN" ]]; then
  echo "Authentik API token file is empty. Populate $TOKEN_FILE with a valid token." >&2
  exit 1
fi

post_json() {
  local endpoint="$1"
  local body="$2"

  local response
  local status

  response=$(mktemp)
  status=$(curl -s -k -w "%{http_code}" -o "$response" -X POST "$AUTHENTIK_URL$endpoint" \
    -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body")

  if [[ $status != 2* ]]; then
    echo "API request to $endpoint failed with status $status" >&2
    echo "Response body:" >&2
    cat "$response" >&2
    rm -f "$response"
    exit 1
  fi

  cat "$response"
  rm -f "$response"
}

echo "Setting up Authentik Forward Authentication for Traefik..."

echo "Creating proxy provider..."
PROVIDER_RESPONSE=$(post_json "/api/v3/providers/proxy/" '{
    "name": "traefik-forward-auth",
    "authorization_flow": "824ebfb4-fe69-4d8e-a2bc-8419896fb1fd",
    "mode": "forward_single",
    "external_host": "https://auth.thelab.lan"
  }')

PROVIDER_ID=$(echo "$PROVIDER_RESPONSE" | jq -r '.pk // .id')
if [[ -z "$PROVIDER_ID" || "$PROVIDER_ID" == "null" ]]; then
  echo "Failed to parse provider ID from response" >&2
  echo "$PROVIDER_RESPONSE" >&2
  exit 1
fi
echo "Provider created with ID: $PROVIDER_ID"

echo "Creating application..."
APP_RESPONSE=$(post_json "/api/v3/core/applications/" "{
    \"name\": \"Traefik Forward Auth\",
    \"slug\": \"traefik-forward-auth\",
    \"provider\": $PROVIDER_ID,
    \"meta_launch_url\": \"https://dashboard.thelab.lan\",
    \"policy_engine_mode\": \"any\"
  }")

APP_SLUG=$(echo "$APP_RESPONSE" | jq -r '.slug')
if [[ -z "$APP_SLUG" || "$APP_SLUG" == "null" ]]; then
  echo "Failed to parse application slug from response" >&2
  echo "$APP_RESPONSE" >&2
  exit 1
fi
echo "Application created: $APP_SLUG"

echo "Creating outpost..."
OUTPOST_RESPONSE=$(post_json "/api/v3/outposts/instances/" "{
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
if [[ -z "$OUTPOST_ID" || "$OUTPOST_ID" == "null" ]]; then
  echo "Failed to parse outpost ID from response" >&2
  echo "$OUTPOST_RESPONSE" >&2
  exit 1
fi
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
