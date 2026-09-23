'use strict';
// 从原始 preload 中提取桥接契约：IPC 通道名、暴露到 window 的全局名、IPC 调用
const fs = require('fs');
const s = fs.readFileSync(process.argv[2], 'utf8');

const grab = (re) => [...new Set([...s.matchAll(re)].map(m => m[1]))];

console.log('IPC CONSTS  :', JSON.stringify(grab(/"([A-Z][A-Z0-9_]{4,})"/g).filter(x => /BRIDGE|MAIN_CALL|CANS|EVENTCENTER|LYNX_VIEW|WEBVIEW_GET|JS_BRIDGE/.test(x))));
console.log('EXPOSED     :', JSON.stringify(grab(/exposeToWindow\("([^"]+)"/g)));
console.log('IPC CALLS   :', JSON.stringify(grab(/ipcRenderer\.(?:send|sendSync|invoke)\("([^"]+)"/g)));
console.log('has electron:', /require\("electron"\)/.test(s));
console.log('has webFrame:', s.indexOf('webFrame') >= 0);
console.log('has contextIsolated:', s.indexOf('contextIsolated') >= 0);
// 找出 process.argv 解析项
console.log('ARGV KEYS   :', JSON.stringify(grab(/startsWith\("(--[a-zA-Z-]+=)"/g)));
// 找出 window 上挂的所有 __ 名字
console.log('WINDOW NAMES:', JSON.stringify(grab(/exposeToWindow\)\("([^"]+)"/g)));
