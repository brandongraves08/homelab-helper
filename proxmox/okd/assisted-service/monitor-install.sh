#!/bin/bash
# OKD Installation Monitor
# Monitors the progress of OKD installation via assisted-service API

CLUSTER_ID="64de2825-c01b-4107-92f4-189901f665c5"
API_URL="http://192.168.2.205:8090/api/assisted-install/v2"

echo "========================================="
echo "OKD Installation Monitor"
echo "========================================="
echo "Cluster ID: $CLUSTER_ID"
echo "UI: http://192.168.2.205:8080"
echo "VM: 150 on Proxmox (192.168.2.196)"
echo ""

while true; do
    clear
    echo "========================================="
    echo "OKD Installation Status - $(date)"
    echo "========================================="
    
    # Get cluster status
    RESPONSE=$(curl -s "$API_URL/clusters/$CLUSTER_ID")
    
    CLUSTER_STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])" 2>/dev/null)
    CLUSTER_INFO=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['status_info'])" 2>/dev/null)
    
    echo "Cluster Status: $CLUSTER_STATUS"
    echo "Status Info: $CLUSTER_INFO"
    echo ""
    
    # Get host status
    HOST_STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; h=json.load(sys.stdin)['hosts'][0]; print(h['status'])" 2>/dev/null)
    HOST_INFO=$(echo "$RESPONSE" | python3 -c "import sys, json; h=json.load(sys.stdin)['hosts'][0]; print(h['status_info'])" 2>/dev/null)
    HOST_PROGRESS=$(echo "$RESPONSE" | python3 -c "import sys, json; h=json.load(sys.stdin)['hosts'][0]; print(h.get('progress', {}).get('current_stage', 'N/A'))" 2>/dev/null)
    
    echo "Host Status: $HOST_STATUS"
    echo "Host Info: $HOST_INFO"
    echo "Current Stage: $HOST_PROGRESS"
    echo ""
    
    # Check if installation is complete
    if [[ "$CLUSTER_STATUS" == "installed" ]] || [[ "$CLUSTER_STATUS" == "error" ]]; then
        echo "========================================="
        echo "Installation Complete!"
        echo "Final Status: $CLUSTER_STATUS"
        echo "========================================="
        break
    fi
    
    echo "Refreshing in 30 seconds... (Ctrl+C to exit)"
    sleep 30
done
