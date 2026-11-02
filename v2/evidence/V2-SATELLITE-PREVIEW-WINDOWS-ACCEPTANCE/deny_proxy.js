// Local CONNECT proxy for the offline test. Refuses Esri hosts while the state file says "off"; everything else passes,
// so MATLAB licensing keeps working. No system network setting changes. Usage: node deny_proxy.js <port> <stateFile> <logFile>
const net = require('net'), http = require('http'), fs = require('fs');
const [port, stateFile, logFile] = process.argv.slice(2);
const counts = {};
const note = (host, s) => { const k = `${host} ${s}`; counts[k] = (counts[k] || 0) + 1; fs.writeFileSync(logFile, Object.entries(counts).map(([a, b]) => `${b} ${a}`).sort().join('\n') + '\n'); };
const denied = h => /arcgis|arcgisonline|esri/i.test(h) && fs.readFileSync(stateFile, 'utf8').trim() === 'off';
const srv = http.createServer((q, r) => {
  let host = ''; try { host = new URL(q.url).hostname; } catch {}
  if (denied(host)) { note(host, 'denied'); r.writeHead(503); return r.end(); }
  note(host, 'plain'); const u = new URL(q.url);
  const o = http.request({ host: u.hostname, port: u.port || 80, path: u.pathname + u.search, method: q.method, headers: q.headers }, x => { r.writeHead(x.statusCode, x.headers); x.pipe(r); });
  o.on('error', () => { r.writeHead(502); r.end(); }); q.pipe(o);
});
srv.on('connect', (q, c, head) => {
  const [host, p] = q.url.split(':');
  if (denied(host)) { note(host, 'denied'); c.end('HTTP/1.1 503 Denied\r\n\r\n'); return; }
  note(host, 'allowed');
  const s = net.connect(+p || 443, host, () => { c.write('HTTP/1.1 200 OK\r\n\r\n'); s.write(head); s.pipe(c); c.pipe(s); });
  s.on('error', () => c.destroy()); c.on('error', () => s.destroy());
});
srv.listen(+port, '127.0.0.1');
