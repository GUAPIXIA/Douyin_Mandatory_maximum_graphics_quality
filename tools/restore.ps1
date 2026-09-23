<#
.SYNOPSIS
  还原抖音画质强制器的全部改动。

.DESCRIPTION
  把 resources\app.asar.unpacked\preload.js 还原为官方版本
  （以固化的 backup\loose-preload\preload.js.orig 为准，md5 必须等于官方值），
  并清理日志。

.EXAMPLE
  pwsh -File D:\Code\dy\tools\restore.ps1
#>
[CmdletBinding()]
param(
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

function Write-Step($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Write-Err($m)  { Write-Host "[x] $m" -ForegroundColor Red }

$ORIG_MD5 = 'bfcb8e31fae5a7370c5bee258ffcdfad'

$metaFile = Join-Path $ProjectDir 'backup\deploy-meta.json'
if (-not (Test-Path $metaFile)) { throw "找不到部署元数据: $metaFile（可能从未部署过）" }
$meta = Get-Content $metaFile -Raw | ConvertFrom-Json

$target = $meta.targetFile
$pristine = Join-Path $ProjectDir 'backup\loose-preload\preload.js.orig'

if (-not (Test-Path $target)) { throw "目标文件不存在: $target" }
if (-not (Test-Path $pristine)) { throw "原始备份不存在: $pristine" }

# 进程检查
$procs = Get-Process -Name douyin, douyin_guard, parfait_crash_handler -ErrorAction SilentlyContinue
if ($procs -and -not $Force) {
  Write-Err ('抖音正在运行，请先完全退出：' + ($procs.ProcessName -join ', '))
  exit 1
}

# 校验原始备份确实是官方的
$pmd5 = (Get-HashHex $pristine 'MD5')
if ($pmd5 -ne $ORIG_MD5) { throw "原始备份 md5=$pmd5 与官方 $ORIG_MD5 不符，拒绝用它还原" }
Write-Ok "原始备份校验通过: $pristine"

Write-Step '还原 preload.js'
$curMd5 = (Get-HashHex $target 'MD5')
Write-Host "    当前 md5: $curMd5" -ForegroundColor Gray

if ($curMd5 -eq $ORIG_MD5) {
  Write-Ok '当前已是官方版本，无需还原'
} else {
  Copy-Item $pristine $target -Force
  $newMd5 = (Get-HashHex $target 'MD5')
  if ($newMd5 -ne $ORIG_MD5) { throw '还原后 md5 不一致，请手动检查' }
  Write-Ok "已还原，md5 校验通过（$newMd5）"
}

Write-Step '清理日志'
$userData = Join-Path $env:APPDATA 'douyin'
foreach ($n in @('dy-force.log', 'dy-force-main.log')) {
  $f = Join-Path $userData $n
  if (Test-Path $f) { Remove-Item $f -Force; Write-Ok "已删除 $n" }
}
$marker = Join-Path $ProjectDir 'hook\hook-active.marker'
if (Test-Path $marker) { Remove-Item $marker -Force }

# ---------------------------------------------------------------------------
# 兼容清理：早期版本的部署脚本改过 app.asar（对页面其实无效），
# 这里顺手还原，保证安装目录里不留任何非官方内容。
# ---------------------------------------------------------------------------
Write-Step '检查 app.asar 是否残留早期补丁'
$asarOrig = Join-Path $ProjectDir 'backup\app.asar.orig'
$asarLive = Join-Path (Split-Path (Split-Path $target -Parent) -Parent) 'app.asar'
if ((Test-Path $asarOrig) -and (Test-Path $asarLive)) {
  $origHash = (Get-HashHex $asarOrig 'SHA256').ToUpper()
  $liveHash = (Get-HashHex $asarLive 'SHA256').ToUpper()
  if ($liveHash -eq $origHash) {
    Write-Ok 'app.asar 已是原版，无需处理'
  } else {
    Copy-Item $asarOrig $asarLive -Force
    $after = (Get-HashHex $asarLive 'SHA256').ToUpper()
    if ($after -eq $origHash) { Write-Ok "app.asar 已还原为原版（$after）" }
    else { Write-Host '  [!] app.asar 还原后哈希仍不一致，请手动检查' -ForegroundColor Yellow }
  }
} else {
  Write-Host '  （没有 app.asar 备份或路径不存在，跳过）' -ForegroundColor DarkGray
}

Write-Host ''
Write-Ok '还原完成，抖音已恢复官方状态。'
