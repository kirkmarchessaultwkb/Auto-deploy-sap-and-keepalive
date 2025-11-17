# start.sh Config Loading Fix - Implementation Summary

## Overview

Fixed start.sh to correctly read config.json and export environment variables for subsequent scripts. The fix ensures proper validation, error handling, and environment variable export as specified in the ticket requirements.

## Key Changes Made

### 1. Enhanced Config File Validation
- **Before**: Used `return 1` for missing config file
- **After**: Uses `exit 1` with clear error message
```bash
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] config.json not found at /home/container/config.json"
    exit 1
fi
```

### 2. Improved JSON Parsing (Handles Spaces)
- **Before**: Used `grep -o '"key":"value"' | cut -d'"' -f4`
- **After**: Uses `grep -o '"key"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/'`
```bash
CF_DOMAIN=$(grep -o '"cf_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
```

### 3. Added Critical Field Validation
- **New Feature**: Validates required fields before proceeding
```bash
if [[ -z "$CF_DOMAIN" || -z "$UUID" || -z "$PORT" ]]; then
    echo "[ERROR] Missing required config fields"
    exit 1
fi
```

### 4. Environment Variable Export (Unchanged - Already Working)
- **Maintained**: Export all variables for child scripts
```bash
export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY
```

### 5. Updated Log Messages to Match Ticket Format
- **Config file error**: `[ERROR] config.json not found at /home/container/config.json`
- **Missing fields**: `[ERROR] Missing required config fields`
- **Nezha success**: `[INFO] Nezha agent started`
- **Deploy script call**: `[INFO] Calling wispbyte-argo-singbox-deploy.sh...`

## Configuration Parameters Loaded

All 7 parameters are loaded from `/home/container/config.json`:

| Parameter | Purpose | Required | Default |
|-----------|---------|----------|---------|
| `CF_DOMAIN` | Cloudflare domain for Argo tunnel | ✅ Yes | - |
| `CF_TOKEN` | Cloudflare tunnel token | ❌ No | - |
| `UUID` | VMess UUID for proxy | ✅ Yes | - |
| `PORT` | Sing-box listening port | ✅ Yes | 27039 |
| `NEZHA_SERVER` | Nezha monitoring server | ❌ No | - |
| `NEZHA_PORT` | Nezha agent port | ❌ No | 5555 |
| `NEZHA_KEY` | Nezha agent key | ❌ No | - |

## Expected Log Output

```
[2025-01-20 10:30:00] [INFO] === Zampto Startup Script ===
[2025-01-20 10:30:00] [INFO] Loading config.json...
[2025-01-20 10:30:00] [INFO] Config loaded:
[2025-01-20 10:30:00] [INFO]   - Domain: zampto.xunda.ggff.net
[2025-01-20 10:30:00] [INFO]   - UUID: 19763831-1234-5678-9abc-123456789012
[2025-01-20 10:30:00] [INFO]   - Port: 27039
[2025-01-20 10:30:00] [INFO]   - Nezha: nezha.example.com
[2025-01-20 10:30:00] [INFO] Starting Nezha agent...
[INFO] Nezha agent started
[INFO] Calling wispbyte-argo-singbox-deploy.sh...
[2025-01-20 10:30:05] [INFO] === Startup Completed ===
```

## Error Scenarios

### 1. Config File Missing
```
[ERROR] config.json not found at /home/container/config.json
```
**Action**: Script exits immediately with code 1

### 2. Missing Critical Fields
```
[ERROR] Missing required config fields
```
**Action**: Script exits immediately with code 1

### 3. Deploy Script Missing
```
[INFO] Calling wispbyte-argo-singbox-deploy.sh...
[2025-01-20 10:30:00] [ERROR] wispbyte-argo-singbox-deploy.sh not found
```
**Action**: Script exits with code 1

## Testing Results

Created comprehensive test suite (`test-start-sh-config-fix.sh`) with 6 test categories:

1. ✅ Config file existence check
2. ✅ Config loading with grep+sed (handles spaces)
3. ✅ Critical field validation
4. ✅ Environment variable export
5. ✅ Verify exported values
6. ✅ Missing field validation

**All tests passed successfully**

## File Statistics

- **start.sh**: 137 lines (increased from 132 due to validation)
- **Syntax check**: ✅ Passes (`bash -n start.sh`)
- **Functionality**: ✅ All requirements implemented

## Integration Notes

### Environment Variable Export
The script exports all 7 variables, making them available to:
- `wispbyte-argo-singbox-deploy.sh` (main deploy script)
- Any child processes spawned by the script

### Backward Compatibility
- ✅ Maintains all existing functionality
- ✅ Same configuration file format
- ✅ Same environment variable names
- ✅ Enhanced error handling without breaking changes

### Nezha Integration
- ✅ Starts only if `NEZHA_KEY` and `NEZHA_SERVER` are configured
- ✅ Supports amd64, arm64, armv7 architectures
- ✅ Downloads binary if not present
- ✅ Runs in background with nohup

## Technical Implementation Details

### JSON Parsing with Spaces
The improved regex pattern handles JSON with optional spaces:
```bash
# Pattern breakdown
"cf_domain"          # Key name
[[:space:]]*        # Zero or more spaces
:                   # Colon
[[:space:]]*        # Zero or more spaces
"[^"]*"             # Quoted value
```

### Sed Extraction
The sed command extracts just the value:
```bash
sed 's/.*"\([^"]*\)".*/\1/'  # Capture content between quotes
```

### Critical Field Validation
Uses bash parameter expansion to check for empty variables:
```bash
if [[ -z "$VAR1" || -z "$VAR2" || -z "$VAR3" ]]; then
    echo "[ERROR] Missing required config fields"
    exit 1
fi
```

## Usage Examples

### Complete Config Example
```json
{
    "cf_domain": "zampto.xunda.ggff.net",
    "cf_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "uuid": "19763831-1234-5678-9abc-123456789012",
    "port": "27039",
    "nezha_server": "nezha.example.com",
    "nezha_port": "5555",
    "nezha_key": "abc123def456"
}
```

### Minimal Config Example
```json
{
    "cf_domain": "zampto.xunda.ggff.net",
    "uuid": "19763831-1234-5678-9abc-123456789012",
    "port": "27039"
}
```

## Deployment Instructions

1. **Deploy the fixed start.sh**:
   ```bash
   cp start.sh /home/container/start.sh
   chmod +x /home/container/start.sh
   ```

2. **Create config.json** at `/home/container/config.json` with required fields

3. **Run the script**:
   ```bash
   bash /home/container/start.sh
   ```

4. **Verify deployment**:
   - Check environment variables are exported
   - Verify Nezha agent starts (if configured)
   - Confirm wispbyte deploy script runs

## Troubleshooting

### Issue: Config not loading
**Check**: JSON format and file permissions
```bash
# Verify JSON is valid
cat /home/container/config.json | python3 -m json.tool

# Check file permissions
ls -la /home/container/config.json
```

### Issue: Environment variables not exported
**Check**: Script execution context
```bash
# Run in same shell to test export
source /home/container/start.sh
echo "CF_DOMAIN: $CF_DOMAIN"
```

### Issue: Nezha not starting
**Check**: Architecture and download
```bash
# Verify architecture
uname -m

# Check binary
file /tmp/nezha/nezha-agent
```

## Summary

The fix successfully implements all ticket requirements:

1. ✅ **Config file validation**: Clear error messages and immediate exit
2. ✅ **Correct config reading**: Improved regex handles JSON with spaces
3. ✅ **Critical field validation**: Ensures CF_DOMAIN, UUID, PORT are present
4. ✅ **Environment variable export**: All variables exported for child scripts
5. ✅ **Enhanced error handling**: Proper exit codes and messages
6. ✅ **Clear logging**: Matches ticket format requirements
7. ✅ **Backward compatibility**: No breaking changes to existing functionality

The script now robustly handles configuration loading and provides clear feedback for any issues encountered during startup.