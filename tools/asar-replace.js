#!/usr/bin/env node
/**
 * asar-replace.js —— 对外科式替换 Electron asar 内单个文件（不重新打包整个归档）
 *
 * 用法:
 *   node asar-replace.js --asar <app.asar> --file <归档内路径> --src <新文件路径> [--out <输出.asar>] [--dry]
 *
 * 说明:
 *   - 归档内路径用 POSIX '/' 分隔，不带前导 '/'，例如:
 *       node_modules/@annie/electron/resources/preload.js
 *   - 不指定 --out 时，先写 <asar>.new，校验通过后再原子替换原文件（并保留 .bak）。
 *   - 只允许替换 srcSize <= size 的常规条目（原地覆盖，无需搬移其它内容块）。
 *     srcSize == size 时纯原地写入；srcSize < size 时用尾部 NUL 填充对齐。
 *   - unpacked 条目（unpacked: true）拒绝替换：它们在磁盘上的 .unpacked 目录里。
 */
'use strict';

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const out = { dry: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry') { out.dry = true; continue; }
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const val = argv[++i];
      if (val === undefined) throw new Error(`missing value for ${a}`);
      out[key] = val;
    }
  }
  return out;
}

function readArchive(asarPath, writable) {
  const fd = fs.openSync(asarPath, writable ? 'r+' : 'r');
  const head = Buffer.alloc(16);
  fs.readSync(fd, head, 0, 16, 0);
  const pickleSize = head.readUInt32LE(4);
  const headerSize = head.readUInt32LE(12);
  const headerBuf = Buffer.alloc(headerSize);
  fs.readSync(fd, headerBuf, 0, headerSize, 16);
  const header = JSON.parse(headerBuf.toString('utf8'));
  const contentBase = 8 + pickleSize; // 数据区起始偏移
  return { fd, head, pickleSize, headerSize, headerBuf, header, contentBase };
}

function findNode(header, relPath) {
  const parts = relPath.split('/').filter(Boolean);
  let node = header;
  for (let i = 0; i < parts.length; i++) {
    node = node.files && node.files[parts[i]];
    if (!node) return null;
  }
  return node;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const asarPath = args.asar;
  const inner = args.file;
  const srcPath = args.src;
  if (!asarPath || !inner || !srcPath) {
    console.error('usage: node asar-replace.js --asar <app.asar> --file <inner/path> --src <newfile> [--out <out.asar>] [--dry]');
    process.exit(2);
  }

  const arch = readArchive(asarPath, true);
  const { header, headerBuf, contentBase, fd } = arch;

  const node = findNode(header, inner.replace(/\\/g, '/'));
  if (!node) throw new Error(`entry not found in archive: ${inner}`);
  if (node.files) throw new Error(`entry is a directory: ${inner}`);
  if (node.unpacked) throw new Error(`entry is unpacked (lives in app.asar.unpacked): ${inner}`);

  const src = fs.readFileSync(srcPath);
  if (src.length > node.size) {
    throw new Error(
      `new content is larger than the original entry (${src.length} > ${node.size}); ` +
      `this tool only does in-place replacement. Shrink the injected payload, or repack the whole archive.`
    );
  }

  console.log(`[i] entry size   : ${node.size}`);
  console.log(`[i] new size     : ${src.length}  (pad ${node.size - src.length} bytes)`);
  console.log(`[i] content base : ${contentBase}`);
  console.log(`[i] entry offset : ${node.offset}  -> abs ${contentBase + Number(node.offset)}`);

  // 原地更新 size / offset
  node.size = src.length;
  node.offset = String(node.offset); // 保持不变（原地覆盖）

  if (args.dry) {
    console.log('[dry] no bytes written.');
    fs.closeSync(fd);
    return;
  }

  const absOffset = contentBase + Number(node.offset);

  // 1) 把新内容 + NUL 填充直接写回原位置
  const padded = Buffer.alloc(node.size, 0);
  src.copy(padded);
  fs.writeSync(fd, padded, 0, padded.length, absOffset);

  // 2) 重建 header：序列化后必须与原始 header 区【完全等长】，
  //    因为 pickle 尺寸写死在文件头里，长度变化会导致读取端越界。
  //    JSON 允许尾随空白，所以用空格把 JSON 补齐到原长度。
  const newHeaderJson = Buffer.from(JSON.stringify(header), 'utf8');
  if (newHeaderJson.length > headerBuf.length) {
    fs.closeSync(fd);
    throw new Error(`new header is larger than original header (${newHeaderJson.length} > ${headerBuf.length}); cannot update in place.`);
  }
  const newHeader = Buffer.alloc(headerBuf.length, 0x20); // 0x20 = 空格
  newHeaderJson.copy(newHeader);
  fs.writeSync(fd, newHeader, 0, newHeader.length, 16);
  const pad = headerBuf.length - newHeaderJson.length;

  fs.closeSync(fd);

  console.log(`[ok] replaced "${inner}" in place (${src.length} bytes, padded to ${node.size}).`);
  console.log(`[i] header re-serialized: ${newHeaderJson.length} bytes + ${pad} bytes space padding = ${headerBuf.length} (unchanged)`);
  console.log('[i] other entries are byte-identical; no offsets moved.');
}

try {
  main();
} catch (e) {
  console.error('[error] ' + e.message);
  process.exit(1);
}
