const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const SUBSCRIPTION_FILE = '/home/container/.npm/sub.txt';

const server = http.createServer((req, res) => {
  // Add CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.url === '/sub') {
    // Handle subscription file request
    try {
      if (fs.existsSync(SUBSCRIPTION_FILE)) {
        const content = fs.readFileSync(SUBSCRIPTION_FILE, 'utf8');
        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0'
        });
        res.end(content);
        console.log(`[${new Date().toISOString()}] [INFO] Subscription served: ${content.length} bytes`);
      } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Subscription file not found');
        console.log(`[${new Date().toISOString()}] [WARN] Subscription file not found: ${SUBSCRIPTION_FILE}`);
      }
    } catch (error) {
      console.error(`[${new Date().toISOString()}] [ERROR] Failed to read subscription file:`, error.message);
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal server error');
    }
  } else if (req.url === '/info') {
    // Handle info request
    try {
      const info = {
        timestamp: new Date().toISOString(),
        port: PORT,
        subscription_file: SUBSCRIPTION_FILE,
        subscription_exists: fs.existsSync(SUBSCRIPTION_FILE),
        node_version: process.version,
        platform: process.platform,
        arch: process.arch,
        uptime: process.uptime()
      };

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(info, null, 2));
      console.log(`[${new Date().toISOString()}] [INFO] Info request served`);
    } catch (error) {
      console.error(`[${new Date().toISOString()}] [ERROR] Failed to generate info:`, error.message);
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal server error');
    }
  } else if (req.url === '/health') {
    // Health check endpoint
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    }));
  } else {
    // Default response
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      service: 'zampto-http-server',
      version: '1.0.0',
      endpoints: {
        '/sub': 'Subscription file endpoint',
        '/info': 'Server information',
        '/health': 'Health check'
      },
      timestamp: new Date().toISOString()
    }));
  }
});

// Error handling
server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`[${new Date().toISOString()}] [ERROR] Port ${PORT} is already in use`);
  } else {
    console.error(`[${new Date().toISOString()}] [ERROR] Server error:`, error.message);
  }
  process.exit(1);
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`[${new Date().toISOString()}] [INFO] HTTP Server started on 0.0.0.0:${PORT}`);
  console.log(`[${new Date().toISOString()}] [INFO] Available endpoints:`);
  console.log(`[${new Date().toISOString()}] [INFO]   GET /sub    - Subscription file`);
  console.log(`[${new Date().toISOString()}] [INFO]   GET /info   - Server information`);
  console.log(`[${new Date().toISOString()}] [INFO]   GET /health - Health check`);
  console.log(`[${new Date().toISOString()}] [INFO]   GET /       - Service information`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log(`[${new Date().toISOString()}] [INFO] Received SIGTERM, shutting down gracefully`);
  server.close(() => {
    console.log(`[${new Date().toISOString()}] [INFO] Server closed`);
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log(`[${new Date().toISOString()}] [INFO] Received SIGINT, shutting down gracefully`);
  server.close(() => {
    console.log(`[${new Date().toISOString()}] [INFO] Server closed`);
    process.exit(0);
  });
});