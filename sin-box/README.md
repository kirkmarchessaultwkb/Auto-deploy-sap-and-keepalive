# sin-box: Lightweight Xray + Cloudflared Runner

A minimal, resource-efficient Node.js-based runner for managing Xray (VMess proxy) and Cloudflared tunnel instances with automatic process monitoring and subscription generation.

## Features

- **Xray VMess Proxy**: Lightweight HTTP/VMess server without external dependencies
- **Cloudflared Tunneling**: Optional Argo tunnel support (both fixed and ephemeral)
- **Subscription Server**: HTTP endpoints for health checks and VMess subscription generation
- **Process Watchdog**: Automatic restart of failed processes with 30-second monitoring intervals
- **Resource Optimization**: Uses `ionice` and `nice` for CPU/IO priority management
- **Binary Caching**: Downloaded binaries are cached locally for faster restarts
- **Graceful Shutdown**: Proper SIGTERM/SIGINT handling with process cleanup

## Quick Start

### Prerequisites

- Node.js 14+ (for running the HTTP server)
- Bash shell with `curl`, `unzip`, and standard Unix utilities
- ~2GB RAM available (as per zampto specifications)

### Installation

```bash
cd sin-box
npm install
npm start
```

## Environment Variables

### Required
- `UUID`: VMess UUID (auto-generated if not provided)

### Optional Tunnel Configuration
- `DISABLE_ARGO=1`: Skip all Argo/Cloudflared setup
- `ARGO_DOMAIN`: Fixed Argo tunnel domain (enables fixed tunnel mode)
- `ARGO_AUTH`: Fixed Argo tunnel authentication (token or JSON)
- `CFIP`: Direct IP address for fallback mode
- `CFPORT`: Port for direct IP (default: 443)
- `SERVER_PORT`: Node.js HTTP server port (default: 3000)

## File Structure

```
sin-box/
├── package.json          # Node.js package configuration
├── index.js             # HTTP server with subscription endpoint
├── start.sh             # Main orchestration script
├── bin/                 # Cached binary storage (created at runtime)
├── logs/                # Process logs (created at runtime)
├── .npm/                # Subscription files (created at runtime)
└── etc/                 # Configuration files (created at runtime)
```

## HTTP Endpoints

- `GET /health` or `/ping` - Returns "OK" (200 status)
- `GET /sub` or `/subscription` - Returns VMess subscription link from `.npm/sub.txt`

## Startup Sequence

1. Validates/generates environment variables (UUID generation)
2. Creates required directories (`bin`, `logs`, `.npm`, `etc`)
3. Downloads Xray binary (if not cached)
4. Generates Xray VMess/WebSocket configuration
5. Starts Xray service on port 10000
6. Downloads Cloudflared (if tunneling enabled)
7. Starts Cloudflared tunnel (if not using fixed tunnel)
8. Starts Node.js HTTP server
9. Generates VMess subscription (Base64-encoded)
10. Launches watchdog loop for process monitoring

## Modes

### 1. Direct Mode (DISABLE_ARGO=1)
- No tunneling
- Direct connection via CFIP:CFPORT or localhost:10000
- Subscription served locally at localhost:3000/sub

### 2. Fixed Argo Tunnel
- Uses pre-configured ARGO_DOMAIN and ARGO_AUTH
- Subscription uses fixed domain
- No Cloudflared startup needed

### 3. Ephemeral Argo Tunnel
- Automatically creates new tunnel each session
- Cloudflared generates temporary domain
- Subscription updated with tunnel URL

## Process Management

### Watchdog Loop
- Runs every 30 seconds
- Checks: Xray, Cloudflared (if enabled), Node server
- Automatically restarts failed processes
- Logs all events with timestamps

### Graceful Shutdown
- Catches SIGTERM and SIGINT
- Cleanly terminates all child processes
- Flushes logs and cleans up resources

## Logging

All process output is logged to `logs/`:
- `xray.log` - Xray proxy server logs
- `cloudflared.log` - Argo tunnel logs
- `node.log` - HTTP server logs
- Main script logs to stdout with timestamps

## Performance Considerations

- **Binary Optimization**: Binaries are stripped to reduce size
- **Priority Management**: Xray runs at nice +15, Cloudflared at +10, Node at +10
- **I/O Scheduling**: Uses `ionice -c 3` for Xray (best-effort I/O)
- **Dependency Footprint**: Zero npm dependencies, only Node.js built-ins
- **Memory**: Minimal overhead - designed for <100MB process footprint

## Debug Version

A debug version (`start.sh.debug`) is available with detailed step-by-step logging to help diagnose issues when the script runs in environments with limited visibility (like zampto).

### Using the Debug Script

Instead of running the regular `start.sh`, use:

```bash
bash start.sh.debug 2>&1 | tee debug_output.log
```

This will:
- Display detailed progress of each step with [STEP N] markers
- Show success (✓) and failure (✗) indicators
- Include key information (UUID, versions, PIDs)
- Verify processes actually started
- Display error logs immediately on failure
- Exit with clear error messages on any failure

### Debug Output Format

```
[STEP 1] Setting up directories...
  ✓ Directories created successfully

[STEP 2] Validating environment...
  ✓ UUID generated: abc123...

[STEP 3] Downloading Xray binary...
  Latest Xray version: v1.8.8
  ✓ Xray installed successfully

[STEP 5] Starting Xray...
  ✓ Xray is running (PID: 12345)
```

### When to Use Debug Version

Use `start.sh.debug` when:
- Script fails silently with no output
- Need to identify which step is failing
- Troubleshooting download or configuration issues
- Verifying environment setup in new deployments
- Diagnosing process startup failures

## Troubleshooting

### Xray fails to start
- Check if unzip is installed: `command -v unzip`
- Verify architecture detection: `uname -m`
- Review logs: `cat sin-box/logs/xray.log`
- **Use debug script**: `bash start.sh.debug 2>&1 | tee debug.log`

### Cloudflared tunnel not extracted
- Check logs: `cat sin-box/logs/cloudflared.log`
- Increase sleep time in start.sh (line 299: `sleep 5`)
- Verify network connectivity to GitHub/Cloudflare
- **Use debug script** to see tunnel URL extraction

### Subscription file not generated
- Ensure `.npm` directory exists: `ls -la sin-box/.npm`
- Check file permissions on `sub.txt`
- Verify HTTP server is running: `curl localhost:3000/sub`
- **Use debug script** to see subscription generation output

### Processes not restarting
- Check watchdog is running: `ps aux | grep 'bash.*start.sh'`
- Review process PIDs match those being monitored
- **Use debug script** to see watchdog check results

### No output in console
- This is common in some hosting environments (zampto, etc.)
- **Always use the debug script** in these cases
- Save output to file: `bash start.sh.debug 2>&1 | tee debug.log`
- Then review `debug.log` to see what happened

## Security Notes

1. **UUID**: Treat like a password - keep it private
2. **Subscription Link**: Contains UUID, don't share publicly
3. **Cloudflared Auth**: Store ARGO_AUTH securely (consider environment files)
4. **Port 10000**: Only accessible locally unless exposed via tunnel

## Development

### Adding Custom Routes

Edit `index.js` to add new HTTP endpoints:
```javascript
if (req.url === '/custom') {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Custom response');
  return;
}
```

### Customizing Xray Config

Edit the `generate_xray_config()` function in `start.sh` to modify:
- Inbound protocol settings
- WebSocket path and options
- TLS configuration
- Routing rules

## License

MIT
