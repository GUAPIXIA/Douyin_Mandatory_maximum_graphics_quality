<#
.SYNOPSIS
  First-run setup for a fresh clone: locate Douyin and snapshot the official files.

.DESCRIPTION
  This repository intentionally does NOT contain any Douyin files (they are
  ByteDance's copyrighted code, so backup\ and work\ are git-ignored).

  Those files are machine-specific and are created automatically:
    - "install" (GUI or CLI) freezes backup\loose-preload\preload.js.orig
    - tools\deploy.ps1 freezes it too
  This script does the same thing up front, so that "restore" also works before
  you ever install, and so you can inspect the fingerprints of your own build.

  It only READS from the Douyin install folder and WRITES inside this project.

.PARAMETER DouyinDir
  Douyin install folder. If omitted, common locations are probed.

.EXAMPLE
  pwsh -File D:\Code\dy\tools\prepare.ps1
#>
[CmdletBinding()]
param(
  [string]$DouyinDir,
  [string]$ProjectDir = 'D:\Code\dy'
)

$ErrorActionPreference = 'Stop'

function Title($m) { Write-Host ''; Write-Host ('=' * 64) -ForegroundColor DarkCyan; Write-Host "  $m" -ForegroundColor Cyan; Write-Host ('=' * 64) -ForegroundColor DarkCyan }
function Step($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "[x] $m" -ForegroundColor Red }
function Dim($m)  { Write-Host "    $m" -ForegroundColor DarkGray }

# .NET-only hashing: Windows PowerShell 5.1 has no Get-FileHash
function Get-HashHex([string]$path, [string]$algo) {
  $fs = $null
  try {
    $fs = [System.IO.File]::OpenRead($path)
    $h = [System.Security.Cryptography.HashAlgorithm]::Create($algo)
    return [System.BitConverter]::ToString($h.ComputeHash($fs)).Replace('-', '').ToLower()
  } finally { if ($fs) { $fs.Dispose() } }
}

$module = Join-Path $ProjectDir 'injector\..\tools\douyin-version.ps1'
$script:Manifest = $null
$manifestFile = Join-Path $ProjectDir 'versions.json'
if (Test-Path $manifestFile) {
  try { $script:Manifest = Get-Content $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
}
$ORIG_MD5 = if ($script:Manifest) { [string]$script:Manifest.injection.targetOfficialMd5 } else { 'bfcb8e31fae5a7370c5bee258ffcdfad' }

Title 'FIRST-RUN SETUP'

# ---------------------------------------------------------------------------
# 1) locate the Douyin install folder
# ---------------------------------------------------------------------------
if (-not $DouyinDir) {
  Step 'Looking for the Douyin install folder...'
  $candidates = New-Object System.Collections.Generic.List[string]

  # a running client tells us exactly where it is
  try {
    Get-Process -Name douyin -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.Path) { $candidates.Add((Split-Path $_.Path -Parent)) }
    }
  } catch { }

  foreach ($c in @(
      'D:\douyin', 'C:\douyin', 'E:\douyin', 'F:\douyin',
      'C:\Program Files\douyin', 'C:\Program Files (x86)\douyin',
      'D:\Program Files\douyin', 'D:\Program Files (x86)\douyin',
      'D:\software\douyin', 'D:\soft\douyin', 'D:\apps\douyin',
      (Join-Path $env:LOCALAPPDATA 'douyin'))) {
    $candidates.Add($c)
  }

  try {
    foreach ($rp in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
      Get-ItemProperty $rp -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'douyin' -or $_.DisplayIcon -match 'douyin' } |
        ForEach-Object {
          if ($_.InstallLocation) { $candidates.Add($_.InstallLocation) }
          if ($_.DisplayIcon) {
            $ic = ($_.DisplayIcon -split ',')[0].Trim('"')
            if (Test-Path -LiteralPath $ic) { $candidates.Add((Split-Path $ic -Parent)) }
          }
          if ($_.UninstallString) {
            $us = ($_.UninstallString -split ' ')[0].Trim('"')
            if (Test-Path -LiteralPath $us) { $candidates.Add((Split-Path $us -Parent)) }
          }
        }
    }
  } catch { }

  foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
    if (-not $drive.Root) { continue }
    try {
      Get-ChildItem -LiteralPath $drive.Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match ('douyin|' + [char]0x6296 + [char]0x97F3) } |
        ForEach-Object { $candidates.Add($_.FullName) }
    } catch { }
  }

  foreach ($c in $candidates) {
    if ($c -and (Test-Path (Join-Path $c 'launcher_config.json'))) { $DouyinDir = $c; break }
  }
}
if (-not $DouyinDir) {
  Bad 'Could not find the Douyin install folder. Pass it explicitly:'
  Dim '  pwsh -File tools\prepare.ps1 -DouyinDir "D:\douyin"'
  exit 1
}
Ok ('Douyin folder: ' + $DouyinDir)

$cfgFile = Join-Path $DouyinDir 'launcher_config.json'
if (-not (Test-Path $cfgFile)) { Bad "launcher_config.json not found under $DouyinDir"; exit 1 }
$cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json
$versionDir = Join-Path $DouyinDir $cfg.cur_path
$preloadLive = Join-Path $versionDir 'resources\app.asar.unpacked\preload.js'
$asarLive = Join-Path $versionDir 'resources\app.asar'
$md5Json = Join-Path $versionDir 'md5.json'

Step 'Detected build'
Dim ('douyin version : ' + $cfg.cur_path)
Dim ('version folder : ' + $versionDir)
if (Test-Path $md5Json) {
  try {
    $j = Get-Content $md5Json -Raw | ConvertFrom-Json
    Dim ('md5.json items : ' + (($j.files.PSObject.Properties | Measure-Object).Count))
  } catch { }
}

if (-not (Test-Path $preloadLive)) { Bad "preload.js not found: $preloadLive"; exit 1 }

# ---------------------------------------------------------------------------
# 2) snapshot the official preload.js
# ---------------------------------------------------------------------------
Step 'Snapshotting the official preload.js'
$bkDir = Join-Path $ProjectDir 'backup\loose-preload'
New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
$pristine = Join-Path $bkDir 'preload.js.orig'

$liveMd5 = Get-HashHex $preloadLive 'MD5'
if ($liveMd5 -eq $ORIG_MD5) {
  Copy-Item $preloadLive $pristine -Force
  Ok ('saved pristine copy: ' + $pristine)
  Dim ('md5 : ' + $liveMd5)
} else {
  # already patched (by us or something else): try to strip our injected block
  Warn ('preload.js differs from the official original (md5=' + $liveMd5 + ')')
  $markB = if ($script:Manifest) { [string]$script:Manifest.injection.markBegin } else { '/* ==== DY_FORCE_INJECTOR_BEGIN ==== */' }
  $markE = if ($script:Manifest) { [string]$script:Manifest.injection.markEnd } else { '/* ==== DY_FORCE_INJECTOR_END ==== */' }
  $txt = Get-Content $preloadLive -Raw
  $i = $txt.IndexOf($markB); $j2 = $txt.IndexOf($markE)
  if ($i -ge 0 -and $j2 -gt $i) {
    Step 'Stripping the injected block to recover the original...'
    # Symmetric strip: the injected block owns the newlines around it,
    # so they must be removed too for a byte-exact restore.
    $end2 = $j2 + $markE.Length
    if ($i -gt 0 -and $txt[$i - 1] -eq [char]10) { $i = $i - 1 }
    if ($end2 -lt $txt.Length -and $txt[$end2] -eq [char]13) { $end2++ }
    if ($end2 -lt $txt.Length -and $txt[$end2] -eq [char]10) { $end2++ }
    $recovered = $txt.Substring(0, $i) + $txt.Substring($end2)
    $buildDir = Join-Path $ProjectDir 'work\build'
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
    $tmp = Join-Path $buildDir 'recovered-orig.js'
    [System.IO.File]::WriteAllText($tmp, $recovered, (New-Object System.Text.UTF8Encoding($false)))
    if ((Get-HashHex $tmp 'MD5') -eq $ORIG_MD5) {
      Copy-Item $tmp $pristine -Force
      Ok 'recovered the official original and saved it'
    } else {
      Bad 'could not reconstruct the official original exactly'
    }
  } else {
    Bad 'preload.js was modified by something else; cannot recover automatically.'
    Dim 'Reinstall the Douyin client, then run this script again.'
  }
}

# ---------------------------------------------------------------------------
# 3) snapshot app.asar (optional, used by restore on old installs)
# ---------------------------------------------------------------------------
Step 'Snapshotting app.asar'
$aOrig = Join-Path $ProjectDir 'backup\app.asar.orig'
if (Test-Path $asarLive) {
  $expected = $null
  if (Test-Path $md5Json) {
    try {
      $j2 = Get-Content $md5Json -Raw | ConvertFrom-Json
      $expected = $j2.files.'resources\app.asar'
    } catch { }
  }
  $am = Get-HashHex $asarLive 'MD5'
  if ($expected -and $am -ne $expected) {
    Warn ('app.asar md5=' + $am + ' but md5.json says ' + $expected)
    Warn 'Skipping the app.asar snapshot (it is not the official file).'
  } else {
    Copy-Item $asarLive $aOrig -Force
    Ok ('saved: ' + $aOrig)
    Dim ('md5 : ' + $am)
  }
} else {
  Warn "app.asar not found: $asarLive"
}

# ---------------------------------------------------------------------------
# 4) summary
# ---------------------------------------------------------------------------
Title 'READY'
$okPre = (Test-Path $pristine) -and ((Get-HashHex $pristine 'MD5') -eq $ORIG_MD5)
Ok ('pristine preload.js : ' + $(if ($okPre) { 'OK' } else { 'MISSING' }))
Ok ('app.asar snapshot  : ' + $(if (Test-Path $aOrig) { 'OK' } else { 'not saved' }))
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Gray
Write-Host '  1. Double-click  启动画质助手.bat   (or run douyin-quality-gui.ps1)' -ForegroundColor Gray
Write-Host '  2. Pick douyin.exe, quit Douyin, click "Enable"' -ForegroundColor Gray
Write-Host '  3. Verify:  pwsh -File tools\check-inject.ps1   or  -Action version' -ForegroundColor Gray
Write-Host ''
Write-Host 'If this Douyin version is not in versions.json yet, record it after a' -ForegroundColor Gray
Write-Host 'successful test:   pwsh -File tools\record-version.ps1' -ForegroundColor Gray
