'use strict';
/**
 * 输出 asar 内某个条目的 size（纯数字，便于 PowerShell 捕获）。
 * 用法: node asar-entry-size.js <app.asar> <inner/path>
 */
const fs = require('fs');

const [, , asarPath, inner] = process.argv;
const b = fs.readFileSync(asarPath);
const hs = b.readUInt32LE(12);
const header = JSON.parse(b.slice(16, 16 + hs).toString('utf8'));

function findNode(root, relPath) {
  let n = root;
  for (const part of relPath.split('/').filter(Boolean)) {
    n = n.files && n.files[part];
    if (!n) return null;
  }
  return n;
}

// header.files 是根映射；也兼容 {files:{...}} 形式
const root = header.files ? header : { files: header };
const node = findNode(root, inner);
if (!node) {
  console.error('entry not found: ' + inner);
  process.exit(1);
}
if (node.files) {
  console.error('entry is a directory: ' + inner);
  process.exit(1);
}
if (node.unpacked) {
  console.error('entry is unpacked: ' + inner);
  process.exit(1);
}
process.stdout.write(String(node.size));
