# VMess-WS-Argo Subscription Generation

## Overview

This document describes the vmess-ws-argo subscription generation functionality added to `start.sh`. After the Argo tunnel is successfully set up via `argo-diagnostic.sh`, the script automatically generates VMess nodes and subscription files for easy client configuration.

## Features

### 1. VMess Node Generation
- Generates standard VMess protocol nodes with WS (WebSocket) and Argo tunnel support
- Includes all required fields: UUID, domain, port, path, TLS configuration
- Base64 encodes the node information for URL-safe representation

### 2. Subscription File Generation
- Creates subscription file at `/home/container/.npm/sub.txt`
- File contains base64-encoded VMess node information
- Compatible with subscription management tools and clients

### 3. User Output
After successful Argo tunnel setup, displays:
```
[INFO] Generating vmess-ws-argo subscription...
[✅ SUCCESS] VMESS Node: vmess://[base64...]
[✅ SUCCESS] Subscription generated
[✅ SUCCESS] Subscription URL: https://zampto.xunda.ggff.net/sub
[INFO] Subscription file: /home/container/.npm/sub.txt
```

## Implementation Details

### Functions Added to `start.sh`

#### `generate_vmess_node(domain, uuid, name)`
Generates a VMess node with the following structure:
```json
{
  "v": "2",
  "ps": "node_name",
  "add": "domain",
  "port": "443",
  "id": "uuid",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "domain",
  "path": "/ws",
  "tls": "tls"
}
```

**Parameters:**
- `domain`: CF_DOMAIN from config.json (e.g., zampto.xunda.ggff.net)
- `uuid`: UUID from config.json (e.g., 19763831-f9cb-45f2-b59a-9d60264c7f1c)
- `name`: Node name (default: zampto-node, typically set to "zampto-argo")

**Returns:**
- VMess URL: `vmess://[base64_encoded_json]`

#### `generate_subscription(node, sub_file)`
Generates a subscription file from a VMess node.

**Parameters:**
- `node`: VMess node URL (output from `generate_vmess_node()`)
- `sub_file`: Path where subscription file should be saved

**Behavior:**
- Creates parent directory if it doesn't exist
- Saves base64-encoded node to file
- Returns 0 on success, 1 on failure

#### `generate_subscription_output()`
Main function that orchestrates subscription generation.

**Behavior:**
- Validates CF_DOMAIN and UUID are set
- Generates VMess node
- Creates subscription file at `/home/container/.npm/sub.txt`
- Displays user-friendly output
- Returns 0 on success, 1 on failure

### Configuration Requirements

The following values must be present in `/home/container/config.json`:

```json
{
  "CF_DOMAIN": "your_domain.example.com",
  "UUID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

## Integration with index.js

The generated subscription file (`/home/container/.npm/sub.txt`) is designed to be served by the `index.js` HTTP server via the `/sub` endpoint:

```javascript
// In index.js (example)
app.get('/sub', (req, res) => {
  const subFile = '/home/container/.npm/sub.txt';
  res.sendFile(subFile);
});
```

This allows clients to subscribe to the VMess node via the URL:
```
https://zampto.xunda.ggff.net/sub
```

## VMess Node Format

### Field Breakdown

| Field | Value | Purpose |
|-------|-------|---------|
| v | "2" | VMess protocol version |
| ps | "zampto-argo" | Node display name |
| add | CF_DOMAIN | Server address |
| port | "443" | HTTPS port |
| id | UUID | User UUID from config |
| aid | "0" | Alter ID (no extra accounts) |
| net | "ws" | WebSocket transport |
| type | "none" | Header type |
| host | CF_DOMAIN | WebSocket host header |
| path | "/ws" | WebSocket path |
| tls | "tls" | TLS encryption enabled |

### Security Features

- **TLS Encryption**: All connections use HTTPS/TLS
- **WebSocket Transport**: Obfuscates traffic, bypasses simple DPI
- **Argo Tunnel**: Cloudflare infrastructure provides DDoS protection
- **UUID Authentication**: Each connection requires valid UUID

## Output Example

```bash
$ bash start.sh

[2025-01-17 10:30:45] [INFO] === Zampto Startup Script ===
[2025-01-17 10:30:45] [INFO] Loading configuration from: /home/container/config.json
[2025-01-17 10:30:45] [INFO] Configuration loaded successfully:
[2025-01-17 10:30:45] [INFO]   CF_DOMAIN: zampto.xunda.ggff.net
[2025-01-17 10:30:45] [INFO]   UUID: 19763831-f9cb-45f2-b59a-9d60264c7f1c
...
[2025-01-17 10:30:50] [✅ SUCCESS] ✅ Argo tunnel setup completed successfully

[2025-01-17 10:30:50] [INFO] Generating vmess-ws-argo subscription...
[2025-01-17 10:30:50] [✅ SUCCESS] VMESS Node: vmess://ewogICJ2IjogIjIiLAogICJwcyI6ICJ6YW1wdG8tYXJnbyIsCiAgImFkZCI6ICJ6YW1wdG8ueHVuZGEuZ2dmZi5uZXQiLAogICJwb3J0IjogIjQ0MyIsCiAgImlkIjogIjE5NzYzODMxLWY5Y2ItNDVmMi1iNTlhLTlkNjAyNjRjN2YxYyIsCiAgImFpZCI6ICIwIiwKICAibmV0IjogIndzIiwKICAidHlwZSI6ICJub25lIiwKICAiaG9zdCI6ICJ6YW1wdG8ueHVuZGEuZ2dmZi5uZXQiLAogICJwYXRoIjogIi93cyIsCiAgInRscyI6ICJ0bHMiCn0=
[2025-01-17 10:30:50] [✅ SUCCESS] Subscription generated
[2025-01-17 10:30:50] [✅ SUCCESS] Subscription URL: https://zampto.xunda.ggff.net/sub
[2025-01-17 10:30:50] [INFO] Subscription file: /home/container/.npm/sub.txt

[2025-01-17 10:30:50] [INFO] === Startup Script Completed ===
```

## Usage

### 1. For Client Subscription

Users can subscribe to the node using any VMess-compatible client:

1. Copy the subscription URL: `https://zampto.xunda.ggff.net/sub`
2. Paste into their VPN client
3. Client automatically decodes and imports the node

### 2. For Direct Node Configuration

Users can also copy the complete VMess node URL directly:
```
vmess://ewogICJ2IjogIjIiLAogICJwcyI6ICJ6YW1wdG8tYXJnbyIsCiAgImFkZCI6ICJ6YW1wdG8ueHVuZGEuZ2dmZi5uZXQiLAogICJwb3J0IjogIjQ0MyIsCiAgImlkIjogIjE5NzYzODMxLWY5Y2ItNDVmMi1iNTlhLTlkNjAyNjRjN2YxYyIsCiAgImFpZCI6ICIwIiwKICAibmV0IjogIndzIiwKICAidHlwZSI6ICJub25lIiwKICAiaG9zdCI6ICJ6YW1wdG8ueHVuZGEuZ2dmZi5uZXQiLAogICJwYXRoIjogIi93cyIsCiAgInRscyI6ICJ0bHMiCn0=
```

### 3. For Debugging

To verify the node structure, decode the base64 part:

```bash
# Extract and decode
echo "ewogICJ2I..." | base64 -d | jq .

# Output:
{
  "v": "2",
  "ps": "zampto-argo",
  "add": "zampto.xunda.ggff.net",
  "port": "443",
  "id": "19763831-f9cb-45f2-b59a-9d60264c7f1c",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "zampto.xunda.ggff.net",
  "path": "/ws",
  "tls": "tls"
}
```

## Files Modified

- `start.sh`: Added subscription generation functions and integration

## Testing

Run the test script to verify functionality:

```bash
chmod +x test-subscription-generation.sh
./test-subscription-generation.sh
```

The test script validates:
- VMess node generation
- Subscription file creation
- Correct node format and structure
- Base64 encoding
- All required fields

## Troubleshooting

### Missing Subscription File

**Symptom**: `/home/container/.npm/sub.txt` not found

**Solutions**:
1. Verify CF_DOMAIN is set in config.json
2. Verify UUID is set in config.json
3. Check logs for errors in start.sh

### Invalid VMess Node

**Symptom**: Client cannot import the node

**Solutions**:
1. Verify domain is valid and accessible
2. Verify UUID format is correct (uuid v4)
3. Check that Argo tunnel is running
4. Test by decoding base64 and verifying JSON structure

### Subscription URL Not Accessible

**Symptom**: Cannot access `https://zampto.xunda.ggff.net/sub`

**Solutions**:
1. Verify Argo tunnel is running
2. Verify index.js is serving `/sub` endpoint
3. Check firewall/proxy settings
4. Verify subscription file was created at `/home/container/.npm/sub.txt`

## Version Information

- **Feature Version**: 1.0
- **Added in**: start.sh enhancement
- **Dependencies**: base64, standard POSIX shell features
- **Tested on**: Linux systems with bash and standard utilities

## Related Files

- `start.sh`: Main startup script
- `argo-diagnostic.sh`: Argo tunnel setup
- `index.js` (future): HTTP server with /sub endpoint
- `config.json`: Configuration file
- `test-subscription-generation.sh`: Test script
