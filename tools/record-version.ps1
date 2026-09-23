<#
.SYNOPSIS
  Record the currently installed Douyin version into versions.json.

.DESCRIPTION
  Run this AFTER you have enabled the patch on a Douyin version and personally
  verified that videos play at the highest clarity. It appends/updates an entry
  in versions.json so the tool can report that version as "verified" later.

  It records the official hashes (from the install folder's md5.json), the
  preload.js size, the md5.json entry count and the Electron version, so the
  entry can act as a fingerprint for that exact build.

.PARAMETER Status
  verified (default, you tested it) | compatible (did not test) | unsupported

.PARAMETER Yes
  Skip the confirmation prompt.

.EXAMPLE
  pwsh -File D:\Code\dy\tools\record-version.ps1
#>
[CmdletBinding()]
param(
  [string]$DouyinDir = 'D:\douyin',
  [string]$ProjectDir = 'D:\Code\dy',
  [ValidateSet('verified', 'compatible', 'unsupported')]
  [string]$Status = 'verified',
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'

function Title($m) { Write-Host ''; Write-Host ('=' * 60) -ForegroundColor DarkCyan; Write-Host "  $m" -ForegroundColor Cyan; Write-Host ('=' * 60) -ForegroundColor DarkCyan }
function Step($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "[x] $m" -ForegroundColor Red }
function Dim($m)  { Write-Host "    $m" -ForegroundColor DarkGray }

$module = Join-Path $ProjectDir 'tools\douyin-version.ps1'
if (-not (Test-Path $module)) { Bad "missing $module"; exit 1 }
. $module

Title 'RECORD DOUYIN VERSION'

$before = Get-DouyinVersionInfo -InstallRoot $DouyinDir -ProjectDir $ProjectDir
if (-not $before.Version) { Bad ('could not determine the Douyin version: ' + $before.Label); exit 1 }

Step 'Current installation'
Dim ('install root   : ' + $DouyinDir)
Dim ('douyin version : ' + $before.Version)
Dim ('tool version   : ' + $before.ToolVersion)
Dim ('patch applied  : ' + $before.IsPatched)
Dim ('pristine md5   : ' + $before.PristineMd5)
if ($before.Official) { Dim ('md5.json items : ' + $before.Official.entries) }

if (-not $before.IsPatched) {
  Warn 'The patch does not appear to be applied. Record anyway? (usually you record AFTER a successful test)'
}

if (-not $Yes) {
  Write-Host ''
  Write-Host ("Record version {0} as '{1}'? [y/N] " -f $before.Version, $Status) -NoNewline
  $ans = Read-Host
  if ($ans -notmatch '^(y|Y)') { Warn 'cancelled'; exit 0 }
}

Step 'Writing versions.json'
$entry = Add-DouyinVersionRecord -InstallRoot $DouyinDir -ProjectDir $ProjectDir -Status $Status
Ok ('recorded ' + $entry.version + ' as ' + $entry.status)
Dim ('app.asar md5 : ' + $entry.md5.appAsar)
Dim ('preload  md5 : ' + $entry.md5.preload)
Dim ('pristine size: ' + $entry.signatures.pristinePreloadSize)
Dim ('md5.json     : ' + $entry.signatures.md5JsonEntries + ' items')
if ($entry.electronVersion) { Dim ('electron     : ' + $entry.electronVersion) }

Write-Host ''
Step 'Versions now recorded'
$mf = Get-VersionManifest $ProjectDir
$mf.versions | ForEach-Object {
  Write-Host ('  ' + $_.version.PadRight(10) + $_.status.PadRight(14) + 'tested ' + $_.testedAt) -ForegroundColor Gray
}
Write-Host ''
Ok 'done - the GUI and CLI will now report this version accordingly'
