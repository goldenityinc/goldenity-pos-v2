/**
 * Fake ESC/POS printer — dengar di TCP :9100 (Nota Dapur) & :9101 (Struk Kasir).
 * Terima byte mentah dari bridge (mode tcp), decode ESC/POS jadi teks terbaca.
 * Viewer HTTP di :9109  →  buka http://localhost:9109  (auto-refresh 2 dtk).
 */
import net from 'node:net';
import http from 'node:http';
import fs from 'node:fs';

const OUT = process.env.OUT || '.';
const PORTS = { 9100: 'NOTA DAPUR', 9101: 'STRUK KASIR' };
const tickets = []; // { id, label, port, ts, bytes, text }

function decodeEscPos(buf) {
  // Render per-baris: lacak posisi kolom absolut (ESC $) supaya row()
  // (2-kolom kiri/kanan) tampil rapi seperti di printer thermal betulan.
  const cols = 48;
  const lines = [];
  let line = ''; // string baris berjalan, di-pad sesuai posisi kolom
  const put = (s) => { line += s; };
  const setPos = (col) => { if (col > line.length) line += ' '.repeat(col - line.length); };
  const flush = () => { lines.push(line.replace(/\s+$/, '')); line = ''; };

  for (let i = 0; i < buf.length; i++) {
    const b = buf[i];
    if (b === 0x1b) {
      const cmd = buf[i + 1];
      if (cmd === 0x40) i += 1;                         // ESC @  init
      else if (cmd === 0x61) i += 2;                    // ESC a n  align
      else if (cmd === 0x45) i += 2;                    // ESC E n  bold
      else if (cmd === 0x21) i += 2;                    // ESC ! n
      else if (cmd === 0x2d) i += 2;                    // ESC - n  underline
      else if (cmd === 0x32) i += 1;                    // ESC 2    default line spacing
      else if (cmd === 0x33) i += 2;                    // ESC 3 n  line spacing
      else if (cmd === 0x64) { for (let k = 0; k < Math.min(buf[i + 2] || 0, 6); k++) flush(); i += 2; } // ESC d n  feed
      else if (cmd === 0x24) {                          // ESC $ nL nH  posisi absolut
        const nL = buf[i + 2] || 0; const nH = buf[i + 3] || 0;
        setPos(Math.round((nL + nH * 256) / 12)); // ~12 dot per char
        i += 3;
      } else if (cmd === 0x5c) i += 3;                  // ESC \ nL nH  relatif
      else i += 1;
      continue;
    }
    if (b === 0x1d) {
      const cmd = buf[i + 1];
      if (cmd === 0x21) i += 2;                         // GS ! n  ukuran
      else if (cmd === 0x42) i += 2;                    // GS B n
      else if (cmd === 0x56) { flush(); lines.push('[ POTONG KERTAS ]'); i += (buf[i + 2] === 0x42 ? 3 : 2); }
      else i += 1;
      continue;
    }
    if (b === 0x0a) { flush(); continue; }
    if (b === 0x0d) continue;
    if (b === 0x09) { setPos(Math.ceil((line.length + 1) / 8) * 8); continue; }
    if (b < 0x20) continue;
    put(Buffer.from([b]).toString('latin1'));
  }
  if (line) flush();
  void cols;
  return lines
    .map((l) =>
      l
        .replace(/^\.(?=[-=A-Za-z0-9*])/, '') // titik nyasar di awal baris
        .replace(/ \.(?=\S)/g, '  ') // titik pengisi kolom row() → spasi
        .replace(/ +\.$/, ''),
    )
    .join('\n')
    .replace(/\n{4,}/g, '\n\n\n')
    .trimEnd();
}

let n = 0;
for (const [port, label] of Object.entries(PORTS)) {
  net
    .createServer((sock) => {
      const chunks = [];
      sock.on('data', (d) => chunks.push(d));
      sock.on('end', () => {
        const raw = Buffer.concat(chunks);
        const id = ++n;
        const ts = new Date().toLocaleTimeString('id-ID');
        const text = decodeEscPos(raw);
        tickets.unshift({ id, label, port: Number(port), ts, bytes: raw.length, text });
        if (tickets.length > 40) tickets.length = 40;
        const bar = '='.repeat(52);
        console.log(`\n${bar}\n  ${label}  ·  :${port}  ·  ${ts}  ·  ${raw.length} byte\n${bar}\n${text}\n${bar}`);
        try {
          fs.writeFileSync(`${OUT}/print_${String(id).padStart(2, '0')}_${label.replace(/ /g, '')}_${port}.txt`, text);
        } catch {}
      });
      sock.on('error', () => {});
    })
    .listen(port, '127.0.0.1', () => console.log(`[fake-printer] ${label} :${port}`));
}

// ── HTTP viewer ──
const PAGE = `<!doctype html><meta charset="utf-8"><title>Fake Printer</title>
<style>
  :root{color-scheme:light dark}
  body{margin:0;background:#1b1b1b;color:#e8e8e8;font:14px/1.5 system-ui,sans-serif}
  header{padding:14px 20px;border-bottom:1px solid #333;display:flex;gap:14px;align-items:baseline;position:sticky;top:0;background:#1b1b1b;z-index:2}
  h1{font-size:15px;margin:0;font-weight:700}
  .muted{color:#999;font-size:12px}
  main{padding:20px;display:flex;flex-wrap:wrap;gap:20px;align-items:flex-start}
  .t{background:#f7f4ee;color:#211d17;border-radius:3px;padding:16px 16px 22px;box-shadow:0 8px 24px rgba(0,0,0,.4)}
  .t .h{font:700 10px/1.4 system-ui;letter-spacing:.12em;text-transform:uppercase;color:#6b6459;margin-bottom:9px}
  .t pre{margin:0;font:12px/1.5 "JetBrains Mono",ui-monospace,monospace;white-space:pre}
  .t .m{margin-top:9px;padding-top:7px;border-top:1px dashed #cbc3b4;font:11px/1.4 system-ui;color:#6b6459}
  .empty{color:#888;padding:40px}
</style>
<header><h1>&#128424; Fake Printer</h1><span class="muted">Struk Kasir :9101 &middot; Nota Dapur :9100 &middot; auto-refresh 2s</span></header>
<main id="out"><div class="empty">Belum ada cetakan. Buat web order lalu tekan Terima di POS&hellip;</div></main>
<script>
function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
async function tick(){
  try{
    const d = await (await fetch('/data')).json();
    if(!d.length) return;
    document.getElementById('out').innerHTML = d.map(function(t){
      return '<div class="t"><div class="h">'+t.label+' &middot; :'+t.port+' &middot; '+t.ts+
        '</div><pre>'+esc(t.text)+'</pre><div class="m">#'+t.id+' &middot; '+t.bytes+' byte</div></div>';
    }).join('');
  }catch(e){}
}
tick(); setInterval(tick, 2000);
</script>`;

http
  .createServer((req, res) => {
    if (req.url === '/data') {
      res.writeHead(200, { 'content-type': 'application/json' });
      return res.end(JSON.stringify(tickets));
    }
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    res.end(PAGE);
  })
  .listen(9109, '127.0.0.1', () => console.log('[fake-printer] viewer -> http://localhost:9109'));
