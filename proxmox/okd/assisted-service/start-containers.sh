#!/bin/bash
set -euo pipefail

# Start containers with proper ordering and restart policies

cd ~/okd-assisted-service

# Parse configmap into environment variables (preserve JSON values)
CONFIG_ENV=$(mktemp)
# Extract values from YAML, preserving quotes for JSON strings
grep -E '^\s+[A-Z_]+:' okd-configmap.yml | while IFS=: read -r key value; do
    key=$(echo "$key" | tr -d ' ')
    value=$(echo "$value" | sed 's/^ *//')
    # If value starts with ' or ", it's a string value - keep the quotes but unquote the outer layer
    if [[ "$value" == \'*\' ]]; then
        value="${value:1:-1}"  # Remove outer single quotes
    fi
    echo "$key=$value"
done > "$CONFIG_ENV"

# Stop existing pod
podman pod rm -f assisted-installer 2>/dev/null || true

# Create pod with port mappings
podman pod create \
    --name assisted-installer \
    -p 8080:8080 \
    -p 8090:8090 \
    -p 8888:8888

# Start PostgreSQL and wait for it to be ready
podman run -d \
    --pod assisted-installer \
    --name assisted-installer-db \
    --restart=always \
    --env-file "$CONFIG_ENV" \
    quay.io/sclorg/postgresql-12-c8s:latest \
    run-postgresql

echo "Waiting for PostgreSQL to be ready..."
sleep 10

# Verify PostgreSQL is accepting connections
for i in {1..30}; do
    if podman exec assisted-installer-db pg_isready -U admin &>/dev/null; then
        echo "PostgreSQL is ready!"
        break
    fi
    echo "Still waiting... ($i/30)"
    sleep 2
done

# Start UI
podman run -d \
    --pod assisted-installer \
    --name assisted-installer-ui \
    --restart=always \
    --env-file "$CONFIG_ENV" \
    quay.io/edge-infrastructure/assisted-installer-ui:latest

# Start Image Service
podman run -d \
    --pod assisted-installer \
    --name assisted-installer-image-service \
    --restart=always \
    --env-file "$CONFIG_ENV" \
    quay.io/edge-infrastructure/assisted-image-service:latest

# Start Main Service (last, so DB is definitely ready)
podman run -d \
    --pod assisted-installer \
    --name assisted-installer-service \
    --restart=always \
    --env-file "$CONFIG_ENV" \
    quay.io/edge-infrastructure/assisted-service:latest

rm -f "$CONFIG_ENV"

echo ""
echo "✓ All services started!"
echo ""
echo "Service endpoints:"
echo "  - UI:            http://192.168.2.205:8080"
echo "  - API:           http://192.168.2.205:8090"
echo "  - Image Service: http://192.168.2.205:8888"
echo ""
echo "Check status: podman pod ps && podman ps"
echo "View logs: podman logs assisted-installer-service"
