#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.SERVER_PORT || 3000;
const SUB_FILE = path.join(process.cwd(), '.npm', 'sub.txt');

const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/ping') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK');
    return;
  }

  if (req.url === '/sub' || req.url === '/subscription') {
    try {
      if (fs.existsSync(SUB_FILE)) {
        const content = fs.readFileSync(SUB_FILE, 'utf8').trim();
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(content);
      } else {
        res.writeHead(503, { 'Content-Type': 'text/plain' });
        res.end('Subscription not ready');
      }
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end(`Error: ${err.message}`);
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

server.on('error', (err) => {
  console.error('Server error:', err);
  process.exit(1);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[server] Listening on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('[server] Received SIGTERM, shutting down gracefully');
  server.close(() => {
    console.log('[server] Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('[server] Received SIGINT, shutting down gracefully');
  server.close(() => {
    console.log('[server] Server closed');
    process.exit(0);
  });
});

setInterval(() => {
  console.log(`[server] Health check: ${new Date().toISOString()}`);
}, 60000);
