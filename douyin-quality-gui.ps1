<#
=============================================================================
  Douyin PC - Force Highest Video Quality  (GUI tool)
=============================================================================

 ENCODING NOTE (do not "fix" this):
   Every string literal in this .PS1 is intentionally ASCII-only. Chinese text
   inside a PowerShell string literal breaks the parser when the file encoding
   is re-interpreted (Windows PowerShell 5.1 reads .ps1 as ANSI unless a BOM is
   present). Chinese is kept ONLY in gui.xaml, where it is XML content.
   Keep this file UTF-8 with BOM.

 Requires: Windows built-in WPF, plus `node` on PATH (used to build the patch).
=============================================================================
#>
[CmdletBinding()]
param(
  [string]$DouyinDir,
  [string]$ProjectDir = 'D:\Code\dy',
  [switch]$SelfTest,
  [switch]$DumpXaml,
  [switch]$AutoDetect,
  [switch]$TestPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# MD5 of the pristine preload, taken from <install>\md5.json
$ORIG_PRELOAD_MD5 = 'bfcb8e31fae5a7370c5bee258ffcdfad'
$MARK_BEGIN = '/* ==== DY_FORCE_INJECTOR_BEGIN ==== */'
$MARK_END   = '/* ==== DY_FORCE_INJECTOR_END ==== */'

# Remembers the user's chosen install folder
$ConfigFile = Join-Path $ProjectDir 'config.json'

# >>> EMBEDDED-PATCHER-BEGIN (auto-generated, do not edit) >>>
$EmbeddedPatcherB64 = @'
IyEvdXNyL2Jpbi9lbnYgbm9kZQovKioKICogcGF0Y2gtcHJlbG9hZC5qcyAtLSBpbmplY3QgdGhlIHF1YWxpdHkgZW5mb3JjZXIgcGF5bG9hZCBpbnRvIERvdXlpbidzIGxvb3NlIHByZWxvYWQuanMKICoKICogVGhpcyBpcyB0aGUgU0lOR0xFIFNPVVJDRSBPRiBUUlVUSCBmb3IgdGhlIGluamVjdGlvbjoKICogICAtIHRoZSBDTEkgdG9vbGNoYWluICh0b29sc1xkZXBsb3kucHMxIC8gZG91eWluLXF1YWxpdHkucHMxKSBjYWxscyB0aGlzIGZpbGUKICogICAtIHRoZSBHVUkgKGRvdXlpbi1xdWFsaXR5LWd1aS5wczEpIGVtYmVkcyBhIGNvcHkgb2YgaXQsIGtlcHQgaW4gc3luYyBieQogKiAgICAgdG9vbHNcc3luYy1ndWktcGF0Y2hlci5qcywgYW5kIHByZWZlcnMgdGhpcyBmaWxlIHdoZW4gaXQgZXhpc3RzCiAqIEJvdGggcGF0aHMgbXVzdCBwcm9kdWNlIGlkZW50aWNhbCBieXRlcywgb3RoZXJ3aXNlIGluc3RhbGxpbmcgdmlhIGEgZGlmZmVyZW50CiAqIGVudHJ5IHBvaW50IHdvdWxkIHlpZWxkIGEgZGlmZmVyZW50IGZpbGUuCiAqCiAqIFVzYWdlOgogKiAgIG5vZGUgcGF0Y2gtcHJlbG9hZC5qcyAtLXNyYyA8cHJpc3RpbmUgcHJlbG9hZC5qcz4gLS1wYXlsb2FkIDxwYXlsb2FkLmpzPiAtLW91dCA8b3V0LmpzPgogKgogKiBOb3RlczoKICogICAtIFRoZSBpbmplY3RlZCBibG9jayBpcyB3cmFwcGVkIGluIEJFR0lOL0VORCBtYXJrZXJzIHNvIGl0IGNhbiBiZSBzdHJpcHBlZAogKiAgICAgYWdhaW4gKHRoZSBHVUkgdXNlcyB0aGF0IHRvIHJlY292ZXIgdGhlIG9yaWdpbmFsIGZpbGUgYnkgaXRzZWxmKS4KICogICAtIFRoZSBpbmplY3RlZCBjb2RlIGlzIGZ1bGx5IHdyYXBwZWQgaW4gdHJ5L2NhdGNoOyBpdCBuZXZlciB0aHJvd3Mgb3V0d2FyZC4KICogICAtIEl0IHdyaXRlcyBhIGRpc2sgbG9nICglQVBQREFUQSVcZG91eWluXGR5LWZvcmNlLmxvZykgdXNlZCB0byB2ZXJpZnkgdGhhdAogKiAgICAgdGhlIHByZWxvYWQgaXMgYWN0dWFsbHkgbG9hZGVkLgogKiAgIC0gVGhlIGJsb2NrIGlzIGluc2VydGVkIGJlZm9yZSB0aGUgc291cmNlTWFwcGluZ1VSTCBjb21tZW50IHNvIHRoYXQgY29tbWVudAogKiAgICAgc3RheXMgbGFzdC4KICoKICogQVNDSUkgT05MWTogZXZlcnkgc3RyaW5nIGxpdGVyYWwgaW4gdGhpcyBmaWxlIG11c3Qgc3RheSBBU0NJSS4gSXQgZ2V0cwogKiBlbWJlZGRlZCBpbnRvIGEgUG93ZXJTaGVsbCBoZXJlLXN0cmluZywgYW5kIG5vbi1BU0NJSSB0ZXh0IHRoZXJlIGJyZWFrcyB0aGUKICogUG93ZXJTaGVsbCBwYXJzZXIgd2hlbiB0aGUgZmlsZSBlbmNvZGluZyBpcyByZS1pbnRlcnByZXRlZC4KICovCid1c2Ugc3RyaWN0JzsKCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsKCmZ1bmN0aW9uIHBhcnNlQXJncyhhcmd2KSB7CiAgY29uc3Qgb3V0ID0ge307CiAgZm9yIChsZXQgaSA9IDA7IGkgPCBhcmd2Lmxlbmd0aDsgaSsrKSB7CiAgICBjb25zdCBhID0gYXJndltpXTsKICAgIGlmIChhLnN0YXJ0c1dpdGgoJy0tJykpIHsgb3V0W2Euc2xpY2UoMildID0gYXJndlsrK2ldOyB9CiAgfQogIHJldHVybiBvdXQ7Cn0KCmNvbnN0IGFyZ3MgPSBwYXJzZUFyZ3MocHJvY2Vzcy5hcmd2LnNsaWNlKDIpKTsKaWYgKCFhcmdzLnNyYyB8fCAhYXJncy5wYXlsb2FkIHx8ICFhcmdzLm91dCkgewogIGNvbnNvbGUuZXJyb3IoJ3VzYWdlOiBub2RlIHBhdGNoLXByZWxvYWQuanMgLS1zcmMgPHByZWxvYWQuanM+IC0tcGF5bG9hZCA8cGF5bG9hZC5qcz4gLS1vdXQgPG91dC5qcz4nKTsKICBwcm9jZXNzLmV4aXQoMik7Cn0KCmNvbnN0IE1BUktfQkVHSU4gPSAnLyogPT09PSBEWV9GT1JDRV9JTkpFQ1RPUl9CRUdJTiA9PT09ICovJzsKY29uc3QgTUFSS19FTkQgPSAnLyogPT09PSBEWV9GT1JDRV9JTkpFQ1RPUl9FTkQgPT09PSAqLyc7Cgpjb25zdCBvcmlnaW5hbCA9IGZzLnJlYWRGaWxlU3luYyhhcmdzLnNyYywgJ3V0ZjgnKTsKY29uc3QgcGF5bG9hZCA9IGZzLnJlYWRGaWxlU3luYyhhcmdzLnBheWxvYWQsICd1dGY4Jyk7CgppZiAob3JpZ2luYWwuaW5kZXhPZihNQVJLX0JFR0lOKSA+PSAwKSB7CiAgY29uc29sZS5lcnJvcignW3hdIHNvdXJjZSBmaWxlIGlzIGFscmVhZHkgcGF0Y2hlZDsgdXNlIHRoZSBwcmlzdGluZSBvcmlnaW5hbCcpOwogIHByb2Nlc3MuZXhpdCgxKTsKfQoKY29uc3QgTkwgPSBTdHJpbmcuZnJvbUNoYXJDb2RlKDEwKTsKY29uc3QgUSA9IFN0cmluZy5mcm9tQ2hhckNvZGUoMzkpOyAgIC8vIHNpbmdsZSBxdW90ZQpjb25zdCBCUyA9IFN0cmluZy5mcm9tQ2hhckNvZGUoOTIpOyAgLy8gYmFja3NsYXNoCgovLyBBU0NJSS1vbmx5IHdyYXBwZXI6IGluc3RhbGxzIHRoZSBsb2cgc2luayB0aGUgcGF5bG9hZCBleHBlY3RzLCB0aGVuIHJ1bnMgdGhlCi8vIHBheWxvYWQgdmVyYmF0aW0uCmNvbnN0IHdyYXBwZXIgPSBbCiAgJzsoZnVuY3Rpb24gKCkgeycsCiAgJyAgJyArIFEgKyAndXNlIHN0cmljdCcgKyBRICsgJzsnLAogICcgIHZhciBmcyA9IG51bGwsIHBhdGggPSBudWxsLCBsb2dGaWxlID0gJyArIFEgKyBRICsgJzsnLAogICcgIGZ1bmN0aW9uIHdhbChsaW5lKSB7JywKICAnICAgIHRyeSB7JywKICAnICAgICAgaWYgKCFmcykgeyBmcyA9IHJlcXVpcmUoJyArIFEgKyAnZnMnICsgUSArICcpOyBwYXRoID0gcmVxdWlyZSgnICsgUSArICdwYXRoJyArIFEgKyAnKTsgfScsCiAgJyAgICAgIGlmICghbG9nRmlsZSkgeycsCiAgJyAgICAgICAgdmFyIGIgPSBwcm9jZXNzLmVudi5BUFBEQVRBIHx8IHByb2Nlc3MuY3dkKCk7JywKICAnICAgICAgICBsb2dGaWxlID0gcGF0aC5qb2luKGIsICcgKyBRICsgJ2RvdXlpbicgKyBRICsgJywgJyArIFEgKyAnZHktZm9yY2UubG9nJyArIFEgKyAnKTsnLAogICcgICAgICB9JywKICAnICAgICAgZnMuYXBwZW5kRmlsZVN5bmMobG9nRmlsZSwgbmV3IERhdGUoKS50b0lTT1N0cmluZygpICsgJyArIFEgKyAnICcgKyBRICsgJyArIGxpbmUgKyAnICsgUSArIEJTICsgJ24nICsgUSArICcpOycsCiAgJyAgICB9IGNhdGNoIChlKSB7IC8qIGxvZ2dpbmcgbXVzdCBuZXZlciBicmVhayBhbnl0aGluZyAqLyB9JywKICAnICB9JywKICAnICB0cnkgeycsCiAgJyAgICB3YWwoJyArIFEgKyAnW2Jvb3RdIGxvb3NlLXByZWxvYWQgbG9hZGVkIHVybD0nICsgUSArICcgKyAodHlwZW9mIGxvY2F0aW9uICE9PSAnICsgUSArICd1bmRlZmluZWQnICsgUSArICcgPyBsb2NhdGlvbi5ocmVmIDogJyArIFEgKyAnbi9hJyArIFEgKyAnKSArICcgKyBRICsgJyBpc29sYXRlZD0nICsgUSArICcgKyBwcm9jZXNzLmNvbnRleHRJc29sYXRlZCk7JywKICAnICB9IGNhdGNoIChlKSB7fScsCiAgJyAgdHJ5IHsgaWYgKHR5cGVvZiB3aW5kb3cgIT09ICcgKyBRICsgJ3VuZGVmaW5lZCcgKyBRICsgJykgeyB3aW5kb3cuX19keUZvcmNlTG9nID0gd2FsOyB9IH0gY2F0Y2ggKGUpIHt9JywKICAnICB0cnkgeycsCiAgcGF5bG9hZCwKICAnICAgIHdhbCgnICsgUSArICdbYm9vdF0gcGF5bG9hZCBkb25lJyArIFEgKyAnKTsnLAogICcgIH0gY2F0Y2ggKGUpIHsnLAogICcgICAgd2FsKCcgKyBRICsgJ1tib290XSBwYXlsb2FkIGVycm9yOiAnICsgUSArICcgKyAoZSAmJiBlLnN0YWNrID8gZS5zdGFjayA6IGUpKTsnLAogICcgIH0nLAogICd9KSgpOycKXS5qb2luKE5MKTsKCi8vIFRoZSBibG9jayBtdXN0IHJvdW5kLXRyaXAgRVhBQ1RMWTogc3RyaXBwaW5nIG11c3QgcmVzdG9yZSB0aGUgb3JpZ2luYWwgYnl0ZQovLyBmb3IgYnl0ZS4gU28gdGhlIGluamVjdGVkIGJsb2NrIG93bnMgYm90aCB0aGUgbmV3bGluZSBiZWZvcmUgTUFSS19CRUdJTiBhbmQKLy8gdGhlIG5ld2xpbmUgYWZ0ZXIgTUFSS19FTkQsIGFuZCB0aGUgc3RyaXAgc2lkZSByZW1vdmVzIFtpLCBlbmQpIHdoZXJlIGVuZCBpcwovLyB0aGUgb2Zmc2V0IGp1c3QgcGFzdCB0aGF0IHRyYWlsaW5nIG5ld2xpbmUuCmNvbnN0IGluamVjdGlvbiA9IE5MICsgTUFSS19CRUdJTiArIE5MICsgd3JhcHBlciArIE5MICsgTUFSS19FTkQgKyBOTDsKCi8vIEtlZXAgdGhlIHNvdXJjZU1hcHBpbmdVUkwgY29tbWVudCBsYXN0CmNvbnN0IG1hcElkeCA9IG9yaWdpbmFsLmxhc3RJbmRleE9mKCcvLyMgc291cmNlTWFwcGluZ1VSTCcpOwpjb25zdCBwYXRjaGVkID0gbWFwSWR4ID49IDAKICA/IG9yaWdpbmFsLnNsaWNlKDAsIG1hcElkeCkgKyBpbmplY3Rpb24gKyBvcmlnaW5hbC5zbGljZShtYXBJZHgpCiAgOiBvcmlnaW5hbCArIGluamVjdGlvbjsKCmZzLndyaXRlRmlsZVN5bmMoYXJncy5vdXQsIHBhdGNoZWQsICd1dGY4Jyk7Cgpjb25zb2xlLmxvZygnW29rXSB3cm90ZSAnICsgYXJncy5vdXQpOwpjb25zb2xlLmxvZygnW2ldICcgKyBCdWZmZXIuYnl0ZUxlbmd0aChvcmlnaW5hbCkgKyAnIGJ5dGVzIC0+ICcgKyBCdWZmZXIuYnl0ZUxlbmd0aChwYXRjaGVkKSArICcgYnl0ZXMnKTsK
'@
$EmbeddedPatcherMd5 = '387cedabb644af334fd044c176e636ab'
# <<< EMBEDDED-PATCHER-END <<<

# ===========================================================================
# Helpers
# ===========================================================================
function Get-Md5([string]$p) {
  if (-not (Test-Path $p)) { return '' }
  return (Get-HashHex $p 'MD5')
}
function Get-Sha([string]$p) {
  if (-not (Test-Path $p)) { return '' }
  return (Get-HashHex $p 'SHA256').ToUpper()
}
# .NET-only hashing: Windows PowerShell 5.1 (which a .bat launcher starts) does
# not ship Get-FileHash, and shelling out must not happen for every file.
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
function Test-DouyinRunning {
  $p = Get-Process -Name douyin, douyin_guard, parfait_crash_handler -ErrorAction SilentlyContinue
  return ($null -ne $p)
}

function Read-Config {
  if (-not (Test-Path $ConfigFile)) { return $null }
  try {
    $c = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    if ($c.douyinDir) { return [string]$c.douyinDir }
  } catch { }
  return $null
}

function Save-Config([string]$dir) {
  try {
    $obj = [ordered]@{ douyinDir = $dir; savedAt = (Get-Date).ToString('o') }
    [System.IO.File]::WriteAllText($ConfigFile, ($obj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    return $true
  } catch { return $false }
}

# A valid install root has launcher_config.json plus <ver>\resources\app.asar.unpacked\preload.js
function Test-InstallRoot([string]$dir) {
  if ([string]::IsNullOrWhiteSpace($dir)) { return $false }
  $cfg = Join-Path $dir 'launcher_config.json'
  if (-not (Test-Path $cfg)) { return $false }
  try {
    $c = Get-Content $cfg -Raw | ConvertFrom-Json
    if (-not $c.cur_path) { return $false }
    $pre = Join-Path (Join-Path $dir $c.cur_path) 'resources\app.asar.unpacked\preload.js'
    return (Test-Path $pre)
  } catch { return $false }
}

# Accepts anything the user may have picked (exe, version folder, or root)
function Resolve-InstallRoot([string]$picked) {
  if ([string]::IsNullOrWhiteSpace($picked)) { return $null }
  $candidates = New-Object System.Collections.Generic.List[string]

  $full = $picked
  if (Test-Path -LiteralPath $picked) {
    $item = Get-Item -LiteralPath $picked -ErrorAction SilentlyContinue
    if ($item -and -not $item.PSIsContainer) { $full = $item.DirectoryName } else { $full = $item.FullName }
  }
  $candidates.Add($full)
  $candidates.Add((Split-Path $full -Parent))
  $d = $full
  for ($i = 0; $i -lt 4; $i++) {
    $d = Split-Path $d -Parent
    if ($d) { $candidates.Add($d) } else { break }
  }

  foreach ($c in $candidates) {
    if (Test-InstallRoot $c) { return (Resolve-Path -LiteralPath $c).Path }
  }
  return $null
}

function Get-AutoDetectCandidates {
  $list = New-Object System.Collections.Generic.List[string]

  try {
    Get-Process -Name douyin -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.Path) { $list.Add((Split-Path $_.Path -Parent)) }
    }
  } catch { }

  foreach ($c in @(
      'D:\douyin', 'C:\douyin', 'E:\douyin', 'F:\douyin',
      'C:\Program Files\douyin', 'C:\Program Files (x86)\douyin',
      'D:\Program Files\douyin', 'D:\Program Files (x86)\douyin',
      (Join-Path $env:LOCALAPPDATA 'douyin'),
      (Join-Path $env:APPDATA 'douyin'),
      'D:\software\douyin', 'D:\soft\douyin', 'D:\apps\douyin')) {
    $list.Add($c)
  }

  try {
    foreach ($rp in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
      Get-ItemProperty $rp -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'douyin' -or $_.DisplayIcon -match 'douyin' } |
        ForEach-Object {
          if ($_.InstallLocation) { $list.Add($_.InstallLocation) }
          if ($_.DisplayIcon) {
            $ic = ($_.DisplayIcon -split ',')[0].Trim('"')
            if (Test-Path -LiteralPath $ic) { $list.Add((Split-Path $ic -Parent)) }
          }
          if ($_.UninstallString) {
            $us = ($_.UninstallString -split ' ')[0].Trim('"')
            if (Test-Path -LiteralPath $us) { $list.Add((Split-Path $us -Parent)) }
          }
        }
    }
  } catch { }

  foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
    $root = $drive.Root
    if (-not $root) { continue }
    try {
      Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match ('douyin|' + [char]0x6296 + [char]0x97F3) } |
        ForEach-Object { $list.Add($_.FullName) }
    } catch { }
  }

  return $list
}

function Find-DouyinDir {
  if ($DouyinDir) {
    $r = Resolve-InstallRoot $DouyinDir
    if ($r) { return $r }
  }
  $saved = Read-Config
  if ($saved) {
    $r = Resolve-InstallRoot $saved
    if ($r) { return $r }
  }
  foreach ($c in (Get-AutoDetectCandidates)) {
    $r = Resolve-InstallRoot $c
    if ($r) { return $r }
  }
  return $null
}

function Get-InstallPaths([string]$root) {
  if (-not (Test-InstallRoot $root)) { throw "Not a valid Douyin install folder: $root" }
  $cfg = Get-Content (Join-Path $root 'launcher_config.json') -Raw | ConvertFrom-Json
  $versionDir = Join-Path $root $cfg.cur_path
  [pscustomobject]@{
    Root       = $root
    VersionDir = $versionDir
    Preload    = Join-Path $versionDir 'resources\app.asar.unpacked\preload.js'
    Asar       = Join-Path $versionDir 'resources\app.asar'
    Md5Json    = Join-Path $versionDir 'md5.json'
  }
}

function Get-ToolPaths {
  [pscustomobject]@{
    Payload     = Join-Path $ProjectDir 'injector\payload.js'
    OrigPreload = Join-Path $ProjectDir 'backup\loose-preload\preload.js.orig'
    AsarOrig    = Join-Path $ProjectDir 'backup\app.asar.orig'
    BuildDir    = Join-Path $ProjectDir 'work\build'
    UserData    = Join-Path $env:APPDATA 'douyin'
    PageLog     = Join-Path $env:APPDATA 'douyin\dy-force.log'
  }
}

# Prefer the canonical patcher next to this tool; otherwise decode the embedded copy.
function Ensure-Patcher([string]$buildDir) {  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  $canonical = Join-Path $ProjectDir 'tools\patch-preload.js'
  if ((Test-Path $canonical) -and ((Get-Item $canonical).Length -gt 500)) { return $canonical }

  $fallback = Join-Path $buildDir 'embedded-patch.js'
  try {
    $bytes = [System.Convert]::FromBase64String(($EmbeddedPatcherB64 -replace '\s', ''))
    $md5 = [System.BitConverter]::ToString((New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash($bytes)).Replace('-', '').ToLower()
    if ($md5 -eq $EmbeddedPatcherMd5) {
      [System.IO.File]::WriteAllBytes($fallback, $bytes)
      return $fallback
    }
  } catch { }
  throw 'No usable patcher: tools\patch-preload.js is missing and the embedded copy failed to decode.'
}

# ===========================================================================
# Version compatibility (shared implementation in tools\douyin-version.ps1)
# ===========================================================================
$script:VersionInfo = $null
$versionModule = Join-Path $ProjectDir 'tools\douyin-version.ps1'
if (Test-Path $versionModule) {
  try { . $versionModule } catch { $script:VersionModuleError = $_.Exception.Message }
} else {
  $script:VersionModuleError = 'tools\douyin-version.ps1 not found'
}

function Update-VersionInfo([string]$root) {
  $script:VersionInfo = $null
  if (-not $root) { return }
  if (-not (Get-Command Get-DouyinVersionInfo -ErrorAction SilentlyContinue)) { return }
  try {
    $script:VersionInfo = Get-DouyinVersionInfo -InstallRoot $root -ProjectDir $ProjectDir
  } catch {
    $script:VersionInfo = $null
    Write-Log ('版本检查失败：' + $_.Exception.Message) 'warn'
  }
}
# ===========================================================================
# Load UI
# ===========================================================================
$xamlFile = Join-Path $PSScriptRoot 'gui.xaml'
if (-not (Test-Path $xamlFile)) { throw "gui.xaml not found: $xamlFile" }

[xml]$xaml = Get-Content $xamlFile -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)

$C = @{}
foreach ($n in @('StatusIcon','StatusText','StatusDetail','VersionValue','PreloadValue','AsarValue','BackupValue',
                 'PathBox','BtnBrowse','BtnInstall','BtnRestore','BtnCheck','BtnRefresh',
                 'LogBox','FootText','RunBadge')) {
  $C[$n] = $win.FindName($n)
}
$missing = @($C.Keys | Where-Object { $null -eq $C[$_] })
if ($missing.Count -gt 0) { throw ('gui.xaml is missing controls: ' + ($missing -join ',')) }

function Pump {
  try {
    $frame = New-Object System.Windows.Threading.DispatcherFrame
    $cb = [System.Windows.Threading.DispatcherOperationCallback]{
      param($f)
      $f.Continue = $false
      return $null
    }
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
      [System.Windows.Threading.DispatcherPriority]::Background, $cb, $frame) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
  } catch { }
}

function Write-Log([string]$msg, [string]$level = 'info') {
  $ts = Get-Date -Format 'HH:mm:ss'
  $prefix = switch ($level) {
    'ok'    { '[ OK ]' }
    'warn'  { '[WARN]' }
    'err'   { '[FAIL]' }
    default { '[INFO]' }
  }
  $C.LogBox.AppendText('[' + $ts + '] ' + $prefix + ' ' + $msg + [Environment]::NewLine)
  $C.LogBox.ScrollToEnd()
  Pump
}

function Set-Status([string]$icon, [string]$text, [string]$detail, [string]$color) {
  $C.StatusIcon.Text = $icon
  $C.StatusText.Text = $text
  $C.StatusText.Foreground = $color
  $C.StatusDetail.Text = $detail
}

function Set-Busy([bool]$busy) {
  $win.Cursor = if ($busy) { 'Wait' } else { 'Arrow' }
  $C.BtnInstall.IsEnabled = -not $busy
  $C.BtnRestore.IsEnabled = -not $busy
  $C.BtnCheck.IsEnabled = -not $busy
  $C.BtnRefresh.IsEnabled = -not $busy
  $C.BtnBrowse.IsEnabled = -not $busy
  Pump
}

$script:InstallRoot = $null
$script:TRACE = { param($m) try { [System.IO.File]::AppendAllText("D:\Code\dy\work\gui-state.txt", $m + [Environment]::NewLine) } catch {} }


function Set-InstallRoot([string]$root, [switch]$Persist) {
  $script:InstallRoot = $root
  if ($Persist -and $root) { [void](Save-Config $root) }
  Update-VersionInfo $root
  $C.PathBox.Text = if ($root) { $root } else { '尚未选择' }
}

# ---------------------------------------------------------------------------
# Browse for douyin.exe
# ---------------------------------------------------------------------------
function Invoke-Browse {
  $dlg = New-Object Microsoft.Win32.OpenFileDialog
  $dlg.Title = '请选择抖音程序 douyin.exe'
  $dlg.Filter = 'douyin.exe|douyin.exe|可执行文件 (*.exe)|*.exe|所有文件 (*.*)|*.*'
  $dlg.CheckFileExists = $true
  $dlg.Multiselect = $false

  # Only used to open the dialog in a helpful place - it never auto-selects
  $hint = $null
  if ($script:InstallRoot) { $hint = $script:InstallRoot }
  elseif ($script:HintDir) { $hint = $script:HintDir }
  if ($hint -and (Test-Path $hint)) { $dlg.InitialDirectory = $hint }

  $res = $dlg.ShowDialog($win)
  if ($res -ne $true) { Write-Log '已取消选择。' 'warn'; return }

  $picked = $dlg.FileName
  Write-Log ('已选择：' + $picked)

  if ((Split-Path $picked -Leaf) -notlike 'douyin*.exe') {
    Write-Log '注意：文件名不叫 douyin.exe，继续尝试识别所在目录。' 'warn'
  }

  $root = Resolve-InstallRoot $picked
  if (-not $root) {
    Write-Log '该文件不在抖音安装目录里，无法识别。' 'err'
    [System.Windows.MessageBox]::Show(
      ('该文件不在抖音安装目录中，无法识别。' + [Environment]::NewLine + [Environment]::NewLine +
       '请选择抖音安装目录里的 douyin.exe，例如：' + [Environment]::NewLine +
       '  D:\douyin\douyin.exe' + [Environment]::NewLine +
       '  C:\Program Files\douyin\douyin.exe'),
      '位置不正确', 'OK', 'Warning') | Out-Null
    return
  }

  Set-InstallRoot $root -Persist
  Write-Log ('已确认抖音位置：' + $root) 'ok'
  Write-Log '接下来：退出抖音 → 点「① 一键启用最高画质」' 
  Update-View
}

# ---------------------------------------------------------------------------
# Status board
# ---------------------------------------------------------------------------
function Update-View {
  if (-not $script:InstallRoot) {
    Set-Status '?' '请先选择抖音程序' '点下面的「浏览…」，选中抖音安装目录里的 douyin.exe' '#D25F00'
    $C.BtnInstall.IsEnabled = $false
    $C.BtnRestore.IsEnabled = $false
    $C.BtnCheck.IsEnabled = $false
    $C.BtnBrowse.IsEnabled = $true
    if ($C.PathBox.Text -eq '' -or $C.PathBox.Text -eq '(not found - click Browse...)') { $C.PathBox.Text = '尚未选择' }
    $C.VersionValue.Text = '待选择（选好后自动识别）'
    $C.VersionValue.Foreground = '#86909C'
    $C.PreloadValue.Text = '-'
    $C.AsarValue.Text = '-'
    $C.BackupValue.Text = '-'
    return
  }

  try { $p = Get-InstallPaths $script:InstallRoot } catch {
    Set-Status '!' 'Douyin folder problem' $_.Exception.Message '#C0392B'
    $C.BtnInstall.IsEnabled = $false
    $C.BtnRestore.IsEnabled = $false
    $C.BtnCheck.IsEnabled = $false
    return
  }
  $t = Get-ToolPaths

  # --- 版本兼容性 ---
  $vi = $script:VersionInfo
  if ($vi) {
    switch ($vi.Status) {
      'verified'    { $C.VersionValue.Text = $vi.Version + '（已实测支持）'; $C.VersionValue.Foreground = '#00B42A' }
      'compatible'  { $C.VersionValue.Text = $vi.Version + '（结构兼容，未实测）'; $C.VersionValue.Foreground = '#E67E22' }
      'unknown'     { $C.VersionValue.Text = $vi.Version + '（未验证的新版本）'; $C.VersionValue.Foreground = '#E67E22' }
      'unsupported' { $C.VersionValue.Text = $vi.Version + '（不受支持）'; $C.VersionValue.Foreground = '#F53F3F' }
      default       { $C.VersionValue.Text = '无法识别'; $C.VersionValue.Foreground = '#F53F3F' }
    }
  } else {
    $C.VersionValue.Text = '未检查'
    $C.VersionValue.Foreground = '#86909C'
  }

  if (Test-DouyinRunning) {
    $C.RunBadge.Text = 'Douyin RUNNING'
    $C.RunBadge.Foreground = '#F53F3F'
  } else {
    $C.RunBadge.Text = 'Douyin not running'
    $C.RunBadge.Foreground = '#00B42A'
  }

  $md5 = Get-Md5 $p.Preload
  if ($md5 -eq '') {
    Set-Status '?' 'preload.js not found' $p.Preload '#C0392B'
    $C.BtnInstall.IsEnabled = $false
    $C.BtnRestore.IsEnabled = $false
  } elseif ($md5 -eq $ORIG_PRELOAD_MD5) {
    Set-Status 'o' 'Not enabled yet' 'Click button 1 above to enable' '#E67E22'
    $C.BtnInstall.IsEnabled = -not (Test-DouyinRunning)
    $C.BtnRestore.IsEnabled = $false
  } else {
    Set-Status '*' 'Highest quality ENABLED' 'Open Douyin - videos use the best available clarity' '#00B42A'
    $C.BtnInstall.IsEnabled = -not (Test-DouyinRunning)
    $C.BtnRestore.IsEnabled = -not (Test-DouyinRunning)
  }

  if ($md5 -eq '') { $C.PreloadValue.Text = 'missing' }
  elseif ($md5 -eq $ORIG_PRELOAD_MD5) { $C.PreloadValue.Text = 'official / untouched' }
  else { $C.PreloadValue.Text = 'patched (' + $md5.Substring(0, 8) + '...)' }

  $asarState = 'unknown'
  if (Test-Path $p.Md5Json) {
    $manifest = Get-Content $p.Md5Json -Raw | ConvertFrom-Json
    $exp = $manifest.files.'resources\app.asar'
    if ($exp) {
      if ((Get-Md5 $p.Asar) -eq $exp) { $asarState = 'official / untouched' } else { $asarState = 'MODIFIED (unexpected)' }
    }
  }
  $C.AsarValue.Text = $asarState

  $bm = Get-Md5 $t.OrigPreload
  if ($bm -eq $ORIG_PRELOAD_MD5) { $C.BackupValue.Text = 'good (restore is possible)' }
  elseif ($bm -eq '') { $C.BackupValue.Text = 'none yet (created on first enable)' }
  else { $C.BackupValue.Text = 'BAD' }

  $C.BtnCheck.IsEnabled = (Test-Path $t.PageLog)
  $C.FootText.Text = 'Version folder: ' + $p.VersionDir
}

# ===========================================================================
# ENABLE
# ===========================================================================
function Invoke-Install {
  $C.LogBox.Clear()
  Write-Log 'Starting enable...'
  $nl = [Environment]::NewLine

  if (-not $script:InstallRoot) {
    Write-Log 'Douyin location is not set yet - opening the file picker.' 'warn'
    Invoke-Browse
    if (-not $script:InstallRoot) { return }
  }

  try { $p = Get-InstallPaths $script:InstallRoot } catch { Write-Log $_.Exception.Message 'err'; return }
  $t = Get-ToolPaths

  if (Test-DouyinRunning) {
    Write-Log 'Douyin is running. Please quit it completely first.' 'err'
    [System.Windows.MessageBox]::Show(
      ('Douyin is still running.' + $nl + $nl +
       'Right-click the tray icon and choose Exit, make sure douyin.exe is gone in Task Manager, then click again.'),
      'Quit Douyin first', 'OK', 'Warning') | Out-Null
    return
  }

  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Log 'node not found on PATH - cannot build the patch.' 'err'
    [System.Windows.MessageBox]::Show('Node.js was not found on PATH. Please install Node.js and retry.', 'Missing dependency', 'OK', 'Error') | Out-Null
    return
  }

  Set-Busy $true
  try {
    Write-Log ('Using install folder: ' + $script:InstallRoot)
    Write-Log 'Checking the pristine backup...'
    New-Item -ItemType Directory -Force -Path (Split-Path $t.OrigPreload -Parent) | Out-Null
    $haveOrig = ((Get-Md5 $t.OrigPreload) -eq $ORIG_PRELOAD_MD5)

    if ($haveOrig) {
      Write-Log 'Pristine backup present and verified.' 'ok'
    } elseif ((Get-Md5 $p.Preload) -eq $ORIG_PRELOAD_MD5) {
      Copy-Item $p.Preload $t.OrigPreload -Force
      $haveOrig = $true
      Write-Log 'Pristine backup created.' 'ok'
    } else {
      Write-Log 'File is already patched; stripping our block to recover the original...' 'warn'
      $txt = Get-Content $p.Preload -Raw
      $i = $txt.IndexOf($MARK_BEGIN)
      $j = $txt.IndexOf($MARK_END)
      $end = if ($j -gt $i) { $j + $MARK_END.Length } else { 0 }
      # Symmetric strip: the injected block owns the newlines around it
      if ($i -gt 0 -and $i -lt $txt.Length -and $txt[$i - 1] -eq [char]10) { $i = $i - 1 }
      if ($end -gt 0 -and $end -lt $txt.Length -and $txt[$end] -eq [char]13) { $end++ }
      if ($end -gt 0 -and $end -lt $txt.Length -and $txt[$end] -eq [char]10) { $end++ }
      if ($i -ge 0 -and $j -gt $i) {
        New-Item -ItemType Directory -Force -Path $t.BuildDir | Out-Null
        $tmp = Join-Path $t.BuildDir 'recovered-orig.js'
        $stripped = $txt.Substring(0, $i) + $txt.Substring($end)
        [System.IO.File]::WriteAllText($tmp, $stripped, (New-Object System.Text.UTF8Encoding($false)))
        if ((Get-Md5 $tmp) -eq $ORIG_PRELOAD_MD5) {
          Copy-Item $tmp $t.OrigPreload -Force
          $haveOrig = $true
          Write-Log 'Original recovered successfully.' 'ok'
        }
      }
    }

    if (-not $haveOrig) {
      Write-Log 'Cannot obtain the official original file - aborted.' 'err'
      [System.Windows.MessageBox]::Show(
        ('The official original file could not be obtained, so nothing was changed.' + $nl + $nl +
         'Please reinstall the Douyin client and try again.'),
        'Enable failed', 'OK', 'Error') | Out-Null
      return
    }

    Write-Log 'Building patched file...'
    $patcher = Ensure-Patcher $t.BuildDir
    $built = Join-Path $t.BuildDir 'gui-patched.js'

    $out = & node $patcher --src $t.OrigPreload --payload $t.Payload --out $built 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $built)) {
      throw ('build failed: ' + ($out -join ' '))
    }
    Write-Log ('Built OK ({0:N0} bytes)' -f (Get-Item $built).Length) 'ok'

    Write-Log 'Writing into the Douyin folder...'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $snap = Join-Path $ProjectDir ('backup\' + $stamp)
    New-Item -ItemType Directory -Force -Path $snap | Out-Null
    Copy-Item $p.Preload (Join-Path $snap 'preload.js.before') -Force
    Copy-Item $built $p.Preload -Force
    Write-Log ('Written (md5 ' + (Get-Md5 $p.Preload).Substring(0, 8) + ')') 'ok'

    foreach ($f in @($t.PageLog, (Join-Path $t.UserData 'dy-force-main.log'))) {
      if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
    }

    if ((Test-Path $t.AsarOrig) -and ((Get-Sha $p.Asar) -ne (Get-Sha $t.AsarOrig))) {
      Copy-Item $t.AsarOrig $p.Asar -Force
      Write-Log 'app.asar restored to the official version.' 'ok'
    }

    # 写部署元数据：tools\restore.ps1 依赖它才能还原。
    # 走 GUI 安装的用户也必须留下这个文件，否则以后无法一键还原。
    try {
      $metaDir = Join-Path $ProjectDir 'backup'
      New-Item -ItemType Directory -Force -Path $metaDir | Out-Null
      $meta = [ordered]@{
        timestamp     = (Get-Date).ToString('o')
        versionDir    = $p.VersionDir
        targetFile    = $p.Preload
        origMd5       = $ORIG_PRELOAD_MD5
        newMd5        = (Get-Md5 $p.Preload)
        pristinePath  = $t.OrigPreload
        payloadFile   = $t.Payload
        installedBy   = 'gui'
        douyinVersion = if ($script:VersionInfo) { $script:VersionInfo.Version } else { '' }
        toolVersion   = if ($script:VersionInfo) { $script:VersionInfo.ToolVersion } else { '' }
      }
      [System.IO.File]::WriteAllText(
        (Join-Path $metaDir 'deploy-meta.json'),
        ($meta | ConvertTo-Json -Depth 4),
        (New-Object System.Text.UTF8Encoding($false)))
      Set-Content -Path (Join-Path $metaDir 'LATEST') -Value (Get-Date -Format 'yyyyMMdd-HHmmss') -Encoding UTF8
      Write-Log 'Restore metadata written (backup\deploy-meta.json).' 'ok'
    } catch {
      Write-Log ('Could not write restore metadata: ' + $_.Exception.Message) 'warn'
    }

    Write-Log 'Done. You can start Douyin now.' 'ok'
    [System.Windows.MessageBox]::Show(
      ('Highest quality is now enabled.' + $nl + $nl +
       'Next:' + $nl +
       '  1. Start Douyin normally' + $nl +
       '  2. Open any 4K-capable video' + $nl +
       '  3. Clarity will be 4K right away' + $nl + $nl +
       '(Videos without 4K fall back to 2K or 1080P automatically.)'),
      'Enabled', 'OK', 'Information') | Out-Null
  } catch {
    Write-Log ('Enable error: ' + $_.Exception.Message) 'err'
    [System.Windows.MessageBox]::Show(('Enable error:' + $nl + $nl + $_.Exception.Message), 'Error', 'OK', 'Error') | Out-Null
  } finally {
    Set-Busy $false
    Update-View
  }
}

# ===========================================================================
# RESTORE
# ===========================================================================
function Invoke-Restore {
  $C.LogBox.Clear()
  Write-Log 'Starting restore...'
  $nl = [Environment]::NewLine

  if (-not $script:InstallRoot) { Write-Log 'Douyin location is not set. Click Browse first.' 'err'; return }
  try { $p = Get-InstallPaths $script:InstallRoot } catch { Write-Log $_.Exception.Message 'err'; return }
  $t = Get-ToolPaths

  if (Test-DouyinRunning) {
    Write-Log 'Douyin is running. Please quit it first.' 'err'
    [System.Windows.MessageBox]::Show('Please quit Douyin from the tray first.', 'Quit Douyin first', 'OK', 'Warning') | Out-Null
    return
  }

  $ans = [System.Windows.MessageBox]::Show(
    ('Restore Douyin to the official version?' + $nl + $nl +
     'The highest-quality forcing will stop working (you can enable it again later).'),
    'Confirm restore', 'YesNo', 'Question')
  if ($ans -ne 'Yes') { Write-Log 'Restore cancelled.'; return }

  Set-Busy $true
  try {
    if ((Get-Md5 $t.OrigPreload) -ne $ORIG_PRELOAD_MD5) {
      throw 'Pristine backup is missing or fails verification; refusing to restore.'
    }
    Copy-Item $t.OrigPreload $p.Preload -Force
    if ((Get-Md5 $p.Preload) -ne $ORIG_PRELOAD_MD5) { throw 'verification after restore failed' }
    Write-Log 'preload.js restored to the official version.' 'ok'

    if ((Test-Path $t.AsarOrig) -and ((Get-Sha $p.Asar) -ne (Get-Sha $t.AsarOrig))) {
      Copy-Item $t.AsarOrig $p.Asar -Force
      Write-Log 'app.asar restored to the official version.' 'ok'
    }

    foreach ($n in @('dy-force.log', 'dy-force-main.log')) {
      $f = Join-Path $t.UserData $n
      if (Test-Path $f) { Remove-Item $f -Force }
    }

    Write-Log 'Restore complete - Douyin is back to its official state.' 'ok'
    [System.Windows.MessageBox]::Show('Restored to the official version.', 'Restore complete', 'OK', 'Information') | Out-Null
  } catch {
    Write-Log ('Restore error: ' + $_.Exception.Message) 'err'
    [System.Windows.MessageBox]::Show(('Restore error:' + $nl + $nl + $_.Exception.Message), 'Error', 'OK', 'Error') | Out-Null
  } finally {
    Set-Busy $false
    Update-View
  }
}

# ===========================================================================
# CHECK
# ===========================================================================
function Invoke-Check {
  $C.LogBox.Clear()
  Write-Log 'Reading the runtime log...'
  $t = Get-ToolPaths
  $nl = [Environment]::NewLine

  if (-not (Test-Path $t.PageLog)) {
    Write-Log 'No runtime log yet. Enable first, then open some videos.' 'warn'
    [System.Windows.MessageBox]::Show(
      ('No runtime log found yet.' + $nl + $nl +
       'Please do this first:' + $nl +
       '  1. Quit Douyin' + $nl +
       '  2. Click button 1 (Enable)' + $nl +
       '  3. Start Douyin and open a few videos' + $nl +
       '  4. Come back and click button 3 (Check)'),
      'No data yet', 'OK', 'Information') | Out-Null
    return
  }

  $lines = Get-Content $t.PageLog
  $onPage  = $lines | Where-Object { $_ -match 'loose-preload .*url=https://www\.douyin\.com' }
  $created = ($lines | Where-Object { $_ -match '\[created\]' }).Count
  $forced  = ($lines | Where-Object { $_ -match '\[forced\]' }).Count
  $skipped = ($lines | Where-Object { $_ -match '\[skip\]' }).Count
  $errs    = $lines | Where-Object { $_ -match 'SecurityError|ERROR|error' }

  Write-Log ('Log lines: ' + $lines.Count)
  if ($onPage) { Write-Log 'Injection confirmed on the Douyin page.' 'ok' }
  else { Write-Log 'No Douyin-page injection record found.' 'err' }
  Write-Log ('Clarity writes: created=' + $created + ' forced=' + $forced + ' kept-default=' + $skipped)
  if ($errs) { Write-Log ('Error lines: ' + $errs.Count) 'warn' }

  if ($onPage -and ($created -gt 0 -or $forced -gt 0)) {
    Write-Log 'Verdict: the tool is working.' 'ok'
    [System.Windows.MessageBox]::Show(
      ('The tool is working correctly.' + $nl + $nl +
       'If the picture still does not look like 4K, check:' + $nl +
       '  - the video itself offers a 4K option' + $nl +
       '  - you are logged in (4K usually requires login)' + $nl +
       '  - open the clarity menu and look at the current tier'),
      'Check result: OK', 'OK', 'Information') | Out-Null
  } else {
    Write-Log 'Verdict: no effect recorded yet - open some videos first.' 'warn'
    [System.Windows.MessageBox]::Show(
      ('No effect recorded yet.' + $nl + $nl +
       'Start Douyin, open a few videos, then click Check again.'),
      'Check result: no data', 'OK', 'Information') | Out-Null
  }
}

# ===========================================================================
# Wire up
# ===========================================================================
$C.BtnBrowse.Add_Click({ Invoke-Browse })
$C.BtnInstall.Add_Click({ Invoke-Install })
$C.BtnRestore.Add_Click({ Invoke-Restore })
$C.BtnCheck.Add_Click({ Invoke-Check })
$C.BtnRefresh.Add_Click({
  $C.LogBox.Clear()
  Write-Log 'Status refreshed.'
  Update-VersionInfo $script:InstallRoot
  Update-View
})

$win.Add_Loaded({
  try {
    Update-VersionInfo $null
    Write-Log '工具已就绪。请先点「浏览…」选择 douyin.exe。'
    if ($script:VersionModuleError) { Write-Log ('版本检查模块未加载：' + $script:VersionModuleError) 'warn' }

    # 必须由用户自己选 douyin.exe；自动探测只用来提示位置，不自动选定
    $hint = Find-DouyinDir
    if ($hint) {
      $script:HintDir = $hint
      Write-Log ('检测到抖音可能在：' + $hint)
      Write-Log '请点「浏览…」选中 douyin.exe 以确认。'
    } else {
      Write-Log '未能自动找到抖音，请用「浏览…」手动定位。' 'warn'
    }

    Set-InstallRoot $null
    Set-Status '?' '请先选择抖音程序' '点下面的「浏览…」，选中抖音安装目录里的 douyin.exe' '#D25F00'
    Update-View
    $C.LogBox.AppendText('提示：douyin.exe 通常在 <抖音安装目录>\douyin.exe' + [Environment]::NewLine)
  } catch {
    Write-Log ('启动出错：' + $_.Exception.Message) 'err'
  }
})

if ($TestPath) {
  # 无人值守自检：直接用给定路径走一遍状态刷新，然后退出（供维护与回归测试）
  $probeRoot = if ($DouyinDir) { $DouyinDir } else { 'D:\douyin' }
  Set-InstallRoot $probeRoot
  Update-VersionInfo $probeRoot
  Update-View
  Write-Host ('TESTPATH-ROOT=' + $script:InstallRoot)
  if ($script:VersionInfo) {
    Write-Host ('TESTPATH-VERSION=' + $script:VersionInfo.Version)
    Write-Host ('TESTPATH-STATUS=' + $script:VersionInfo.Status)
    Write-Host ('TESTPATH-LABEL=' + $script:VersionInfo.Label)
  } else {
    Write-Host 'TESTPATH-VERSION=(none)'
  }
  Write-Host ('TESTPATH-VERSIONROW=' + $C.VersionValue.Text)
  Write-Host ('TESTPATH-INSTALLBTN=' + $C.BtnInstall.IsEnabled)
  exit 0
}

if ($DumpXaml) {
  Write-Host 'XAML-LOADED-OK'
  Write-Host ('controls=' + (($C.Keys | Sort-Object) -join ','))
  exit 0
}

if ($AutoDetect) {
  $found = Find-DouyinDir
  if ($found) { Write-Host ('DETECTED=' + $found) } else { Write-Host 'DETECTED=NONE' }
  exit 0
}

if ($SelfTest) {
  Update-View
  Write-Host 'SELFTEST-OK'
  exit 0
}

try {
  $win.ShowDialog() | Out-Null
} catch {
  $errFile = Join-Path $ProjectDir 'work\gui-error.txt'
  $msg = ($_ | Out-String) + [Environment]::NewLine + $_.ScriptStackTrace
  try { [System.IO.File]::WriteAllText($errFile, $msg, (New-Object System.Text.UTF8Encoding($false))) } catch { }
  Write-Host ('GUI crashed: ' + $_.Exception.Message)
  exit 1
}
