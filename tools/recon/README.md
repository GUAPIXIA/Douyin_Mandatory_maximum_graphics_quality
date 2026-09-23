# 侦察脚本（recon）

这些是**开发期用来把结论挖出来**的一次性脚本。它们不参与安装/还原流程，
保留在这里是为了让 `versions.json` 和 [CHANGELOG.md](../../CHANGELOG.md) 里的
结论**可复现、可复核** —— 每一条都不是猜的。

> 运行前请先阅读脚本内容。它们只**读**抖音安装目录与用户数据目录。

## 各组脚本干什么

### asar 归档分析

| 脚本 | 用途 |
|---|---|
| `asar-hdrdiff.js` | 对比两个 asar 的 header，定位差异（排查补丁是否只改了目标条目） |
| `asar-measure.js` | 精确测量 header 重新序列化后的长度差 |
| `preload-contract.js` | 从 preload 里提取桥接契约：IPC 通道名、暴露到 window 的全局名、argv 参数 |

### 画质设置定位

| 脚本 | 用途 |
|---|---|
| `search-quality.js` | 在 LevelDB / 存储文件里搜画质相关 token（UTF-8 与 UTF-16LE 双编码） |
| `storage-keys.js` | 列出 Storage LevelDB 里所有像键名的字符串 |
| `decode-keys.js` | 解出 UTF-16BE 存储键（Chromium 把 sessionStorage 写盘时的编码） |
| `swap-strings.js` | 处理字节交换的 UTF-16 文本（不换字节就读不出键名） |
| `list-keys.js` | 枚举候选存储键名 |
| `find-key.js` | 定位某个 token 前后的原始字节结构 |
| `find-player.js` | 找 `player_*` 键族（曾误判出 `player_backratio`，实为 LevelDB 块前缀压缩假象，真名 `player_playbackratio`） |
| `find-player-key.js` | 按 `map-<id>-player_` 前缀定位键名与值 |
| `parse-storage.js` | 粗解析 Storage LevelDB 的键值对 |

### 客户端变更追踪

| 脚本 | 用途 |
|---|---|
| `snapshot-diff.js` | 对比改动前后的 AppData 全量快照，列出新增/删除/修改（用来验证"切 4K 后偏好到底写没写盘"） |
| `analyze-log.ps1` | 解析注入器的运行日志（已被 `tools\check-inject.ps1` 取代，保留作参考） |

### GUI 验证（维护界面时很有用）

| 脚本 | 用途 |
|---|---|
| `verify-gui-window.ps1` | 通过 Win32 `EnumWindows` 找到窗口、抓图、统计颜色数，判断界面是否真的渲染出来（不是空白） |
| `verify-gui-state.ps1` | 通过 UI Automation 读真实控件状态（按钮是否可点、文案内容） |

> 踩过的坑：用 UI Automation 读状态时要**等窗口加载完成**，并且 `FindAll` 返回多个同名
> 窗口时未必取到当前那个 —— 否则会得出"按钮可点"的错误结论。定位窗口请按**进程 ID**。

## 复现结论的入口

想自己复核最重要的几条结论，按这个顺序：

```powershell
# 1) 注入点到底是哪个 preload？——看磁盘日志
pwsh -File ..\check-inject.ps1          # 期望看到 url=https://www.douyin.com/ isolated=false

# 2) 画质偏好存在哪个键？——搜存储
node search-quality.js "$env:APPDATA\douyin\Session Storage" "$env:APPDATA\douyin\Local Storage"

# 3) 切 4K 会不会写盘？——先快照、切档、再对比
node snapshot-diff.js <before.json>
```
