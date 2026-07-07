const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const base = path.join(__dirname, 'build', 'web');

const mimeTypes = {
  'html': 'text/html',
  'js':   'application/javascript',
  'css':  'text/css',
  'wasm': 'application/wasm',
  'json': 'application/json',
  'png':  'image/png',
  'ico':  'image/x-icon',
  'svg':  'image/svg+xml',
  'ttf':  'font/ttf',
  'woff': 'font/woff',
  'woff2':'font/woff2',
};

http.createServer((req, res) => {
  // Strip query string before resolving file path
  const parsedUrl = url.parse(req.url);
  let filePath = path.join(base, parsedUrl.pathname === '/' ? 'index.html' : parsedUrl.pathname);

  if (!fs.existsSync(filePath)) {
    // SPA fallback
    filePath = path.join(base, 'index.html');
  }

  const ext = path.extname(filePath).slice(1).toLowerCase();
  const contentType = mimeTypes[ext] || 'application/octet-stream';

  res.writeHead(200, { 'Content-Type': contentType });
  fs.createReadStream(filePath).pipe(res);

}).listen(8080, () => {
  console.log('✅ SyncLedger server running at http://localhost:8080');
});
