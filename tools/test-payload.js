'use strict';
/**
 * payload.js 单测（v0.3）：验证 MANUAL_SWITCH 的创建/拉高/降级逻辑。
 * 用法: node test-payload.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const src = fs.readFileSync(path.join(__dirname, '..', 'injector', 'payload.js'), 'utf8');
const logs = [];
const data = new Map();
const listeners = {};

function Storage() { }
Storage.prototype.getItem = function (k) { return this.__d.has(k) ? this.__d.get(k) : null; };
Storage.prototype.setItem = function (k, v) { this.__d.set(k, String(v)); };
Storage.prototype.removeItem = function (k) { this.__d.delete(k); };

const sandbox = {
  console: { log: (...a) => logs.push(a.join(' ')) },
  document: {
    readyState: 'loading',
    addEventListener: (t, f) => { listeners[t] = f; },
  },
  setInterval: (f) => { sandbox.__tick = f; return 0; },
  clearInterval: () => { },
  setTimeout, clearTimeout, JSON, Date, Array, Object, String, Number, parseInt, isNaN, RegExp, Error,
};
sandbox.window = sandbox;
sandbox.self = sandbox;
sandbox.location = { href: 'https://www.douyin.com/' };
sandbox.sessionStorage = Object.create(Storage.prototype);
sandbox.sessionStorage.__d = data;

const ctx = vm.createContext(sandbox);
vm.runInContext(src, ctx, { filename: 'payload.js' });

let pass = true;
function check(name, cond, extra) {
  console.log((cond ? 'PASS  ' : 'FAIL  ') + name + (cond || extra === undefined ? '' : '  <' + extra + '>'));
  if (!cond) pass = false;
}
const j = (o) => JSON.stringify(o);
const get = () => JSON.parse(data.get('MANUAL_SWITCH'));
const tick = () => sandbox.__tick && sandbox.__tick();
const now = () => sandbox.__dyForceNow && sandbox.__dyForceNow();

// --- 用例 1：键不存在 -> 应主动创建为 4K ---
sandbox.__dyForceNow(); // 触发一次
let v = get();
check('键不存在时主动创建', !!v);
check('创建为 4K gearType=-2', v.gearType === -2, String(v.gearType));
check('创建为 gearClarity=20', v.gearClarity === '20', v.gearClarity);
check('创建为 gearName=超清 4K', v.gearName === '超清 4K', v.gearName);
check('done=1', v.done === 1, String(v.done));

// --- 用例 2：被重置为智能 -> 应拉回 4K ---
data.set('MANUAL_SWITCH', j({ gearType: 0, gearClarity: '0', gearName: '', qualityType: 0, done: 1 }));
now();
v = get();
check('智能被拉回 4K', v.gearType === -2, String(v.gearType));

// --- 用例 3：已是 4K -> 不动 ---
data.set('MANUAL_SWITCH', j({ gearType: -2, gearClarity: '20', gearName: '超清 4K', qualityType: 20, done: 1, clarityReal: ['adapt_lowest_4_1'] }));
const before = data.get('MANUAL_SWITCH');
now();
check('已是 4K 不重复写入', data.get('MANUAL_SWITCH') === before);

// --- 用例 4：clarityReal 表明只有 1080P -> 不干预 ---
data.set('MANUAL_SWITCH', j({ gearType: 0, gearClarity: '0', gearName: '', qualityType: 0, done: 1, clarityReal: ['normal_1080_0', 'normal_720_0', 'low_540_0'] }));
now();
v = get();
check('1080P-only 不硬塞 4K', v.gearType === 0, String(v.gearType));

// --- 用例 5：clarityReal 只有 1440 -> 拉到 2K ---
data.set('MANUAL_SWITCH', j({ gearType: 0, gearClarity: '0', gearName: '', qualityType: 0, done: 1, clarityReal: ['normal_1080_0', 'adapt_lowest_1440_1'] }));
now();
v = get();
check('2K-only 拉到 2K', v.gearType === -1, String(v.gearType));

// --- 用例 6：clarityReal 有 4K -> 拉 4K ---
data.set('MANUAL_SWITCH', j({ gearType: 5, gearClarity: '5', gearName: '高清 1080P', qualityType: 1, done: 1, clarityReal: ['normal_1080_0', 'adapt_lowest_4_1'] }));
now();
v = get();
check('有 4K 时拉 4K', v.gearType === -2, String(v.gearType));

// --- 用例 8：clarityReal 含 HDR 4K 档 -> 应使用 HDR 档 ---
data.set('MANUAL_SWITCH', j({ gearType: 0, gearClarity: '0', gearName: '', qualityType: 0, done: 1, clarityReal: ['normal_1080_0', 'adapt_lowest_hdr_4_1'] }));
now();
v = get();
check('有 HDR 档时用 gearType=-3', v.gearType === -3, String(v.gearType));
check('有 HDR 档时用 gearClarity=30', v.gearClarity === '30', v.gearClarity);

// --- 用例 9：普通 4K 档（无 HDR）-> 用非 HDR 4K，避免旧版常量表不认识 -3 ---
data.set('MANUAL_SWITCH', j({ gearType: 0, gearClarity: '0', gearName: '', qualityType: 0, done: 1, clarityReal: ['normal_1080_0', 'adapt_lowest_4_1'] }));
now();
v = get();
check('普通 4K 用 gearType=-2', v.gearType === -2, String(v.gearType));

// --- 用例 10：损坏数据不抛 ---
data.set('MANUAL_SWITCH', '{"broken');
let threw = false;
try { now(); } catch (e) { threw = true; }
check('损坏数据不抛异常', !threw);

console.log('\n--- 日志 ---');
logs.slice(0, 12).forEach(l => console.log('  ' + l));
console.log('\n结果: ' + (pass ? '全部通过' : '存在失败'));
process.exit(pass ? 0 : 1);
