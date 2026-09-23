'use strict';
/**
 * 在 LevelDB / Chromium 存储文件里搜索画质相关 token（支持 UTF-8 与 UTF-16LE 两种编码）。
 * 用法: node search-quality.js <rootDir...>
 */
const fs = require('fs');
const path = require('path');

const TOKENS = [
  'uhd', 'uhd50p', '2k4k', 'normal_1080_0', 'adapt_lowest_1080_1', 'low_1080_0',
  'gear_name', 'gearName', 'quality_type', 'clarity', 'switchClarity', 'setQuality',
  'currentQuality', 'qualityList', 'player_quality', 'videoQuality', 'video_quality',
  '默认清晰度', '清晰度', '超清', '蓝光', '原画',
];

const SKIP_DIR = /[\\/](Cache|Code Cache|GPUCache|DawnGraphiteCache|DawnWebGPUCache|blob_storage|VideoDecodeStats|hybridElectronRTC|Partitions\\annie-session\\Cache)[\\/]/i;
const MAX_SIZE = 25 * 1024 * 1024;

function decodeUtf16LE(buf) {
  // 把 UTF-16LE 字节流按可读字符近似还原（只保留 ASCII 与常见 CJK）
  let out = '';
  for (let i = 0; i + 1 < buf.length; i += 2) {
    const code = buf[i] | (buf[i + 1] << 8);
    if (code === 0) { out += '\u0000'; continue; }
    out += String.fromCharCode(code);
  }
  return out;
}

function decodeLatin(buf) {
  const bytes = new Uint8Array(buf.length);
  for (let i = 0; i < buf.length; i++) bytes[i] = buf[i];
  return Buffer.from(bytes).toString('latin1');
}

const hits = new Map(); // token -> [{file, enc, ctx}]

function scan(file) {
  let st;
  try { st = fs.statSync(file); } catch { return; }
  if (!st.isFile() || st.size === 0 || st.size > MAX_SIZE) return;
  let buf;
  try { buf = fs.readFileSync(file); } catch { return; }

  const latin = decodeLatin(buf);
  const utf16 = decodeUtf16LE(buf);

  for (const tok of TOKENS) {
    for (const [enc, text] of [['latin1', latin], ['utf16le', utf16]]) {
      let idx = text.indexOf(tok);
      let count = 0;
      while (idx !== -1 && count < 2) {
        const ctx = text.slice(Math.max(0, idx - 90), idx + 130).replace(/[\r\n]+/g, '\\n').replace(/[^\x20-\x7e\u4e00-\u9fff]/g, '.');
        const key = tok + '|' + enc;
        if (!hits.has(key)) hits.set(key, []);
        hits.get(key).push({ file, ctx });
        count++;
        idx = text.indexOf(tok, idx + 1);
      }
    }
  }
}

function walk(dir) {
  if (SKIP_DIR.test(dir)) return;
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.isFile()) scan(p);
  }
}

for (const root of process.argv.slice(2)) walk(root);

const out = [];
for (const [key, list] of hits) {
  const [tok, enc] = key.split('|');
  out.push(`\n########## token "${tok}" [${enc}] hits=${list.length}`);
  for (const h of list) {
    out.push(`  FILE: ${h.file}`);
    out.push(`  CTX : ${h.ctx}`);
  }
}
fs.writeFileSync(path.join(__dirname, '..', 'work', 'quality-hits.txt'), out.join('\n') || '(no hits)', 'utf8');
console.log('tokens with hits: ' + hits.size);
for (const k of hits.keys()) console.log('  ' + k + '  -> ' + hits.get(k).length);
console.log('report: D:\\Code\\dy\\work\\quality-hits.txt');
