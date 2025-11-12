# Nezha Agent Integration

This document describes the Nezha monitoring agent integration for the SAP Cloud Foundry deployment system.

## Overview

The Nezha agent integration provides automatic monitoring and management capabilities for deployed proxy nodes. It supports both v0 and v1 protocols with automatic detection, architecture-aware binary downloads, and built-in watchdog functionality.

## Features

- **Automatic Protocol Detection**: Intelligently detects v0 vs v1 protocol based on configuration
- **Architecture Support**: Supports AMD64, ARM64, and ARMv7 architectures
- **Smart Caching**: Reuses downloaded binaries to save bandwidth and disk space
- **Watchdog Protection**: 30-second automatic restart on crashes
- **Resource Management**: Uses nice/ionice for minimal resource impact
- **Detailed Logging**: Comprehensive logging to `/app/logs/nezha.log`
- **Status Reporting**: JSON status file for external monitoring systems

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `NEZHA_SERVER` | Yes | Nezha server address (format determines protocol) |
| `NEZHA_PORT` | No | Port for v0 protocol only |
| `NEZHA_KEY` | Yes | Agent key (v0) or NZ_CLIENT_SECRET (v1) |

### Protocol Detection Logic

The system automatically determines the protocol version based on your configuration:

1. **v0 Protocol**: Used when `NEZHA_PORT` is explicitly set
   ```
   NEZHA_SERVER=nezha.example.com
   NEZHA_PORT=5555
   NEZHA_KEY=your_v0_agent_key
   ```

2. **v1 Protocol**: Used when `NEZHA_SERVER` contains a port
   ```
   NEZHA_SERVER=nezha.example.com:8008
   NEZHA_KEY=your_nz_client_secret
   ```

3. **v0 Protocol (Default)**: Used when server has no port and no `NEZHA_PORT` is set
   ```
   NEZHA_SERVER=nezha.example.com
   NEZHA_KEY=your_v0_agent_key
   # Uses default port 5555
   ```

## Command Line Generation

### v0 Protocol Commands
```
# Standard
nezha-agent -s nezha.example.com:5555 -p your_key

# With TLS (for ports 443/8443)
nezha-agent -s nezha.example.com:443 -p your_key --tls
```

### v1 Protocol Commands
```
# Standard
nezha-agent service --report -s nezha.example.com:8008 -p your_key

# With TLS (for ports 443/8443)
nezha-agent service --report -s nezha.example.com:443 -p your_key --tls
```

## File Structure

```
/app/
├── bin/
│   └── nezha                 # Downloaded Nezha agent binary
├── logs/
│   ├── nezha.log            # Main log file
│   ├── nezha.pid           # Process ID file
│   └── nezha_status.json   # Status information
└── nezha-agent.sh          # Management script
```

## Status Monitoring

The agent creates a JSON status file at `/app/logs/nezha_status.json` with real-time information:

```json
{
  "status": "running",
  "protocol_version": "v1",
  "server": "nezha.example.com:8008",
  "port": "",
  "architecture": "amd64",
  "pid": 12345,
  "start_time": "2025-11-12T21:00:00+00:00",
  "last_restart": "2025-11-12T21:00:00+00:00"
}
```

### Status Values

- `starting`: Agent is starting up
- `running`: Agent is operational
- `restarting`: Agent exited normally and is restarting
- `crashed`: Agent crashed and is restarting
- `stopped`: Agent has been shut down

## Log Management

All agent activities are logged to `/app/logs/nezha.log` with timestamps and severity levels:

```
[2025-11-12 21:00:00] Initializing Nezha agent setup...
[2025-11-12 21:00:01] Detected architecture: amd64
[2025-11-12 21:00:02] Latest Nezha version: 0.20.8
[2025-11-12 21:00:05] Starting Nezha agent with command: /app/bin/nezha service --report -s nezha.example.com:8008 -p your_key
[2025-11-12 21:00:06] Nezha agent started with PID: 12345
```

## Watchdog Functionality

The agent includes a built-in watchdog that:

1. Monitors the Nezha process every 30 seconds
2. Automatically restarts on crashes
3. Implements backoff to prevent log spam
4. Handles graceful shutdown on system signals

## Integration Points

### GitHub Actions Workflow

The deployment workflow automatically:
1. Detects Nezha configuration presence
2. Downloads and executes the management script
3. Verifies successful startup
4. Reports status in deployment logs

### Environment Variable Export

The script exports status variables for external consumption:
```bash
export NEZHA_STATUS="running"
export NEZHA_PROTOCOL_VERSION="v1"
export NEZHA_PID="12345"
```

## Troubleshooting

### Common Issues

1. **Agent doesn't start**: Check that both `NEZHA_SERVER` and `NEZHA_KEY` are set
2. **Connection failures**: Verify server address and port configuration
3. **Permission errors**: Ensure `/app/bin` and `/app/logs` directories are writable
4. **Architecture mismatch**: System will auto-detect, but verify with `uname -m`

### Debug Commands

```bash
# Check agent status
cat /app/logs/nezha_status.json

# View recent logs
tail -20 /app/logs/nezha.log

# Check if process is running
kill -0 $(cat /app/logs/nezha.pid) 2>/dev/null && echo "Running" || echo "Not running"
```

## Testing

Use the provided test script to verify functionality:

```bash
./test-nezha.sh
```

This tests:
- Architecture detection
- Protocol version detection
- Command building logic
- Configuration validation

## Security Considerations

1. **Key Protection**: Nezha keys are stored as environment variables and in deployment secrets
2. **Network Security**: TLS is automatically enabled for standard TLS ports (443, 8443)
3. **Resource Limits**: Agent runs with minimal resource usage and proper process isolation
4. **Access Control**: Agent only communicates with the specified Nezha server

## Performance Impact

- **Memory Usage**: ~10-20MB RAM when running
- **CPU Usage**: <1% CPU during normal operation
- **Network**: Minimal periodic reporting to Nezha server
- **Disk**: ~5-10MB for binary and logs

## Version Compatibility

- Supports Nezha v0.x and v1.x protocols
- Auto-detects latest stable agent version
- Backward compatible with existing configurations
- Graceful handling of version mismatches