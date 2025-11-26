# UniFi DNS Automation via REST API

**Last Updated:** November 25, 2025  
**Issue Resolved:** 403 Forbidden errors when creating DNS records via UniFi controller API

## Problem Summary

When attempting to create static DNS records programmatically via the UniFi Dream Machine's REST API, POST requests to `/proxy/network/v2/api/site/default/static-dns` returned:

```json
{"error": {"code": 403, "message": "Forbidden"}}
```

Despite:
- ✅ Successful authentication (HTTP 200 login response)
- ✅ Admin role with `network.management` permissions
- ✅ Valid CSRF token extracted from JWT
- ✅ Proper `Content-Type: application/json` header
- ✅ Working GET requests (could retrieve existing DNS records)

## Root Cause

**Incomplete API payload.** The UniFi controller requires **ALL fields** in the DNS record payload, even for A records where some fields (like `port`, `priority`, `weight`) are not logically needed.

Sending only the essential fields:
```python
# ❌ INCOMPLETE - Returns 403 Forbidden
{
    'key': 'grafana.thelab.lan',
    'record_type': 'A',
    'value': '192.168.2.250'
}
```

Results in 403 Forbidden, with no helpful error message indicating which fields are missing.

## Solution

Include **all required fields** in the payload:

```python
# ✅ COMPLETE - Successfully creates DNS record
{
    'key': 'grafana.thelab.lan',
    'record_type': 'A',
    'value': '192.168.2.250',
    'port': 0,        # Required even for A records
    'priority': 0,    # Required even for A records
    'ttl': 0,         # Required (0 = use default TTL)
    'weight': 0       # Required even for A records
}
```

## Working Implementation

### Authentication Flow

```python
import requests
import json
import base64
import urllib3

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Create session
session = requests.Session()
session.verify = False  # Self-signed cert on UniFi controller

# Step 1: Login to UniFi controller
login_response = session.post(
    'https://192.168.2.1/api/auth/login',
    json={
        'username': 'your_username',
        'password': 'your_password'
    }
)

if login_response.status_code != 200:
    raise Exception(f"Login failed: {login_response.status_code}")

# Step 2: Extract CSRF token from JWT cookie
token = login_response.cookies.get('TOKEN')
if not token:
    raise Exception("No TOKEN cookie received")

# JWT has 3 parts separated by dots: header.payload.signature
# We need the payload (middle part)
payload = token.split('.')[1]

# Base64 decode requires padding
payload += '=' * (4 - len(payload) % 4)

# Decode and parse JSON
decoded = json.loads(base64.b64decode(payload))
csrf_token = decoded.get('csrfToken')

if not csrf_token:
    raise Exception("No csrfToken found in JWT")

print(f"✓ Authenticated successfully, CSRF token: {csrf_token[:20]}...")
```

### Creating DNS A Records

```python
# DNS records to create
dns_records = [
    {'hostname': 'grafana', 'ip': '192.168.2.250'},
    {'hostname': 'argocd', 'ip': '192.168.2.250'},
    {'hostname': 'vault', 'ip': '192.168.2.250'},
    {'hostname': 'harbor', 'ip': '192.168.2.250'},
    {'hostname': 'prometheus', 'ip': '192.168.2.250'},
]

# API endpoint
api_url = 'https://192.168.2.1/proxy/network/v2/api/site/default/static-dns'

# Create each DNS record
for record in dns_records:
    fqdn = f"{record['hostname']}.thelab.lan"
    
    # CRITICAL: Include ALL fields
    payload = {
        'key': fqdn,
        'record_type': 'A',
        'value': record['ip'],
        'port': 0,        # Required
        'priority': 0,    # Required
        'ttl': 0,         # Required (0 = default)
        'weight': 0       # Required
    }
    
    response = session.post(
        api_url,
        json=payload,
        headers={
            'X-CSRF-Token': csrf_token,
            'Content-Type': 'application/json'
        }
    )
    
    if response.status_code == 200:
        print(f"✓ Created: {fqdn} → {record['ip']}")
    else:
        print(f"✗ Failed: {fqdn} - {response.status_code}: {response.text}")
```

### Verifying DNS Records

```python
# Retrieve all static DNS records
response = session.get(
    'https://192.168.2.1/proxy/network/v2/api/site/default/static-dns',
    headers={'X-CSRF-Token': csrf_token}
)

if response.status_code == 200:
    records = response.json()
    print(f"\nTotal DNS records: {len(records)}")
    for record in records:
        print(f"  {record['key']} ({record['record_type']}) → {record['value']}")
else:
    print(f"Failed to retrieve DNS records: {response.status_code}")
```

## API Reference

### Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/auth/login` | Authenticate and receive session cookies + JWT |
| GET | `/proxy/network/v2/api/site/default/static-dns` | List all static DNS records |
| POST | `/proxy/network/v2/api/site/default/static-dns` | Create new DNS record |
| PUT | `/proxy/network/v2/api/site/default/static-dns/{id}` | Update existing DNS record |
| DELETE | `/proxy/network/v2/api/site/default/static-dns/{id}` | Delete DNS record |

### Authentication

**Method:** Session-based with CSRF protection

1. **Login**: POST credentials to `/api/auth/login`
2. **Receive**: Session cookies (including `TOKEN` JWT)
3. **Extract**: Base64 decode JWT payload to get `csrfToken`
4. **Use**: Include CSRF token in `X-CSRF-Token` header for all write operations

**Note:** The Site Manager API at `api.ui.com` is different and uses `X-API-KEY` header, but that API is currently **read-only**. For local UniFi controller management, use session authentication as shown above.

### DNS Record Schema

```json
{
  "key": "string",           // FQDN (e.g., "grafana.thelab.lan")
  "record_type": "string",   // "A", "AAAA", "CNAME", "MX", "SRV", "TXT"
  "value": "string",         // IP address for A/AAAA, hostname for CNAME, etc.
  "port": 0,                 // Integer (required even for A records)
  "priority": 0,             // Integer (required even for A records)
  "ttl": 0,                  // Integer, 0 = use default TTL
  "weight": 0,               // Integer (required even for A records)
  "enabled": true            // Boolean (optional, defaults to true)
}
```

## Key Lessons Learned

### 1. API Payload Completeness
- UniFi API validates **all** required fields, even when logically unnecessary
- Missing fields result in **403 Forbidden** (not 400 Bad Request)
- Error messages don't indicate which fields are missing
- Always inspect existing records (via GET) to see the complete schema

### 2. Authentication Method
- Local console API uses **session cookies + CSRF token** (not API keys)
- Site Manager API (api.ui.com) is separate and uses **X-API-KEY** header
- Site Manager API is currently **read-only** for DNS operations
- CSRF token must be extracted from JWT payload (base64 decode)

### 3. Error Handling
- 403 Forbidden can mean:
  - Incomplete payload
  - Missing CSRF token
  - Invalid session
  - Insufficient permissions
- 200 OK login doesn't guarantee write permissions
- Always verify admin role has `network.management` permissions

### 4. Testing Strategy
- Start with GET requests to verify authentication
- Inspect existing records to understand required schema
- Test POST with complete payload matching GET response structure
- Verify DNS resolution with `nslookup` after creation

## Verification

After creating DNS records, verify they work:

```bash
# Check DNS resolution (query UniFi DNS server directly)
for host in grafana argocd vault harbor prometheus; do
    echo -n "$host.thelab.lan: "
    nslookup $host.thelab.lan 192.168.2.1 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}'
done
```

Expected output:
```
grafana.thelab.lan: 192.168.2.250
argocd.thelab.lan: 192.168.2.250
vault.thelab.lan: 192.168.2.250
harbor.thelab.lan: 192.168.2.250
prometheus.thelab.lan: 192.168.2.250
```

## Related Documentation

- [K3s Deployment Guide](./README.md) - Full K3s cluster setup
- [Quick Reference](./QUICK_REFERENCE.md) - K3s cluster management commands
- [Deployment State](./K3S_DEPLOYMENT_STATE.md) - Current cluster status

## References

- UniFi Controller API is not officially documented by Ubiquiti
- Community reverse-engineering: [Art-of-WiFi/UniFi-API-client](https://github.com/Art-of-WiFi/UniFi-API-client)
- Site Manager API (read-only): https://developer.ui.com/site-manager-api/gettingstarted
- Python library (devices/clients only): https://github.com/tnware/unifi-controller-api
