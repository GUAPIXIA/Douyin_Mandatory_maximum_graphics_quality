'use strict';
const fs = require('fs');

function hdr(p) {
  const b = fs.readFileSync(p);
  const hs = b.readUInt32LE(12);
  const json = b.slice(16, 16 + hs).toString('utf8');
  return { json, hs };
}

const a = hdr(process.argv[2]);
const c = hdr(process.argv[3]);

console.log('orig header len :', a.hs);
console.log('mine header len :', c.hs);
console.log('orig json len   :', a.json.length);
console.log('mine json len   :', c.json.length);

try { JSON.parse(a.json); console.log('orig parses     : OK'); } catch (e) { console.log('orig parses     : FAIL', e.message); }
try { JSON.parse(c.json); console.log('mine parses     : OK'); } catch (e) { console.log('mine parses     : FAIL', e.message); }

console.log('orig tail :', JSON.stringify(a.json.slice(-80)));
console.log('mine tail :', JSON.stringify(c.json.slice(-80)));

const offRe = /"offset":"?\d+"?/g;
console.log('orig offset samples:', (a.json.match(offRe) || []).slice(0, 3));
console.log('mine offset samples:', (c.json.match(offRe) || []).slice(0, 3));

// 找出第一个不同的位置
let i = 0;
while (i < Math.min(a.json.length, c.json.length) && a.json[i] === c.json[i]) i++;
console.log('first diff at', i);
console.log('orig@diff  :', JSON.stringify(a.json.slice(Math.max(0, i - 40), i + 40)));
console.log('mine@diff  :', JSON.stringify(c.json.slice(Math.max(0, i - 40), i + 40)));
