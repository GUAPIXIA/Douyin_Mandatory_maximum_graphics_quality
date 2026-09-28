/* ============================================================================
 * 抖音 PC 版 —— 视频画质强制器（由 loose preload 注入 www.douyin.com 页面）
 *
 * 实测前提（已用日志验证）：
 *   - 该 preload 在 https://www.douyin.com/ 上以 isolated=false 运行，
 *     与页面同一个 JS 上下文，可直接读写页面 sessionStorage。
 *
 * 原理（来自对网页 bundle 的逆向）：
 *   播放器每次构建播放配置时读 sessionStorage 的 MANUAL_SWITCH，
 *   取其中的 gearType 作为 config.shared.definition.userSelectDefinition。
 *   键值格式（与清晰度菜单点选后写入的完全一致）：
 *     { gearType:-2, gearClarity:'20', gearName:'超清 4K', qualityType:20, done:1 }
 *   档位表（gearClarity / gearType / 显示名）：
 *     '30' / -3 / 超清4K HDR   ← 最高（仅当前 HDR 版常量表有；需视频提供 HDR 档）
 *     '20' / -2 / 超清 4K
 *     '10' / -1 / 超清 2K
 *     '5'  /  1 / 高清 1080P
 *     '4'  /  2 / 高清 720P
 *     '3'  /  3 / 标清 540P
 *     '2'  /  4 / 极速
 *     '0'  /  0 / 智能
 *
 *   页面自身会优雅降级：请求 4K 但该视频没有 4K 时，
 *   会把 gearType 20 重写成（有 1440 则 10，否则 1）。
 *   因此对不支持 4K 的视频写 4K 是安全的，不会导致播放失败。
 *
 * 策略：优先 4K（若该视频确有 HDR 4K 档则用 HDR 4K），由页面自动降到 2K / 1080P。
 * ==========================================================================*/
(function () {
  'use strict';

  var TAG = '[dy-force]';
  var VERSION = '0.4.0';
  var KEY = 'MANUAL_SWITCH';

  // 4K 档（页面对不可用档位会自动降级）
  var PICK_4K = { gearType: -2, gearClarity: '20', gearName: '超清 4K', qualityType: 20, done: 1 };
  // HDR 4K 档（仅在能确认该视频提供 HDR 档时使用，避免旧版常量表不认识 -3）
  var PICK_4K_HDR = { gearType: -3, gearClarity: '30', gearName: '超清4K HDR', qualityType: 20, done: 1 };
  // 2K 档（仅在明确知道该视频没有 4K 时使用）
  var PICK_2K = { gearType: -1, gearClarity: '10', gearName: '超清 2K', qualityType: 10, done: 1 };

  function emit(line) {
    try {
      if (window.__dyForceLog) window.__dyForceLog(TAG + ' ' + line);
      else console.log(TAG + ' ' + line);
    } catch (e) { }
  }

  function safe(v) {
    try { return typeof v === 'string' ? v.slice(0, 400) : JSON.stringify(v); } catch (e) { return String(v); }
  }

  // ---------------------------------------------------------------------------
  // 档位判定
  // ---------------------------------------------------------------------------
  function gearTypeOf(obj) {
    if (!obj) return null;
    var t = Number(obj.gearType);
    return isNaN(t) ? null : t;
  }

  // 已知的"已达最高档"集合：HDR4K(-3) 与 4K(-2) 都算
  function isTop(gt) { return gt === -2 || gt === -3; }

  // clarityReal 是该视频【实际可用】的档位 id 列表，用来预判该写几档
  function resOfGearId(id) {
    var s = String(id || '');
    if (/adapt_(lowest|lower)_hdr_4_1/.test(s)) return 2160;
    if (/adapt_(lowest|lower)_4_1/.test(s)) return 2160;
    if (/adapt_(lowest|lower)_1440_1/.test(s)) return 1440;
    var m = s.match(/_(\d{3,4})_/);
    if (m) {
      var n = parseInt(m[1], 10);
      if (n >= 240 && n <= 4320) return n;
    }
    return 0;
  }

  // 该视频是否提供 HDR 4K 档（决定能不能用 gearClarity '30'）
  function hasHdr4k(obj) {
    var arr = obj && obj.clarityReal;
    if (Object.prototype.toString.call(arr) !== '[object Array]') return false;
    for (var i = 0; i < arr.length; i++) {
      if (/adapt_(lowest|lower)_hdr_4_1/.test(String(arr[i]))) return true;
    }
    return false;
  }

  function bestAvailable(obj) {
    var top = 0;
    var arr = obj && obj.clarityReal;
    if (Object.prototype.toString.call(arr) === '[object Array]') {
      for (var i = 0; i < arr.length; i++) {
        var r = resOfGearId(arr[i]);
        if (r > top) top = r;
      }
    }
    return top;
  }

  // ---------------------------------------------------------------------------
  // 核心：确保 MANUAL_SWITCH 处于最高档
  // ---------------------------------------------------------------------------
  var lastLogged = '';

  function ensureTop(where) {
    try {
      if (storageBlocked) return;
      var ss = window.sessionStorage;
      if (!ss) return;

      var raw = ss.getItem(KEY);
      var obj = null;
      if (raw) { try { obj = JSON.parse(raw); } catch (e) { obj = null; } }

      // 情况一：键不存在 —— 主动创建（这是首次运行能生效的关键）
      if (!obj || typeof obj !== 'object') {
        ss.setItem(KEY, JSON.stringify(PICK_4K));
        logOnce('created', '键不存在，已创建为 4K 档 @' + where);
        return;
      }

      var gt = gearTypeOf(obj);
      if (isTop(gt)) {
        // 正常状态不刷日志，避免日志爆炸
        return;
      }

      // 情况二：该视频明显没有 4K（clarityReal 有内容且最高只到 1440/1080）
      var avail = bestAvailable(obj);
      var pick = hasHdr4k(obj) ? PICK_4K_HDR : PICK_4K;
      if (avail && avail < 2160) {
        if (avail >= 1440) pick = PICK_2K;
        else {
          logOnce('skip', '该视频最高仅 ' + avail + 'p，保持页面自身行为（gearType=' + gt + '）@' + where);
          return;
        }
      }

      // 情况三：是"智能"/较低档 —— 拉高
      obj.gearType = pick.gearType;
      obj.gearClarity = pick.gearClarity;
      obj.gearName = pick.gearName;
      obj.qualityType = pick.qualityType;
      obj.done = 1;
      ss.setItem(KEY, JSON.stringify(obj));
      logOnce('forced', '拉高到 ' + pick.gearName + ' (gearType=' + pick.gearType + ')，原 gearType=' + gt
        + ' avail=' + avail + ' @' + where);
    } catch (e) {
      handleError(e, where);
    }
  }

  // 沙箱帧 / about:blank 上访问 sessionStorage 会抛 SecurityError，
  // 这类文档永久跳过，避免每秒刷屏。
  var storageBlocked = false;
  var errLogged = '';

  function handleError(e, where) {
    var msg = String(e);
    if (msg.indexOf('SecurityError') >= 0 || msg.indexOf('Access is denied') >= 0) {
      storageBlocked = true;
      // 每个文档只报一次
      if (errLogged !== 'blocked') {
        errLogged = 'blocked';
        emit('该文档不允许访问 sessionStorage，已跳过（url=' + safe(location.href) + '）');
      }
      return;
    }
    if (errLogged !== msg) {
      errLogged = msg;
      emit('ensureTop 异常 @' + where + ': ' + msg);
    }
  }

  // 同样的状态不重复刷日志，避免日志爆炸
  function logOnce(tag, msg) {
    if (lastLogged === tag + msg) return;
    lastLogged = tag + msg;
    emit('[' + tag + '] ' + msg);
  }

  // ---------------------------------------------------------------------------
  // 启动：preload 执行时尽早写入，之后持续看护（页面可能把智能重置回去）
  // ---------------------------------------------------------------------------
  function boot() {
    emit('injector v' + VERSION + ' 启动 readyState=' + document.readyState
      + ' url=' + location.href);

    // 立刻写一次（越早越好：播放器构建配置前就位）
    ensureTop('boot');

    // 页面后续可能重置成"智能"，前 3 分钟每秒看护
    var n = 0;
    var timer = setInterval(function () {
      n++;
      try { ensureTop('tick' + n); } catch (e) { }
      if (n >= 180) clearInterval(timer);
    }, 1000);

    // 页面切换视频/从后台恢复时也复查
    try {
      document.addEventListener('visibilitychange', function () { ensureTop('visibilitychange'); });
      window.addEventListener('focus', function () { ensureTop('focus'); });
    } catch (e) { }
  }

  try {
    if (document.readyState === 'loading') {
      // preload 早于 DOMContentLoaded：先立即跑一次，DOM 就绪后再跑
      ensureTop('early');
      document.addEventListener('DOMContentLoaded', boot, { once: true });
    } else {
      boot();
    }
  } catch (e) {
    emit('启动失败: ' + e);
  }

  // 供人工/诊断调用
  try {
    window.__dyForceInfo = { version: VERSION, key: KEY, pick: PICK_4K };
    window.__dyForceNow = function () { ensureTop('manual'); return window.sessionStorage.getItem(KEY); };
  } catch (e) { }
})();
