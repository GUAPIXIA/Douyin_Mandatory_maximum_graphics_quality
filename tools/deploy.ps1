<#
.SYNOPSIS
  部署抖音画质强制器。

.DESCRIPTION
  注入点（已实测确认）：
    真正给 https://www.douyin.com 挂 preload 的是【asar 外的 loose 文件】：
      <版本目录>\resources\app.asar.unpacked\preload.js   （41,345 字节，isolated=false）
    而不是 asar 内的 @annie/electron/resources/preload.js（那个对页面不生效）。
  因此本脚本只改这一个文件，并先把原始文件固化备份。

  改动范围：仅 resources\app.asar.unpacked\preload.js
  备份位置：D:\Code\dy\backup\loose-preload\preload.js.orig（md5 与安装目录 md5.json 一致）

.PARAMETER DouyinDir
  抖音安装目录，默认 D:\douyin

.PARAMETER Force
  跳过"抖音正在运行"的检查

.EXAMPLE
  pwsh -File D:\Code\dy\tools\deploy.ps1
#>
[CmdletBinding()]
param(
  [string]$DouyinDir = 'D:\douyin',
  [string]$ProjectDir = 'D:\Code\dy',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Hashing via .NET only: Windows PowerShell 5.1 (which a .bat launcher starts)
# does not ship Get-FileHash, while PowerShell 7 does. Do not depend on it.
# ---------------------------------------------------------------------------
function Get-HashHex([string]$path, [string]$algo) {
  $fs = $null
  try {
    $fs = [System.IO.File]::OpenRead($path)
    $h = [System.Security.Cryptography.HashAlgorithm]::Create($algo)
    return [System.BitConverter]::ToString($h.ComputeHash($fs)).Replace('-', '').ToLower()
  } finally {
    if ($fs) { $fs.Dispose() }
  }
}
function Get-Md5([string]$p) {
  if (-not (Test-Path $p)) { return '' }
  return (Get-HashHex $p 'MD5')
}
function Get-Sha([string]$p) {
  if (-not (Test-Path $p)) { return '' }
  return (Get-HashHex $p 'SHA256').ToUpper()
}

function Write-Step($msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[x] $msg" -ForegroundColor Red }

$ORIG_MD5 = 'bfcb8e31fae5a7370c5bee258ffcdfad'   # 官方 preload.js 的 md5（来自安装目录 md5.json）

# ---------------------------------------------------------------------------
# 0) 定位目标文件
# ---------------------------------------------------------------------------
Write-Step '定位安装目录与目标文件'

$launcherCfg = Join-Path $DouyinDir 'launcher_config.json'
if (-not (Test-Path $launcherCfg)) { throw "找不到 launcher_config.json: $launcherCfg" }
$cfg = Get-Content $launcherCfg -Raw | ConvertFrom-Json
$curPath = $cfg.cur_path
if (-not $curPath) { throw 'launcher_config.json 里没有 cur_path' }

$versionDir = Join-Path $DouyinDir $curPath
$targetPreload = Join-Path $versionDir 'resources\app.asar.unpacked\preload.js'
if (-not (Test-Path $targetPreload)) { throw "找不到目标 preload: $targetPreload" }

Write-Ok "版本目录: $versionDir"
Write-Ok "目标文件: $targetPreload"
Write-Ok ("当前大小: {0:N0} 字节" -f (Get-Item $targetPreload).Length)

# ---------------------------------------------------------------------------
# 1) 进程检查
# ---------------------------------------------------------------------------
Write-Step '检查抖音进程'
$procs = Get-Process -Name douyin, douyin_guard, parfait_crash_handler -ErrorAction SilentlyContinue
if ($procs -and -not $Force) {
  Write-Err ('抖音正在运行，请先完全退出：' + ($procs.ProcessName -join ', '))
  Write-Host '    （托盘"退出"，并确认任务管理器里 douyin.exe / douyin_guard.exe 都结束）' -ForegroundColor DarkGray
  exit 1
}
Write-Ok '没有检测到运行中的抖音进程'

# ---------------------------------------------------------------------------
# 2) 备份原始文件（固化，永不覆盖）
# ---------------------------------------------------------------------------
Write-Step '检查原始备份'
$backupDir = Join-Path $ProjectDir 'backup\loose-preload'
$pristine = Join-Path $backupDir 'preload.js.orig'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$pristineOk = $false
if (Test-Path $pristine) {
  $m = (Get-HashHex $pristine 'MD5')
  if ($m -eq $ORIG_MD5) { $pristineOk = $true; Write-Ok "已有原始备份（md5 校验通过）: $pristine" }
  else { Write-Warn2 "已有备份 md5 不符（$m），将重新固化"; Remove-Item $pristine -Force }
}

if (-not $pristineOk) {
  $curMd5 = (Get-HashHex $targetPreload 'MD5')
  if ($curMd5 -eq $ORIG_MD5) {
    Copy-Item $targetPreload $pristine -Force
    $pristineOk = $true
    Write-Ok "已固化原始备份: $pristine"
  } else {
    throw "当前 preload 已被修改过（md5=$curMd5，官方应为 $ORIG_MD5），且找不到原始备份。请先重装抖音客户端。"
  }
}

# ---------------------------------------------------------------------------
# 3) 生成注入后的 preload
# ---------------------------------------------------------------------------
Write-Step '生成注入版 preload'
$payload = Join-Path $ProjectDir 'injector\payload.js'
if (-not (Test-Path $payload)) { throw "缺少 payload: $payload" }

& node --check $payload
if ($LASTEXITCODE -ne 0) { throw 'payload.js 语法检查失败' }
Write-Ok 'payload.js 语法通过'

$buildDir = Join-Path $ProjectDir 'work\build'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$built = Join-Path $buildDir 'loose-preload.patched.js'

& node (Join-Path $ProjectDir 'tools\patch-preload.js') --src $pristine --payload $payload --out $built
if ($LASTEXITCODE -ne 0) { throw '注入失败' }

& node --check $built
if ($LASTEXITCODE -ne 0) { throw '注入后语法检查失败' }
Write-Ok ("注入后大小: {0:N0} 字节（语法通过）" -f (Get-Item $built).Length)

# ---------------------------------------------------------------------------
# 4) 部署
# ---------------------------------------------------------------------------
Write-Step '部署到安装目录'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$snapshotDir = Join-Path $ProjectDir "backup\$stamp"
New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null
Copy-Item $targetPreload (Join-Path $snapshotDir 'preload.js.before') -Force

Copy-Item $built $targetPreload -Force
$newMd5 = (Get-HashHex $targetPreload 'MD5')
Write-Ok "已写入: $targetPreload"
Write-Ok "新 md5: $newMd5"

$meta = [ordered]@{
  timestamp    = (Get-Date).ToString('o')
  versionDir   = $versionDir
  targetFile   = $targetPreload
  origMd5      = $ORIG_MD5
  newMd5       = $newMd5
  pristinePath = $pristine
  payloadFile  = $payload
}
$meta | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $ProjectDir 'backup\deploy-meta.json') -Encoding UTF8
Set-Content (Join-Path $ProjectDir 'backup\LATEST') $stamp -Encoding UTF8

# 清空旧日志
$pageLog = Join-Path $env:APPDATA 'douyin\dy-force.log'
if (Test-Path $pageLog) { Remove-Item $pageLog -Force }
$mainLog = Join-Path $env:APPDATA 'douyin\dy-force-main.log'
if (Test-Path $mainLog) { Remove-Item $mainLog -Force }
Write-Ok '已清空旧日志'

Write-Host ''
Write-Ok '部署完成'
Write-Host '  启动抖音、打开几个视频后，用下面命令查看是否生效：' -ForegroundColor Gray
Write-Host "    pwsh -File $ProjectDir\tools\check-inject.ps1" -ForegroundColor Gray
Write-Host '  一键还原：' -ForegroundColor Gray
Write-Host "    pwsh -File $ProjectDir\tools\restore.ps1" -ForegroundColor Gray

