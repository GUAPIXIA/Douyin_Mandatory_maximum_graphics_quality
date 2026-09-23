#!/usr/bin/env node
/**
 * asar-verify.js —— 比较两个 asar 归档，报告哪些常规条目内容不同。
 * 用法: node asar-verify.js <a.asar> <b.asar>
 */
'use strict';
const fs = require('fs');
const crypto = require('crypto');

function load(f) {
  const b = fs.readFileSync(f);
  const hs = b.readUInt32LE(12);
  const j = JSON.parse(b.slice(16, 16 + hs).toString('utf8'));
  const cb = 8 + b.readUInt32LE(4);
  return { b, j, cb, hs, size: b.length };
}

function collect(node, prefix, out) {
  for (const k in node.files) {
    const f = node.files[k];
    const p = prefix ? prefix + '/' + k : k;
    if (f.files) collect(f, p, out);
    else out.push({ path: p, entry: f });
  }
}

function digest(A, entry) {
  if (entry.unpacked) return 'UNPACKED';
  const start = A.cb + Number(entry.offset);
  return crypto.createHash('sha256').update(A.b.slice(start, start + entry.size)).digest('hex');
}

const [a, b] = process.argv.slice(2);
if (!a || !b) { console.error('usage: node asar-verify.js <a.asar> <b.asar>'); process.exit(2); }

const A = load(a), B = load(b);
const la = [], lb = [];
collect(A.j, '', la);
collect(B.j, '', lb);

const mapB = new Map(lb.map(x => [x.path, x]));
const mapA = new Map(la.map(x => [x.path, x]));

let same = 0, changed = [], onlyA = [], onlyB = [];
for (const { path: p, entry } of la) {
  const other = mapB.get(p);
  if (!other) { onlyA.push(p); continue; }
  if (digest(A, entry) === digest(B, other.entry)) same++;
  else changed.push({ path: p, aSize: entry.size, bSize: other.entry.size, aUnpacked: !!entry.unpacked, bUnpacked: !!other.entry.unpacked });
}
for (const { path: p } of lb) if (!mapA.has(p)) onlyB.push(p);

console.log(`A = ${a}  (${A.size} bytes, ${la.length} entries)`);
console.log(`B = ${b}  (${B.size} bytes, ${lb.length} entries)`);
console.log(`identical entries : ${same}`);
console.log(`changed entries   : ${changed.length}`);
for (const c of changed.slice(0, 50)) {
  console.log(`   ~ ${c.path}  size ${c.aSize} -> ${c.bSize}${c.aUnpacked || c.bUnpacked ? '  [unpacked flag mismatch]' : ''}`);
}
console.log(`only in A         : ${onlyA.length} ${onlyA.slice(0, 10).join(', ')}`);
console.log(`only in B         : ${onlyB.length} ${onlyB.slice(0, 10).join(', ')}`);
process.exit(changed.length === 0 && onlyA.length === 0 && onlyB.length === 0 ? 0 : 0);
