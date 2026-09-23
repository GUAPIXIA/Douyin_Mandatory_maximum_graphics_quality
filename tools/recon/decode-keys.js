'use strict';
/**
 * 解码 Chromium Session/Local Storage LevelDB 里的 UTF-16BE 键名。
 * 用法: node decode-keys.js <file>
 */
const fs = require('fs');

const file = process.argv[2];
const buf = fs.readFileSync(file);

// UTF-16BE 字符串（LevelDB 存储 Chromium Storage 键时常是 BE）
function decodeBE(slice) {
  let s = '';
  for (let i = 0; i + 1 < slice.length; i += 2) {
    const code = (slice[i] << 8) | slice[i + 1];
    if (code >= 32 && code < 127) s += String.fromCharCode(code);
    else if (code >= 0x4e00 && code <= 0x9fff) s += String.fromCharCode(code);
    else s += '\u0001';
  }
  return s;
}

const results = new Map();

// 逐字节找 “map-” 前缀（BE 编码 00 6d 00 61 00 70 00 2d）
const needle = Buffer.from('006d00610070002d', 'hex');
let idx = buf.indexOf(needle);
while (idx !== -1) {
  const end = Math.min(buf.length, idx + 200);
  const chunk = decodeBE(buf.slice(idx, end));
  const cleaned = chunk.split('\u0001')[0];
  if (cleaned.length >= 5) results.set(cleaned, (results.get(cleaned) || 0) + 1);
  idx = buf.indexOf(needle, idx + 2);
}

// 也扫 “_tea_” / 其他 ASCII 键（BE）
const needle2 = Buffer.from('005f007400650061005f', 'hex'); // _tea_
let i2 = buf.indexOf(needle2);
while (i2 !== -1) {
  const chunk = decodeBE(buf.slice(i2, Math.min(buf.length, i2 + 120)));
  const cleaned = chunk.split('\u0001')[0];
  if (cleaned.length >= 4) results.set(cleaned, (results.get(cleaned) || 0) + 1);
  i2 = buf.indexOf(needle2, i2 + 2);
}

const rows = [...results.entries()].sort();
console.log('file: ' + file);
console.log('decoded keys: ' + rows.length);
for (const [k, c] of rows) console.log(`  ${String(c).padStart(3)}  ${k}`);
