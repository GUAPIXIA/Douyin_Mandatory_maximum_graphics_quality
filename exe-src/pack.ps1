# Package the portable single-EXE distribution into dist\
# ASCII-only source (see project encoding rules).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $root 'exe-src\build.ps1')

$dist = Join-Path $root 'dist'
$ascii = Join-Path $dist 'douyin-quality-helper.exe'

# Build display name from code points: U+6296 U+97F3 U+753B U+8D28 U+52A9 U+624B + ".exe"
$codes = 0x6296, 0x97F3, 0x753B, 0x8D28, 0x52A9, 0x624B
$chars = New-Object System.Collections.Generic.List[char]
foreach ($c in $codes) { $chars.Add([char]$c) }
$cnName = (-join $chars) + '.exe'
$cnPath = Join-Path $dist $cnName

Copy-Item $ascii $cnPath -Force

Remove-Item (Join-Path $dist 'selftest.txt') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $dist 'patch-error.txt') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $dist 'versions.json') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $dist 'config.json') -ErrorAction SilentlyContinue

Write-Host 'Packaged:'
Get-ChildItem $dist | ForEach-Object { Write-Host ('  {0}  {1:N0} bytes' -f $_.Name, $_.Length) }
Write-Host ''
Write-Host ('Users only need the folder contents. Double-click ' + $cnName)
