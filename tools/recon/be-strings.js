'use strict';
/**
 * 把文件里所有 UTF-16BE 解码出的“标识符样字符串”列出来（去重、按长度过滤）。
 * 用法: node be-strings.js <file>
 */
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
const out = new Map();

let cur = '';
for (let i = 0; i + 1 < buf.length; i += 2) {
  const code = (buf[i] << 8) | buf[i + 1];
  const ok = (code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff);
  if (ok) { cur += String.fromCharCode(code); continue; }
  if (cur.length >= 3 && cur.length <= 80) out.set(cur, (out.get(cur) || 0) + 1);
  cur = '';
}
if (cur.length >= 3) out.set(cur, (out.get(cur) || 0) + 1);

const rows = [...out.entries()].filter(([k]) => /^[A-Za-z0-9_\-.:/@\u4e00-\u9fff]+$/.test(k)).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
console.log('file: ' + process.argv[2] + '  strings: ' + rows.length);
for (const [k, c] of rows.slice(0, 300)) console.log(`${String(c).padStart(4)}  ${k}`);
