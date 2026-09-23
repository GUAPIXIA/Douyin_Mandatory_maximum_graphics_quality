<#
.SYNOPSIS
  检查画质强制器是否生效。

.DESCRIPTION
  读取 %APPDATA%\douyin\dy-force.log，汇总：
    - preload 是否在 www.douyin.com 上加载
    - MANUAL_SWITCH 是否被创建/拉高到最高档
    - 是否出现"该视频无 4K，保持页面行为"的降级判断

.EXAMPLE
  pwsh -File D:\Code\dy\tools\check-inject.ps1
#>
[CmdletBinding()]
param(
  [string]$LogPath = (Join-Path $env:APPDATA 'douyin\dy-force.log'),
  [int]$Tail = 25
)

function Write-Head($t) { Write-Host ''; Write-Host "=== $t ===" -ForegroundColor Cyan }

if (-not (Test-Path $LogPath)) {
  Write-Host "[x] 日志不存在: $LogPath" -ForegroundColor Red
  Write-Host '    说明 preload 未加载或尚未启动过抖音。' -ForegroundColor DarkGray
  exit 1
}

$lines = Get-Content $LogPath
Write-Host "[i] 日志: $LogPath" -ForegroundColor Gray
Write-Host ("[i] 行数: {0}   最后写入: {1}" -f $lines.Count, (Get-Item $LogPath).LastWriteTime) -ForegroundColor Gray

Write-Head '1. preload 是否挂到 www.douyin.com'
$onPage = $lines | Where-Object { $_ -match 'loose-preload 已加载 url=https://www\.douyin\.com' }
if ($onPage) {
  $onPage | Select-Object -Last 2 | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
  $iso = ($onPage[-1] -match 'isolated=false')
  Write-Host ("  isolated=false（与页面同上下文）: " + $iso) -ForegroundColor Green
} else {
  Write-Host '  [x] 没有在 www.douyin.com 上加载的记录' -ForegroundColor Red
}

Write-Head '2. MANUAL_SWITCH 处置记录'
foreach ($tag in @('created', 'forced', 'ok\]', 'skip')) {
  $hits = $lines | Where-Object { $_ -match "\[$tag" }
  Write-Host ("  [{0}] {1} 次" -f ($tag -replace '\\\]', ''), $hits.Count) -ForegroundColor Gray
}
Write-Host ''
$lines | Where-Object { $_ -match '\[created\]|\[forced\]|\[skip\]' } | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }

Write-Head '3. 异常'
$errs = $lines | Where-Object { $_ -match '异常|错误|失败|error|Error' }
if ($errs) { $errs | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } }
else { Write-Host '  （无）' -ForegroundColor Green }

Write-Head "4. 日志尾部（最后 $Tail 行）"
$lines | Select-Object -Last $Tail | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
