# Build the single-file WPF EXE with the system C# compiler (no NuGet).
# Output: dist\抖音画质助手.exe
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'exe-src'
$dist = Join-Path $root 'dist'
# ASCII output name avoids encoding issues with csc.exe; we rename after build.
$out  = Join-Path $dist 'douyin-quality-helper.exe'

New-Item -ItemType Directory -Force -Path $dist | Out-Null

# Refresh embedded resources from the authoritative sources
Copy-Item (Join-Path $root 'injector\payload.js') (Join-Path $src 'Resources\payload.js') -Force
Copy-Item (Join-Path $root 'versions.json')       (Join-Path $src 'Resources\versions.json') -Force

$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found: $csc" }

$refAsm = 'C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8'
if (-not (Test-Path (Join-Path $refAsm 'PresentationFramework.dll'))) {
  throw "WPF reference assemblies not found under: $refAsm"
}

$refs = @(
  'System',
  'System.Core',
  'System.Xaml',
  'System.Xml',
  'System.Web.Extensions',
  'System.Windows.Forms',
  'PresentationCore',
  'PresentationFramework',
  'WindowsBase',
  'Microsoft.CSharp'
)

$files = Get-ChildItem -Path $src -Filter '*.cs' | ForEach-Object { $_.FullName }

$refArgs = @("/lib:`"$refAsm`"")
foreach ($r in $refs) { $refArgs += "/reference:$r.dll" }

$resourceArgs = @(
  ('/resource:{0},DouyinQualityHelper.Resources.payload.js' -f (Join-Path $src 'Resources\payload.js')),
  ('/resource:{0},DouyinQualityHelper.Resources.versions.json' -f (Join-Path $src 'Resources\versions.json')),
  ('/resource:{0},DouyinQualityHelper.Resources.MainWindow.xaml' -f (Join-Path $src 'MainWindow.xaml'))
)

$argList = @(
  '/nologo',
  '/target:winexe',
  '/platform:anycpu',
  '/optimize+',
  '/debug-',
  '/utf8output',
  ('/out:{0}' -f $out)
) + $refArgs + $resourceArgs + $files

Write-Host "Compiling $($files.Count) source files..."
& $csc @argList
if ($LASTEXITCODE -ne 0) { throw "csc failed with exit code $LASTEXITCODE" }

$fi = Get-Item $out
Write-Host ("OK  {0}  ({1:N0} bytes)" -f $fi.FullName, $fi.Length)
