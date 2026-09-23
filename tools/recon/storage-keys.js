'use strict';
/**
 * 列出 Storage leveldb 文件里所有看起来像 sessionStorage/localStorage 键名的串：
 *   - ASCII 连续串（>=4）
 *   - UTF-16LE 连续串（>=4）
 * 并额外报告以 player/quality/clarity/gear/video 等前缀开头的候选。
 * 用法: node storage-keys.js <file>
 */
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
const out = new Map();

function emit(s, tag) {
  if (s.length < 4 || s.length > 90) return;
  if (!/^[\x20-\x7e\u4e00-\u9fff]+$/.test(s)) return;
  const key = tag + s;
  out.set(key, (out.get(key) || 0) + 1);
}

// ASCII
{
  const text = buf.toString('latin1');
  const re = /[\x20-\x7e]{4,90}/g;
  let m; while ((m = re.exec(text))) emit(m[0], 'A:');
}
// UTF-16LE
{
  let cur = '';
  for (let i = 0; i + 1 < buf.length; i += 2) {
    const code = buf[i] | (buf[i + 1] << 8);
    if ((code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff)) cur += String.fromCharCode(code);
    else { emit(cur, 'U:'); cur = ''; }
  }
  emit(cur, 'U:');
}

const all = [...out.keys()].map(k => k.slice(2));
const uniq = [...new Set(all)].sort();

const interesting = uniq.filter(s => /player|quality|clarity|gear|video|clarityReal|_MP_|__tea|session|map-\d+|volume|back/i.test(s));

console.log('file: ' + process.argv[2]);
console.log('unique strings: ' + uniq.length);
console.log('\n=== 相关候选 ===');
for (const s of interesting) console.log('  ' + s);
