<#
.SYNOPSIS
  分析抖音画质强制器的诊断日志。

.DESCRIPTION
  读取 %APPDATA%\douyin\dy-force.log，按关键事件分类汇总：
    - preload 是否加载、是否成功注入页面
    - 是否发现 MANUAL_SWITCH
    - 是否成功强制到 4K / 2K
    - 页面写入过的画质相关键与原始内容
    - 错误

.PARAMETER LogPath
  日志路径，默认 %APPDATA%\douyin\dy-force.log

.PARAMETER Tail
  只显示最后 N 行原始日志（默认 40）

.EXAMPLE
  pwsh -File D:\Code\dy\tools\analyze-log.ps1
#>
[CmdletBinding()]
param(
  [string]$LogPath = (Join-Path $env:APPDATA 'douyin\dy-force.log'),
  [int]$Tail = 40
)

function Write-Head($t) { Write-Host ''; Write-Host "=== $t ===" -ForegroundColor Cyan }

if (-not (Test-Path $LogPath)) {
  Write-Host "[x] 日志不存在: $LogPath" -ForegroundColor Red
  Write-Host '    说明 preload 可能没有执行，或者还没启动过抖音。' -ForegroundColor DarkGray
  exit 1
}

$lines = Get-Content $LogPath
Write-Host "[i] 日志: $LogPath" -ForegroundColor Gray
Write-Host ("[i] 总行数: {0}   最后写入: {1}" -f $lines.Count, (Get-Item $LogPath).LastWriteTime) -ForegroundColor Gray

Write-Head '1. preload 加载与注入'
$load = $lines | Where-Object { $_ -match 'preload loaded' }
if ($load) { $load | Select-Object -Last 1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Green } }
else { Write-Host '  [!] 没有 preload loaded 记录 —— preload 可能未被执行' -ForegroundColor Red }

$inject = $lines | Where-Object { $_ -match 'inject attempt' }
if ($inject) {
  $inject | Select-Object -Last 3 | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
  if ($inject[-1] -match 'mainWorld=False') {
    Write-Host '  [!] 主世界注入失败（DOM script 未插入），需要改用其它注入通道' -ForegroundColor Yellow
  }
} else {
  Write-Host '  [!] 没有 inject attempt 记录' -ForegroundColor Yellow
}

Write-Head '2. 页面 JS 是否真的跑起来（payload boot）'
$boot = $lines | Where-Object { $_ -match 'payload|injector v|Storage.prototype patched' }
if ($boot) { $boot | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" } }
else { Write-Host '  [!] payload 未运行 —— 页面主世界没有执行我们的代码' -ForegroundColor Red }

Write-Head '3. MANUAL_SWITCH 观测与强制结果'
$ms = $lines | Where-Object { $_ -match 'MANUAL_SWITCH|强制 4K|强制 2K|最高可用|已是 4K' }
if ($ms) {
  $ms | Select-Object -Last 25 | ForEach-Object { Write-Host "  $_" }
  $forced4k = ($lines | Where-Object { $_ -match '强制 4K' }).Count
  $kept = ($lines | Where-Object { $_ -match '已是 4K' }).Count
  $noavail = ($lines | Where-Object { $_ -match '最高可用=' }).Count
  Write-Host ''
  Write-Host ("  统计: 强制4K {0} 次 | 已是4K {1} 次 | 档位不足未强制 {2} 次" -f $forced4k, $kept, $noavail) -ForegroundColor Green
} else {
  Write-Host '  [!] 没有 MANUAL_SWITCH 相关记录' -ForegroundColor Yellow
  Write-Host '      → 说明 payload 没跑，或页面还没写这个键' -ForegroundColor DarkGray
}

Write-Head '4. 页面写入的画质配置（原始内容）'
$setitem = $lines | Where-Object { $_ -match 'SETITEM|clarity seen|GETITEM' }
if ($setitem) { $setitem | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" } }
else { Write-Host '  （无）' }

Write-Head '5. 错误'
$errs = $lines | Where-Object { $_ -match 'fail|error|Error|rejected|threw|fatal' }
if ($errs) { $errs | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } }
else { Write-Host '  （无）' -ForegroundColor Green }

Write-Head "6. 原始日志尾部（最后 $Tail 行）"
$lines | Select-Object -Last $Tail | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
