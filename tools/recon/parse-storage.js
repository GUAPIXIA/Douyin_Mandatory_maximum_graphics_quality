'use strict';
/**
 * 从 Chromium Session/Local Storage 的 leveldb 文件里，粗解析出 (key, value) 对。
 * 定位思路：Storage 的每个记录是 leveldb 内部键 + 数据；存储条目以
 *   0x00 '_' <utf16le 域> 0x00 开头，紧随其后是 UTF-16LE 的 map key。
 * 本脚本直接寻找 “clarityReal” 之类的值，并把其前面 200 字节用多种编码打印，
 * 以便确定键名。
 *
 * 用法: node parse-storage.js <file> <valueToken>
 */
const fs = require('fs');

const file = process.argv[2];
const token = process.argv[3];
const buf = fs.readFileSync(file);

function utf16leAt(offset, maxLen) {
  let s = '';
  for (let i = offset; i + 1 < buf.length && s.length < maxLen; i += 2) {
    const code = buf[i] | (buf[i + 1] << 8);
    if (code === 0) break;
    if ((code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff)) s += String.fromCharCode(code);
    else s += '\u0001';
  }
  return s;
}

// 找所有出现位置（UTF-16LE）
const needle = Buffer.from(token, 'utf16le');
const positions = [];
let idx = buf.indexOf(needle);
while (idx !== -1) { positions.push(idx); idx = buf.indexOf(needle, idx + 2); }

console.log(`file: ${file}`);
console.log(`token "${token}" (UTF-16LE) occurrences: ${positions.length}`);

for (const pos of positions) {
  console.log(`\n--------------- occurrence at byte ${pos} ---------------`);
  // 向前 400 字节逐 2 字节扫描，挑出连续可读的 UTF-16LE 串
  const back = buf.slice(Math.max(0, pos - 500), pos);
  let s = '';
  const segs = [];
  for (let i = 0; i + 1 < back.length; i += 2) {
    const code = back[i] | (back[i + 1] << 8);
    if ((code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff)) s += String.fromCharCode(code);
    else { if (s.length >= 3) segs.push(s); s = ''; }
  }
  if (s.length >= 3) segs.push(s);
  console.log('前置可读串(UTF-16LE, 由远到近):');
  for (const seg of segs) console.log('   | ' + seg);
  console.log('值起始片段: ' + utf16leAt(pos, 160).split('\u0001')[0]);
}
