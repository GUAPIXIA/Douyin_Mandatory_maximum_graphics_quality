'use strict';
/**
 * 打印文件中所有看起来像 Storage KEY 的短字符串（UTF-8 / UTF-16LE 两种编码），
 * 用于识别 localStorage / sessionStorage 的键名。
 * 用法: node list-keys.js <file> [maxLen]
 */
const fs = require('fs');

const file = process.argv[2];
const maxLen = Number(process.argv[3] || 60);
const buf = fs.readFileSync(file);

const found = new Map(); // text -> count

// 1) UTF-8 可打印串
{
  const text = buf.toString('latin1');
  const re = /[\x20-\x7e]{4,120}/g;
  let m;
  while ((m = re.exec(text))) {
    const s = m[0];
    // 只保留像标识符/key 的串
    if (/^[A-Za-z0-9_\-.:@/]{4,60}$/.test(s) && !/^https?:/.test(s)) {
      found.set(s, (found.get(s) || 0) + 1);
    }
  }
}

// 2) UTF-16LE 可打印串
{
  let cur = '';
  for (let i = 0; i + 1 < buf.length; i += 2) {
    const code = buf[i] | (buf[i + 1] << 8);
    const ok = (code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff);
    if (ok) cur += String.fromCharCode(code);
    else { if (cur.length >= 4 && cur.length <= maxLen) found.set(cur, (found.get(cur) || 0) + 1); cur = ''; }
  }
}

// 3) UTF-16BE 可打印串（LevelDB 里的键常是 big-endian 存储）
{
  let cur = '';
  for (let i = 0; i + 1 < buf.length; i += 2) {
    const code = (buf[i] << 8) | buf[i + 1];
    const ok = (code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff);
    if (ok) cur += String.fromCharCode(code);
    else { if (cur.length >= 4 && cur.length <= maxLen) found.set('[BE]' + cur, (found.get('[BE]' + cur) || 0) + 1); cur = ''; }
  }
}

const rows = [...found.entries()].sort((a, b) => b[1] - a[1]);
console.log('file: ' + file + '  candidates: ' + rows.length);
for (const [s, c] of rows.slice(0, 400)) console.log(`${String(c).padStart(4)}  ${s}`);
