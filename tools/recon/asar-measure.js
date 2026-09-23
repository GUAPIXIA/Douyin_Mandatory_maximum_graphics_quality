'use strict';
// 精确测量 header 重序列化后的长度差异，并把结果写文件（避免控制台噪音）
const fs = require('fs');

const asarPath = process.argv[2];
const outPath = process.argv[3];
const orig = fs.readFileSync(asarPath);
const hs = orig.readUInt32LE(12);
const origJson = orig.slice(16, 16 + hs).toString('utf8');
const j = JSON.parse(origJson);

const reStringified = JSON.stringify(j);
const reFiles = JSON.stringify(j.files);

let diffAt = 0;
while (diffAt < Math.min(origJson.length, reStringified.length) && origJson[diffAt] === reStringified[diffAt]) diffAt++;

const report = {
  origHeaderLen: hs,
  origJsonLen: origJson.length,
  reStringifiedLen: reStringified.length,
  delta: reStringified.length - origJson.length,
  reFilesLen: reFiles.length,
  firstDiffAt: diffAt,
  origAt: origJson.slice(Math.max(0, diffAt - 60), diffAt + 60),
  mineAt: reStringified.slice(Math.max(0, diffAt - 60), diffAt + 60),
  origTail: origJson.slice(-120),
  mineTail: reStringified.slice(-120),
  parseOrig: true,
};
try { JSON.parse(reStringified); report.parseMine = true; } catch (e) { report.parseMine = e.message; }

fs.writeFileSync(outPath, JSON.stringify(report, null, 2), 'utf8');
console.log('written ' + outPath);
