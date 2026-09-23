'use strict';
/**
 * 在 Storage leveldb 文件里，按 "map-<id>-player_" 前缀定位键名，并打印键名 + 紧随其后的值片段。
 * 用法: node find-player-key.js <file> <id>
 */
const fs = require('fs');

const file = process.argv[2];
const id = process.argv[3];
const buf = fs.readFileSync(file);

const u16 = (s) => Buffer.from(s, 'utf16le');
const needle = u16(`map-${id}-player_`);

let idx = buf.indexOf(needle);
let n = 0;
while (idx !== -1) {
  console.log(`\n===== map-${id} hit #${n} at byte ${idx} =====`);
  // 键名：从 needle 开始按 UTF-16LE 读到 NUL
  let key = '';
  for (let i = idx; i + 1 < buf.length; i += 2) {
    const code = buf[i] | (buf[i + 1] << 8);
    if (code === 0) break;
    key += ((code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff)) ? String.fromCharCode(code) : '\u0001';
  }
  console.log('KEY : ' + key);

  // 值：键名结束后继续扫描，跳过 leveldb 内部结构，找 JSON 起点
  const scanEnd = Math.min(buf.length, idx + 2000);
  let val = '';
  let started = false;
  for (let i = idx + key.length * 2; i + 1 < scanEnd; i += 2) {
    const code = buf[i] | (buf[i + 1] << 8);
    const ch = ((code >= 32 && code < 127) || (code >= 0x4e00 && code <= 0x9fff)) ? String.fromCharCode(code) : '\u0001';
    if (ch === '{' || ch === '[') started = true;
    if (started) {
      if (ch === '\u0001') break;
      val += ch;
    }
    if (val.length > 700) break;
  }
  console.log('VALUE: ' + (val || '(未找到 JSON 起头)'));
  n++;
  idx = buf.indexOf(needle, idx + 2);
}
if (n === 0) console.log(`map-${id}-player_ 未找到`);
