'use strict';
/**
 * 在 Storage leveldb 里找出所有出现 "player_" 的位置，并打印该处前后 120 字节的
 * ASCII 视图与 UTF-16LE 视图，用于确定完整的 storage 键名。
 * 用法: node find-player.js <file>
 */
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
const needle = Buffer.from('player_', 'latin1');

let idx = buf.indexOf(needle);
let n = 0;
while (idx !== -1 && n < 40) {
  const start = Math.max(0, idx - 60);
  const end = Math.min(buf.length, idx + 120);
  const slice = buf.slice(start, end);
  console.log(`\n=== #${n} at byte ${idx} ===`);
  console.log('ASCII : ' + slice.toString('latin1').replace(/[^\x20-\x7e]/g, '.'));
  let u = '';
  for (let i = 0; i + 1 < slice.length; i += 2) {
    const c = slice[i] | (slice[i + 1] << 8);
    u += ((c >= 32 && c < 127) || (c >= 0x4e00 && c <= 0x9fff)) ? String.fromCharCode(c) : '.';
  }
  console.log('U16LE : ' + u);
  n++;
  idx = buf.indexOf(needle, idx + 1);
}
if (n === 0) console.log('no "player_" found');
