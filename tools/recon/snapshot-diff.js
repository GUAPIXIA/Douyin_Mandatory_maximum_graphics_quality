'use strict';
/**
 * 对比改动前后的 AppData 快照，列出新增/删除/修改的文件。
 * 用法: node snapshot-diff.js <before.json>
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const here = __dirname;
const beforePath = process.argv[2] || path.join(here, '..', 'work', 'snapshot', 'before', 'snapshot.json');
const afterPath = path.join(path.dirname(beforePath), '..', 'after', 'snapshot.json');
const reportPath = path.join(path.dirname(beforePath), '..', 'diff-report.txt');

const before = JSON.parse(fs.readFileSync(beforePath, 'utf8'));
const beforeMap = new Map(before.map(x => [x.Path.toLowerCase(), x]));

const roots = [
  'C:\\Users\\Administrator\\AppData\\Roaming\\douyin',
  'C:\\Users\\Administrator\\AppData\\Roaming\\douyin_lynx',
  'C:\\Users\\Administrator\\AppData\\Roaming\\douyin_widget',
];

function walk(dir, out) {
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.isFile()) {
      let st;
      try { st = fs.statSync(p); } catch { continue; }
      if (st.size >= 60 * 1024 * 1024) { out.push({ Path: p, Size: st.size, MTime: st.mtime.toISOString(), Hash: 'SKIPPED-BIG' }); continue; }
      let h = '';
      try { h = crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'); } catch { h = 'ERR'; }
      out.push({ Path: p, Size: st.size, MTime: st.mtime.toISOString(), Hash: h });
    }
  }
}

const after = [];
for (const r of roots) walk(r, after);
fs.mkdirSync(path.dirname(afterPath), { recursive: true });
fs.writeFileSync(afterPath, JSON.stringify(after), 'utf8');

const afterMap = new Map(after.map(x => [x.Path.toLowerCase(), x]));

const added = [], removed = [], changed = [];
for (const [k, a] of afterMap) {
  const b = beforeMap.get(k);
  if (!b) { added.push(a); continue; }
  if (a.Hash !== b.Hash || a.Size !== b.Size) changed.push({ after: a, before: b });
}
for (const [k, b] of beforeMap) if (!afterMap.has(k)) removed.push(b);

const lines = [];
lines.push('files: before=' + before.length + ' after=' + after.length);
lines.push('added=' + added.length + ' removed=' + removed.length + ' changed=' + changed.length);
lines.push('');
lines.push('=== CHANGED ===');
for (const c of changed) {
  lines.push(`${c.after.Path}`);
  lines.push(`    size ${c.before.Size} -> ${c.after.Size}`);
  lines.push(`    mtime ${c.before.MTime} -> ${c.after.MTime}`);
}
lines.push('');
lines.push('=== ADDED ===');
for (const a of added) lines.push(`${a.Path}  (${a.Size} bytes, ${a.MTime})`);
lines.push('');
lines.push('=== REMOVED ===');
for (const r of removed) lines.push(`${r.Path}  (${r.Size} bytes)`);

fs.writeFileSync(reportPath, lines.join('\n'), 'utf8');

// 控制台只打印摘要 + 可能含画质设置的候选文件
console.log(lines.slice(0, 3).join('\n'));
const interesting = [...changed.map(c => c.after.Path), ...added.map(a => a.Path)]
  .filter(p => !/[\\/](Cache|Code Cache|GPUCache|DawnGraphiteCache|DawnWebGPUCache|blob_storage|VideoDecodeStats|Network|Session Storage|logs?|alog)[\\/]/i.test(p));
console.log('\n候选相关文件 (已排除纯缓存目录):');
for (const p of interesting) console.log('  ' + p);
console.log('\n完整报告: ' + reportPath);
