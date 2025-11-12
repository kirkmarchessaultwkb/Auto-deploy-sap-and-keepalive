const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// Configuration
const PORT = process.env.PORT || 8080;
const SUB_PATH = process.env.SUB_PATH || 'sub';
const WORKDIR = path.join(process.env.HOME || '/home/vcap', '.npm');
const SUB_FILE = path.join(WORKDIR, 'sub.txt');
const START_SCRIPT = path.join(__dirname, 'start.sh');

// Ensure work directory exists
if (!fs.existsSync(WORKDIR)) {
    fs.mkdirSync(WORKDIR, { recursive: true });
}

// Start the bash script
let startScriptProcess = null;

function startBackgroundServices() {
    console.log('[INFO] Starting background services...');
    
    if (startScriptProcess) {
        console.log('[WARNING] Background services already running');
        return;
    }
    
    if (!fs.existsSync(START_SCRIPT)) {
        console.error('[ERROR] start.sh not found at:', START_SCRIPT);
        return;
    }
    
    // Make sure the script is executable
    try {
        fs.chmodSync(START_SCRIPT, '755');
    } catch (err) {
        console.error('[ERROR] Failed to chmod start.sh:', err.message);
    }
    
    // Spawn the start.sh script
    startScriptProcess = spawn('/bin/bash', [START_SCRIPT], {
        detached: false,
        stdio: ['ignore', 'pipe', 'pipe']
    });
    
    startScriptProcess.stdout.on('data', (data) => {
        console.log(`[start.sh] ${data.toString().trim()}`);
    });
    
    startScriptProcess.stderr.on('data', (data) => {
        console.error(`[start.sh ERROR] ${data.toString().trim()}`);
    });
    
    startScriptProcess.on('error', (err) => {
        console.error('[ERROR] Failed to start background services:', err.message);
        startScriptProcess = null;
    });
    
    startScriptProcess.on('exit', (code, signal) => {
        console.log(`[INFO] Background services exited with code ${code}, signal ${signal}`);
        startScriptProcess = null;
        
        // Auto-restart after 5 seconds
        setTimeout(() => {
            console.log('[INFO] Restarting background services...');
            startBackgroundServices();
        }, 5000);
    });
    
    console.log('[INFO] Background services started with PID:', startScriptProcess.pid);
}

// HTTP Server
const server = http.createServer((req, res) => {
    const url = req.url;
    
    // Health check endpoint
    if (url === '/' || url === '/health') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('Hello World\n');
        return;
    }
    
    // Subscription endpoint
    if (url === `/${SUB_PATH}` || url === `/${SUB_PATH}/`) {
        if (fs.existsSync(SUB_FILE)) {
            try {
                const subscription = fs.readFileSync(SUB_FILE, 'utf8');
                res.writeHead(200, { 
                    'Content-Type': 'text/plain; charset=utf-8',
                    'Profile-Update-Interval': '6',
                    'Subscription-Userinfo': 'upload=0; download=0; total=10737418240; expire=2099999999'
                });
                res.end(subscription);
                console.log(`[INFO] Subscription served to ${req.connection.remoteAddress}`);
            } catch (err) {
                console.error('[ERROR] Failed to read subscription file:', err.message);
                res.writeHead(500, { 'Content-Type': 'text/plain' });
                res.end('Internal Server Error\n');
            }
        } else {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('Subscription not ready yet. Please wait a few seconds and try again.\n');
            console.log('[WARNING] Subscription file not found');
        }
        return;
    }
    
    // Status endpoint
    if (url === '/status') {
        const status = {
            status: 'running',
            uptime: process.uptime(),
            memory: process.memoryUsage(),
            env: {
                NODE_VERSION: process.version,
                PLATFORM: process.platform,
                ARCH: process.arch
            },
            services: {
                script_running: startScriptProcess !== null && !startScriptProcess.killed
            }
        };
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(status, null, 2));
        return;
    }
    
    // Logs endpoint (optional, for debugging)
    if (url === '/logs') {
        const logsDir = path.join(WORKDIR, 'logs');
        if (fs.existsSync(logsDir)) {
            try {
                const files = fs.readdirSync(logsDir);
                let logs = '<html><head><title>Logs</title></head><body><h1>Service Logs</h1>';
                
                files.forEach(file => {
                    const filePath = path.join(logsDir, file);
                    const content = fs.readFileSync(filePath, 'utf8');
                    logs += `<h2>${file}</h2><pre>${content}</pre>`;
                });
                
                logs += '</body></html>';
                res.writeHead(200, { 'Content-Type': 'text/html' });
                res.end(logs);
            } catch (err) {
                res.writeHead(500, { 'Content-Type': 'text/plain' });
                res.end('Error reading logs\n');
            }
        } else {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('Logs not available\n');
        }
        return;
    }
    
    // 404 for all other routes
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found\n');
});

// Start HTTP server
server.listen(PORT, '0.0.0.0', () => {
    console.log(`[INFO] HTTP server listening on port ${PORT}`);
    console.log(`[INFO] Subscription endpoint: /${SUB_PATH}`);
    console.log(`[INFO] Health check: /`);
    console.log(`[INFO] Status: /status`);
    
    // Start background services after HTTP server is up
    setTimeout(() => {
        startBackgroundServices();
    }, 1000);
});

// Handle process signals
process.on('SIGTERM', () => {
    console.log('[INFO] Received SIGTERM, shutting down gracefully...');
    if (startScriptProcess && !startScriptProcess.killed) {
        startScriptProcess.kill('SIGTERM');
    }
    server.close(() => {
        console.log('[INFO] HTTP server closed');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('[INFO] Received SIGINT, shutting down gracefully...');
    if (startScriptProcess && !startScriptProcess.killed) {
        startScriptProcess.kill('SIGTERM');
    }
    server.close(() => {
        console.log('[INFO] HTTP server closed');
        process.exit(0);
    });
});

process.on('uncaughtException', (err) => {
    console.error('[ERROR] Uncaught exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('[ERROR] Unhandled rejection at:', promise, 'reason:', reason);
});

console.log('[INFO] Application started');
console.log('[INFO] Node.js version:', process.version);
console.log('[INFO] Working directory:', WORKDIR);
