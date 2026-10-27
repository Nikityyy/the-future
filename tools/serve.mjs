// Local preview of the deployed site: landing/ at /the-future/, build/web at /the-future/app/.
//   flutter build web --base-href /the-future/app/ && node tools/serve.mjs [port]
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { createGzip } from 'node:zlib';
import { extname, join, normalize } from 'node:path';

const port = Number(process.argv[2] ?? 4173);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.wasm': 'application/wasm', '.webmanifest': 'application/manifest+json', '.enc': 'application/json' };

createServer((req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const [root, rest] = path.startsWith('/the-future/app/') ? ['build/web', path.slice(16)] : path.startsWith('/the-future/') ? ['landing', path.slice(12)] : [null, ''];
  if (!root) return res.writeHead(302, { location: '/the-future/' }).end();
  let file = join(root, normalize('/' + rest));
  if (existsSync(file) && statSync(file).isDirectory()) file = join(file, 'index.html');
  if (!existsSync(file)) file = root === 'landing' ? 'landing/404.html' : join(root, 'index.html');
  // Gzip like GitHub Pages does, so load times here match the real site.
  const gzip = /gzip/.test(req.headers['accept-encoding'] ?? '') && !['.png', '.webp', '.woff2'].includes(extname(file));
  res.writeHead(existsSync(file) ? 200 : 404, { 'content-type': types[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store', ...(gzip && { 'content-encoding': 'gzip' }) });
  gzip ? createReadStream(file).pipe(createGzip()).pipe(res) : createReadStream(file).pipe(res);
}).listen(port, () => console.log(`http://localhost:${port}/the-future/  (app at /the-future/app/)`));
