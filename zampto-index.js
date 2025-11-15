#!/usr/bin/env node

/**
 * ============================================================================
 * sing-box HTTP Service and Monitoring for zampto Platform
 * Purpose: Serve subscriptions and monitor sing-box process (managed by zampto-start.sh)
 * Platform: zampto Node10 (ARM)
 * Architecture: HTTP Service & Monitoring Tool (Process Management Delegated)
 * ============================================================================
 */

'use strict';

const http = require('http');
const https = require('https');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');
const url = require('url');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
    port: parseInt(process.env.SERVER_PORT || '8001', 10),
    filePath: process.env.FILE_PATH || './.npm',
    uploadUrl: process.env.UPLOAD_URL || '',
    subPath: process.env.SUB_PATH || 'sub',
    uuid: process.env.UUID || 'de305d54-75b4-431b-adb2-eb6b9e546014',
    nodeName: process.env.NAME || 'zampto-node',
    argoHost: process.env.ARGO_DOMAIN || '',
    cfIp: process.env.CFIP || '',
    cfPort: process.env.CFPORT || '443',
    nezhaServer: process.env.NEZHA_SERVER || '',
    nezhaPort: process.env.NEZHA_PORT || '',
    nezhaKey: process.env.NEZHA_KEY || '',
    chatId: process.env.CHAT_ID || '',
    botToken: process.env.BOT_TOKEN || '',
    healthCheckInterval: 30000, // 30 seconds (optimized from 5s)
};

// ============================================================================
// Logging Utilities
// ============================================================================

const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
};

function log(level, message) {
    const timestamp = new Date().toISOString();
    const levelColors = {
        'INFO': colors.green,
        'WARN': colors.yellow,
        'ERROR': colors.red,
        'DEBUG': colors.blue,
    };
    const color = levelColors[level] || colors.reset;
    console.log(`${color}[${timestamp}] [${level}]${colors.reset} ${message}`);
}

function logInfo(message) {
    log('INFO', message);
}

function logError(message) {
    log('ERROR', message);
}

function logWarn(message) {
    log('WARN', message);
}

// ============================================================================
// Telegram Notification
// ============================================================================

async function sendTelegramNotification(message, type = 'info') {
    if (!CONFIG.botToken || !CONFIG.chatId) {
        return;
    }

    const icons = {
        'info': 'ℹ️',
        'success': '✅',
        'error': '❌',
        'warning': '⚠️',
    };

    const icon = icons[type] || '📢';
    const fullMessage = `${icon} ${message}`;

    try {
        const data = JSON.stringify({
            chat_id: CONFIG.chatId,
            text: fullMessage,
            parse_mode: 'HTML',
        });

        const options = {
            hostname: 'api.telegram.org',
            port: 443,
            path: `/bot${CONFIG.botToken}/sendMessage`,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': data.length,
            },
        };

        await new Promise((resolve, reject) => {
            const req = https.request(options, (res) => {
                let responseData = '';
                res.on('data', (chunk) => {
                    responseData += chunk;
                });
                res.on('end', () => {
                    resolve();
                });
            });

            req.on('error', reject);
            req.write(data);
            req.end();
        });
    } catch (error) {
        logWarn(`Failed to send Telegram notification: ${error.message}`);
    }
}

// ============================================================================
// File System Utilities
// ============================================================================

function ensureDirectoryExists(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
}

function readSubscriptionFile() {
    try {
        if (fs.existsSync(CONFIG.filePath)) {
            return fs.readFileSync(CONFIG.filePath, 'utf8').trim();
        }
    } catch (error) {
        logError(`Failed to read subscription file: ${error.message}`);
    }
    return '';
}

// ============================================================================
// Subscription URL Generation
// ============================================================================

function generateSubscriptionUrl() {
    // Build subscription link based on configuration
    const protocol = CONFIG.argoHost ? 'https' : 'http';
    const host = CONFIG.argoHost || `127.0.0.1:${CONFIG.port}`;
    const port = CONFIG.cfPort || '443';
    
    // Format: vmess://base64
    const vmessConfig = {
        v: '2',
        ps: CONFIG.nodeName,
        add: CONFIG.argoHost ? CONFIG.argoHost.split(':')[0] : 'localhost',
        port: CONFIG.argoHost ? port : '8080',
        id: CONFIG.uuid,
        aid: '0',
        net: 'ws',
        type: 'none',
        host: CONFIG.argoHost || '',
        path: '/ws',
        tls: CONFIG.argoHost ? 'tls' : '',
    };

    const vmessString = 'vmess://' + Buffer.from(JSON.stringify(vmessConfig)).toString('base64');
    return vmessString;
}

function generateVlessUrl() {
    // Optional: Generate VLESS config
    const tls = CONFIG.argoHost ? 'tls' : '';
    const host = CONFIG.argoHost ? CONFIG.argoHost.split(':')[0] : 'localhost';
    const port = CONFIG.argoHost ? CONFIG.cfPort : '8080';
    
    return `vless://${CONFIG.uuid}@${host}:${port}?type=ws&path=/ws&${tls ? 'security=' + tls + '&' : ''}host=${host}#${CONFIG.nodeName}`;
}

// ============================================================================
// sing-box Process Management
// ============================================================================

let singBoxProcess = null;

function startSingBox() {
    // sing-box process management delegated to zampto-start.sh
    // This function only does process discovery and monitoring
    logInfo('sing-box process management delegated to zampto-start.sh');
    return Promise.resolve();
}

function stopSingBox() {
    // sing-box process management delegated to zampto-start.sh
    // This function only does logging
    logInfo('sing-box process stop delegated to zampto-start.sh');
    return Promise.resolve();
}

function checkSingBoxHealth() {
    return new Promise((resolve) => {
        // Check system process list for sing-box
        exec('pgrep -f "sing-box run"', (error, stdout) => {
            if (error || !stdout.trim()) {
                logWarn('sing-box process not found in system');
                resolve(false);
            } else {
                const pid = stdout.trim().split('\n')[0];
                logInfo(`sing-box process found with PID: ${pid}`);
                resolve(true);
            }
        });
    });
}

// ============================================================================
// Health Check Service
// ============================================================================

function startHealthCheck() {
    logInfo(`Starting health check service (${CONFIG.healthCheckInterval}ms interval)`);

    setInterval(() => {
        checkSingBoxHealth().then((isHealthy) => {
            if (!isHealthy) {
                logWarn('sing-box health check failed - zampto-start.sh should handle restart');
                // Only log warning, don't restart (let zampto-start.sh handle it)
            }
        }).catch((error) => {
            logError(`Health check error: ${error.message}`);
        });
    }, CONFIG.healthCheckInterval);
}

// ============================================================================
// HTTP Server Routes
// ============================================================================

function handleSubscriptionRequest(req, res) {
    // Get subscription content
    const subscriptionContent = readSubscriptionFile();
    
    if (!subscriptionContent) {
        // Generate inline subscription if file not found
        const subscriptionUrl = generateSubscriptionUrl();
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end(subscriptionUrl);
        return;
    }

    // Encode subscription content in base64
    const encoded = Buffer.from(subscriptionContent).toString('base64');
    
    res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="subscription.txt"',
    });
    res.end(encoded);
}

function handleInfoRequest(res) {
    const info = {
        status: 'running',
        version: '1.0.1',
        platform: 'zampto-node10-arm',
        uuid: CONFIG.uuid,
        nodeName: CONFIG.nodeName,
        port: CONFIG.port,
        features: {
            argoTunnel: !!CONFIG.argoHost,
            nezhaMonitoring: !!CONFIG.nezhaServer,
            telegramNotification: !!CONFIG.botToken,
        },
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        architecture: 'HTTP service and monitoring tool',
        singBoxManagedBy: 'zampto-start.sh',
        processManagement: 'delegated to parent shell script',
    };

    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(info, null, 2));
}

function handleRootRequest(res) {
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>sing-box Service - zampto Node</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
        }
        .status {
            padding: 10px;
            margin: 10px 0;
            border-radius: 4px;
            background: #e8f5e9;
            border-left: 4px solid #4caf50;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin: 20px 0;
        }
        .info-item {
            background: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
        }
        .label {
            font-weight: bold;
            color: #666;
        }
        .value {
            color: #333;
            word-break: break-all;
        }
        a {
            color: #2196F3;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .endpoint {
            background: #f5f5f5;
            padding: 10px;
            margin: 10px 0;
            border-radius: 4px;
            font-family: monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 sing-box Service</h1>
        <h2>zampto Node10 (ARM) Platform</h2>
        
        <div class="status">
            ✅ Service is running
        </div>
        
        <h3>Quick Links</h3>
        <div class="endpoint"><a href="/sub">📡 Get Subscription</a></div>
        <div class="endpoint"><a href="/info">📊 Service Info</a></div>
        
        <h3>Configuration</h3>
        <div class="info-grid">
            <div class="info-item">
                <div class="label">Node Name:</div>
                <div class="value">${CONFIG.nodeName}</div>
            </div>
            <div class="info-item">
                <div class="label">UUID:</div>
                <div class="value">${CONFIG.uuid}</div>
            </div>
            <div class="info-item">
                <div class="label">Listen Port:</div>
                <div class="value">8080</div>
            </div>
            <div class="info-item">
                <div class="label">Server Port:</div>
                <div class="value">${CONFIG.port}</div>
            </div>
            ${CONFIG.argoHost ? `
            <div class="info-item">
                <div class="label">Argo Domain:</div>
                <div class="value">${CONFIG.argoHost}</div>
            </div>
            ` : ''}
            ${CONFIG.nezhaServer ? `
            <div class="info-item">
                <div class="label">Nezha Server:</div>
                <div class="value">${CONFIG.nezhaServer}</div>
            </div>
            ` : ''}
        </div>
        
        <h3>Features</h3>
        <ul>
            <li>✅ CPU Optimization: 70% → 40-50%</li>
            <li>✅ nice/ionice process priority</li>
            <li>✅ Reduced logging (error level only)</li>
            <li>✅ 30s health check interval</li>
            <li>✅ ARM architecture support (arm64, armv7)</li>
        </ul>
        
        <h3>Endpoints</h3>
        <ul>
            <li><code>GET /</code> - This page</li>
            <li><code>GET /${CONFIG.subPath}</code> - Subscription link</li>
            <li><code>GET /info</code> - Service information</li>
            <li><code>GET /health</code> - Health check</li>
        </ul>
    </div>
</body>
</html>
    `;

    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
}

function handleHealthCheck(res) {
    checkSingBoxHealth().then((isHealthy) => {
        const statusCode = isHealthy ? 200 : 503;
        
        res.writeHead(statusCode, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: isHealthy ? 'healthy' : 'unhealthy',
            timestamp: new Date().toISOString(),
            singBoxManagedBy: 'zampto-start.sh',
        }));
    }).catch((error) => {
        res.writeHead(503, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'error',
            timestamp: new Date().toISOString(),
            error: error.message,
        }));
    });
}

// ============================================================================
// HTTP Server
// ============================================================================

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;

    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    logInfo(`${req.method} ${pathname}`);

    try {
        switch (pathname) {
            case '/':
                handleRootRequest(res);
                break;
            case `/${CONFIG.subPath}`:
                handleSubscriptionRequest(req, res);
                break;
            case '/info':
                handleInfoRequest(res);
                break;
            case '/health':
                handleHealthCheck(res);
                break;
            default:
                res.writeHead(404, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Not found' }));
        }
    } catch (error) {
        logError(`Request handler error: ${error.message}`);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Internal server error' }));
    }
});

// ============================================================================
// Graceful Shutdown
// ============================================================================

async function gracefulShutdown(signal) {
    logInfo(`Received ${signal}, initiating graceful shutdown...`);
    
    await stopSingBox();
    server.close(() => {
        logInfo('Server closed');
        process.exit(0);
    });

    // Force exit after 10 seconds
    setTimeout(() => {
        logError('Forced shutdown after timeout');
        process.exit(1);
    }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

process.on('uncaughtException', (error) => {
    logError(`Uncaught exception: ${error.message}`);
    process.exit(1);
});

// ============================================================================
// Server Startup
// ============================================================================

async function startup() {
    try {
        logInfo('========================================');
        logInfo('   sing-box HTTP Service - zampto Node.js');
        logInfo('   Platform: Node10 (ARM)');
        logInfo('   Architecture: HTTP Service & Monitoring');
        logInfo('   Process Management: Delegated');
        logInfo('========================================');

        // Ensure required directories exist
        ensureDirectoryExists(CONFIG.filePath);
        ensureDirectoryExists('logs');

        // sing-box process management by parent shell script
        logInfo('sing-box process management by parent shell script');

        // Start health check (monitor external processes)
        startHealthCheck();

        // Start HTTP server
        server.listen(CONFIG.port, () => {
            logInfo(`HTTP server listening on port ${CONFIG.port}`);
            logInfo(`Subscription endpoint: http://localhost:${CONFIG.port}/${CONFIG.subPath}`);
            
            sendTelegramNotification(
                `sing-box HTTP service started on zampto Node.js platform - Port: ${CONFIG.port}`,
                'success'
            ).catch(error => {
                logWarn(`Failed to send startup notification: ${error.message}`);
            });
        });
    } catch (error) {
        logError(`Startup failed: ${error.message}`);
        process.exit(1);
    }
}

// Start the service
startup();

module.exports = { server, checkSingBoxHealth };
