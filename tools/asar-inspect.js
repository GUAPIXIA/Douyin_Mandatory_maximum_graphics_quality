'use strict';
const fs = require('fs');

function inspect(p) {
  const b = fs.readFileSync(p);
  const sizeA = b.readUInt32LE(4);
  const sizeB = b.readUInt32LE(8);
  const sizeC = b.readUInt32LE(12);
  const header = b.slice(16, 16 + sizeC).toString('utf8');
  let ok = false, err = '';
  try { JSON.parse(header); ok = true; } catch (e) { err = e.message; }
  console.log(p);
  console.log('  file size        :', b.length);
  console.log('  u32@4 (pickle)   :', sizeA);
  console.log('  u32@8            :', sizeB);
  console.log('  u32@12 (hdr len) :', sizeC);
  console.log('  u32@4 - u32@12   :', sizeA - sizeC);
  console.log('  header parses    :', ok, ok ? '' : '-> ' + err);
  if (ok) {
    const j = JSON.parse(header);
    const c = j.files['__META-INF__'].files['win32x64.node'];
    console.log('  win32x64.node    :', JSON.stringify(c));
    const pre = j.files.node_modules.files['@annie'].files.electron.files.resources.files['preload.js'];
    console.log('  preload.js       :', JSON.stringify(pre));
  }
  console.log('  first 24 bytes   :', b.slice(0, 24).toString('hex'));
}

for (const p of process.argv.slice(2)) inspect(p);
