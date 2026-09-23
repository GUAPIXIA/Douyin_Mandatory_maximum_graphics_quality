'use strict';
/**
 * sync-gui-patcher.js -- embed the canonical patcher into the GUI as base64
 *
 * Why base64: embedding raw JavaScript inside a PowerShell here-string is
 * fragile (any stray quote/backtick or non-ASCII byte can break the PowerShell
 * parser depending on the file encoding). Base64 contains only [A-Za-z0-9+/=],
 * so it cannot interfere with PowerShell parsing at all.
 *
 * The GUI decodes it to disk only when tools\patch-preload.js is unavailable,
 * so the canonical file stays the single source of truth.
 *
 * Usage: node tools/sync-gui-patcher.js
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.join(__dirname, '..');
const canonical = path.join(root, 'tools', 'patch-preload.js');
const gui = path.join(root, 'douyin-quality-gui.ps1');

const BEGIN = '# >>> EMBEDDED-PATCHER-BEGIN (auto-generated, do not edit) >>>';
const END = '# <<< EMBEDDED-PATCHER-END <<<';

if (!fs.existsSync(canonical)) throw new Error('canonical patcher not found: ' + canonical);
if (!fs.existsSync(gui)) throw new Error('GUI script not found: ' + gui);

const src = fs.readFileSync(canonical);
const md5 = crypto.createHash('md5').update(src).digest('hex');
const b64 = src.toString('base64');

let guiText = fs.readFileSync(gui, 'utf8');
const i = guiText.indexOf(BEGIN);
const j = guiText.indexOf(END);
if (i < 0 || j < 0 || j < i) throw new Error('embedded patcher markers not found in the GUI script');

const block = [
  BEGIN,
  '$EmbeddedPatcherB64 = @\'',
  b64,
  '\'@',
  "$EmbeddedPatcherMd5 = '" + md5 + "'",
  END
].join('\n');

guiText = guiText.slice(0, i) + block + guiText.slice(j + END.length);
fs.writeFileSync(gui, guiText, 'utf8');

console.log('[ok] embedded patcher synced into the GUI script');
console.log('[i] canonical bytes: ' + src.length + '   md5: ' + md5 + '   base64 chars: ' + b64.length);
