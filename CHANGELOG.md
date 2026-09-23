# 更新日志

本项目版本号规则：`主版本.次版本.修订号`
- **主版本**：注入方式或兼容性策略发生不兼容变化
- **次版本**：新增功能（GUI、版本检查等）
- **修订号**：修 bug、调整文案

工具版本号记录在 [versions.json](versions.json) 的 `tool.version`，界面与 `-Action version` 都会显示。

---

## [1.0.0] - 2026-09-23

首个可用版本。核心能力：**让抖音 PC 版每个视频都按该视频可用的最高清晰度播放（4K → 2K → 1080P）**。

### 逆向结论（方案的基础，全部实测）

| 结论 | 依据 |
|---|---|
| 抖音 PC 版 = Electron 外壳 + 内嵌 `www.douyin.com` 网页播放器 | 内嵌网页 + 本地预载包 |
| 清晰度偏好存在网页 **sessionStorage 的 `MANUAL_SWITCH`**，不在 localStorage/cookie/IndexedDB | 实测落盘值 + 网页 bundle 里的读写函数 |
| 该偏好**重启即丢**，所以必须每次开页强制 | 用户实测：重启后回到智能 |
| 真正挂到 `www.douyin.com` 的 preload 是 **asar 之外**的 `resources\app.asar.unpacked\preload.js`，且 `isolated=false` | 注入磁盘日志：`[boot] loose-preload loaded url=https://www.douyin.com/ isolated=false` |
| 档位表 | `gearClarity` `'30'`/`'20'`/`'10'`/`'5'`/`'4'`/`'3'`/`'2'`/`'0'`，对应 `gearType` `-3`/`-2`/`-1`/`1`/`2`/`3`/`4`/`0` |
| "智能"卡在 1080P 的原因 | AB 配置 `bitrate_selector.white_list` 最高档即 `normal_1080_0` / `adapt_lowest_1080_1` |
| 页面自身会按视频实际档位优雅降级 | 请求 4K 但视频无 4K 时，页面把 `gearType` 20 →（有 1440 则 10，否则 1） |

### 新增

- **图形界面** `douyin-quality-gui.ps1` + `gui.xaml`，双击 `启动画质助手.bat` 即可用
  - 三步流程：选抖音程序 → 一键启用 → 启动抖音看视频 → 检查生效
  - **必须由用户亲自选择 `douyin.exe`**：未选择时路径框显示「尚未选择」、三个功能按钮全部禁用
  - 选择器容错：选 `douyin.exe`、版本子目录、安装根目录都能识别；无关文件会被拒绝
  - 实时状态：抖音版本/补丁状态/程序主体哈希/原始备份/抖音是否在运行
- **命令行工具** `douyin-quality.ps1`，菜单 + 参数双模式
  - `-Action status | install | restore | check | test | version`
- **版本兼容性管理** `versions.json` + `tools/douyin-version.ps1`
  - 用官方文件哈希做版本指纹；`app.asar` 从不修改，可随时与安装目录 `md5.json` 对账
  - 三种判定：`verified`（实测通过）/ `compatible`（结构兼容）/ `unknown`（未验证的新版，警告但允许）/ `unsupported`（拒绝）
  - `-Action version` 查看结论；`tools/record-version.ps1` 实测通过后一键登记新版本
- **一键还原** `tools/restore.ps1`、GUI 的「② 还原官方原版」
  - 以固化备份 `backup/loose-preload/preload.js.orig` 为准（md5 与安装目录 `md5.json` 一致，可自证是原版）
  - 附带清理早期版本可能在 `app.asar` 留下的改动
- **诊断日志** 写到 `%APPDATA%\douyin\dy-force.log`，`-Action check` 与 GUI「③」可解读

### 修复（开发过程中踩到并解决的真实问题）

| 问题 | 原因 | 处理 |
|---|---|---|
| 注入到 `app.asar` 里的 preload 完全无效 | 那个 preload 不挂到 `www.douyin.com` | 改注入 asar 之外的 loose preload |
| `NODE_OPTIONS=--require` 主进程注入失败 | 该 Electron fuse 虽标注开启，但实机无任何反应 | 放弃该路线，相关代码已移除 |
| `NODE_OPTIONS` 方案会触发 md5 校验风险 | `md5.json` 收录 1093 项且 guard 会做 md5 比对 | 改走"只动 1 个文件、且可一键还原"的低暴露方案 |
| `.bat` 报 `'NoProfile' 不是内部或外部命令` | ① 换行是 LF（cmd 会解析错乱）② `"%~dp0x.ps1"` 中 `%~dp0` 以反斜杠结尾，cmd 里 `\"` 不是转义 | 改 CRLF + `cd /d "%~dp0"` + 相对文件名 |
| 双击 bat 崩溃：`Get-FileHash` 找不到 | `cmd → powershell` 起的是 **Windows PowerShell 5.1**，它没有 `Get-FileHash`（PowerShell 7 有） | 全部哈希计算改为纯 .NET，5.1/7 都能跑且结果一致 |
| `.ps1` 里中文导致解析错误 | 5.1 在编码被重新解释时会把字符串引号搞乱 | `.ps1` 内字面量保持纯 ASCII，中文只放 `gui.xaml` |
| GUI 与 CLI 装出的文件字节不同 | 两个入口各有一份注入实现 | 统一为 `tools/patch-preload.js` 唯一权威；GUI 用 base64 内嵌副本并由 `tools/sync-gui-patcher.js` 同步，实测两边 sha256 一致 |
| 注入器对自己的钩子读值，判断失效 | `forceManualSwitch` 走 `sessionStorage.getItem` 读到自己伪造的"假 4K" | 强制逻辑改用保存的原始 `getItem/setItem` |
| 对 1080P-only 视频硬写 4K | 无脑覆盖档位 | 改为读 `clarityReal`（该视频真实可用档位）后决定，并信任页面自身的降级 |
| 沙箱帧刷屏 `SecurityError` | `about:blank` 等文档不允许访问 `sessionStorage`，每秒重试 | 一次性永久跳过该类文档 |
| 日志爆炸（155 行/分钟） | 正常状态也写日志 | 只在"创建/拉高/降级"时记录 |
| 二次部署把已打补丁的文件当成原始备份 | 备份逻辑未校验内容 | 增加指纹校验 + 固化 `backup/app.asar.orig`，并在还原时自动清理 |

### 已知限制

- 只影响**点播（短视频）**清晰度；直播是另一套机制（`webcast_local_quality`，localStorage）
- 4K 档通常**需要登录**抖音账号
- `resources\app.asar.unpacked\preload.js` 在安装目录 `md5.json` 的清单内，属于唯一暴露面：
  多次启动未被拦截，但若风控升级可能被检测；随时可用「② 还原」消除
- 抖音整体更新会覆盖该文件，更新后需重新运行一次「① 一键启用最高画质」

### 实测环境

- Windows 11
- 抖音 PC 版 **8.7.0**（buildId 495279540，Electron 36.4.0-rs.33.release.pgo.0，md5.json 1093 项）→ 状态 `verified`
- 工具同时兼容 Windows PowerShell 5.1 与 PowerShell 7.6

---

## 后续版本规划

- [ ] 直播清晰度（`webcast_local_quality`）
- [ ] 可选策略：只锁 1080P 高码率（`normal_1080_0`）而不吃 4K 带宽
- [ ] 界面内直接显示/切换"当前实际生效档位"
- [ ] 抖音更新后自动提示并引导重新启用
