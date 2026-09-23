'use strict';
/**
 * 在 Chromium Storage 文件里定位某个 token（UTF-16LE）前后的原始结构，
 * 主要用于找出 Session Storage / localStorage 里存画质的 KEY 名。
 * 用法: node find-key.js <file> <token>
 */
const fs = require('fs');

const file = process.argv[2];
const token = process.argv[3];
const before = Number(process.argv[4] || 400);
const after = Number(process.argv[5] || 200);

const buf = fs.readFileSync(file);

// UTF-16LE 编码的 token
const needs = [...token].map(c => Buffer.from(c, 'utf16le'));
const needle = Buffer.concat(needs);

let idx = buf.indexOf(needle);
let n = 0;
while (idx !== -1 && n < 6) {
  const start = Math.max(0, idx - before);
  const end = Math.min(buf.length, idx + after);
  const slice = buf.slice(start, end);
  console.log(`\n===== hit #${n} at byte ${idx} =====`);
  // 尝试按 UTF-16LE 解码，不可打印字符显示为 ·
  let s = '';
  for (let i = 0; i + 1 < slice.length; i += 2) {
    const code = slice[i] | (slice[i + 1] << 8);
    s += (code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff) ? String.fromCharCode(code) : '·';
  }
  console.log('UTF16LE>> ' + s);
  n++;
  idx = buf.indexOf(needle, idx + 2);
}
if (n === 0) console.log('token not found (UTF-16LE): ' + token);
