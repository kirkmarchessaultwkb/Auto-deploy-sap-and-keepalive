const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const PORT = process.env.PORT || 8080;

console.log('[INFO] Spawning start.sh in background...');

// 启动 start.sh（后台，不阻塞）
spawn('bash', ['/home/container/start.sh'], {
  stdio: 'inherit',
  detached: true,  // 后台运行
});

// 启动 HTTP 服务器
const server = http.createServer((req, res) => {
  if (req.url === '/sub') {
    // 读取订阅文件
    try {
      const sub = fs.readFileSync('/home/container/.npm/sub.txt', 'utf8');
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(sub);
    } catch (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Subscription not found\n');
    }
  } else if (req.url === '/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'running', port: PORT }));
  } else if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK\n');
  } else {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Argo Service Running\n');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[INFO] HTTP Server listening on 0.0.0.0:${PORT}`);
  console.log(`[INFO] GET /sub     - Subscription`);
  console.log(`[INFO] GET /info    - Info`);
  console.log(`[INFO] GET /health  - Health check`);
});

process.on('SIGTERM', () => {
  console.log('[INFO] SIGTERM received, closing server...');
  server.close(() => process.exit(0));
});
