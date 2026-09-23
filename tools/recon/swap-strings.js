'use strict';
/**
 * 从 Storage LevelDB 文件中提取“字节交换后的 UTF-16”（实际是 UTF-16LE 文本被按 BE 读出）
 * 所对应的真实可读字符串，用于识别 storage KEY。
 * 用法: node swap-strings.js <file> [minLen]
 */
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
const minLen = Number(process.argv[3] || 4);
const out = new Map();

function emit(s) {
  if (s.length >= minLen && s.length <= 120) out.set(s, (out.get(s) || 0) + 1);
}

// 方式 A: 把每个 16bit 码元高低字节互换
let cur = '';
for (let i = 0; i + 1 < buf.length; i += 2) {
  const code = (buf[i] << 8) | buf[i + 1];   // 按 BE 组合
  const swapped = ((code & 0xff) << 8) | (code >> 8); // 再互换 -> 得到真实码元
  const ok = (swapped >= 32 && swapped < 127) || (swapped >= 0x4e00 && swapped <= 0x9fff);
  if (ok) cur += String.fromCharCode(swapped);
  else { emit(cur); cur = ''; }
}
emit(cur);

// 方式 B: 普通 UTF-16LE
cur = '';
for (let i = 0; i + 1 < buf.length; i += 2) {
  const code = buf[i] | (buf[i + 1] << 8);
  const ok = (code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff);
  if (ok) cur += String.fromCharCode(code);
  else { emit(cur); cur = ''; }
}
emit(cur);

const rows = [...out.entries()]
  .filter(([k]) => /^[\x20-\x7e\u4e00-\u9fff]+$/.test(k))
  .filter(([k]) => !/^https?:\/\//.test(k))
  .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));

console.log('file: ' + process.argv[2] + '  strings: ' + rows.length);
for (const [k, c] of rows.slice(0, 250)) console.log(`${String(c).padStart(4)}  ${k}`);
