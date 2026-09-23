#!/usr/bin/env node
/**
 * patch-preload.js -- inject the quality enforcer payload into Douyin's loose preload.js
 *
 * This is the SINGLE SOURCE OF TRUTH for the injection:
 *   - the CLI toolchain (tools\deploy.ps1 / douyin-quality.ps1) calls this file
 *   - the GUI (douyin-quality-gui.ps1) embeds a copy of it, kept in sync by
 *     tools\sync-gui-patcher.js, and prefers this file when it exists
 * Both paths must produce identical bytes, otherwise installing via a different
 * entry point would yield a different file.
 *
 * Usage:
 *   node patch-preload.js --src <pristine preload.js> --payload <payload.js> --out <out.js>
 *
 * Notes:
 *   - The injected block is wrapped in BEGIN/END markers so it can be stripped
 *     again (the GUI uses that to recover the original file by itself).
 *   - The injected code is fully wrapped in try/catch; it never throws outward.
 *   - It writes a disk log (%APPDATA%\douyin\dy-force.log) used to verify that
 *     the preload is actually loaded.
 *   - The block is inserted before the sourceMappingURL comment so that comment
 *     stays last.
 *
 * ASCII ONLY: every string literal in this file must stay ASCII. It gets
 * embedded into a PowerShell here-string, and non-ASCII text there breaks the
 * PowerShell parser when the file encoding is re-interpreted.
 */
'use strict';

const fs = require('fs');

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) { out[a.slice(2)] = argv[++i]; }
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
if (!args.src || !args.payload || !args.out) {
  console.error('usage: node patch-preload.js --src <preload.js> --payload <payload.js> --out <out.js>');
  process.exit(2);
}

const MARK_BEGIN = '/* ==== DY_FORCE_INJECTOR_BEGIN ==== */';
const MARK_END = '/* ==== DY_FORCE_INJECTOR_END ==== */';

const original = fs.readFileSync(args.src, 'utf8');
const payload = fs.readFileSync(args.payload, 'utf8');

if (original.indexOf(MARK_BEGIN) >= 0) {
  console.error('[x] source file is already patched; use the pristine original');
  process.exit(1);
}

const NL = String.fromCharCode(10);
const Q = String.fromCharCode(39);   // single quote
const BS = String.fromCharCode(92);  // backslash

// ASCII-only wrapper: installs the log sink the payload expects, then runs the
// payload verbatim.
const wrapper = [
  ';(function () {',
  '  ' + Q + 'use strict' + Q + ';',
  '  var fs = null, path = null, logFile = ' + Q + Q + ';',
  '  function wal(line) {',
  '    try {',
  '      if (!fs) { fs = require(' + Q + 'fs' + Q + '); path = require(' + Q + 'path' + Q + '); }',
  '      if (!logFile) {',
  '        var b = process.env.APPDATA || process.cwd();',
  '        logFile = path.join(b, ' + Q + 'douyin' + Q + ', ' + Q + 'dy-force.log' + Q + ');',
  '      }',
  '      fs.appendFileSync(logFile, new Date().toISOString() + ' + Q + ' ' + Q + ' + line + ' + Q + BS + 'n' + Q + ');',
  '    } catch (e) { /* logging must never break anything */ }',
  '  }',
  '  try {',
  '    wal(' + Q + '[boot] loose-preload loaded url=' + Q + ' + (typeof location !== ' + Q + 'undefined' + Q + ' ? location.href : ' + Q + 'n/a' + Q + ') + ' + Q + ' isolated=' + Q + ' + process.contextIsolated);',
  '  } catch (e) {}',
  '  try { if (typeof window !== ' + Q + 'undefined' + Q + ') { window.__dyForceLog = wal; } } catch (e) {}',
  '  try {',
  payload,
  '    wal(' + Q + '[boot] payload done' + Q + ');',
  '  } catch (e) {',
  '    wal(' + Q + '[boot] payload error: ' + Q + ' + (e && e.stack ? e.stack : e));',
  '  }',
  '})();'
].join(NL);

// The block must round-trip EXACTLY: stripping must restore the original byte
// for byte. So the injected block owns both the newline before MARK_BEGIN and
// the newline after MARK_END, and the strip side removes [i, end) where end is
// the offset just past that trailing newline.
const injection = NL + MARK_BEGIN + NL + wrapper + NL + MARK_END + NL;

// Keep the sourceMappingURL comment last
const mapIdx = original.lastIndexOf('//# sourceMappingURL');
const patched = mapIdx >= 0
  ? original.slice(0, mapIdx) + injection + original.slice(mapIdx)
  : original + injection;

fs.writeFileSync(args.out, patched, 'utf8');

console.log('[ok] wrote ' + args.out);
console.log('[i] ' + Buffer.byteLength(original) + ' bytes -> ' + Buffer.byteLength(patched) + ' bytes');
