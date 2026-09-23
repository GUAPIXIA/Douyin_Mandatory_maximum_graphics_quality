# =============================================================================
# 抖音版本兼容性检查（唯一实现，供 GUI 与 CLI 共用）
#
# 依赖 versions.json（唯一数据源）。本文件不含任何中文字符串字面量，
# 因为 Windows PowerShell 5.1 会因编码问题解析失败 —— 返回的消息用英文，
# 由调用方决定如何显示。
#
# 用法：
#   . "$ProjectDir\tools\douyin-version.ps1"
#   $v = Get-DouyinVersionInfo -InstallRoot 'D:\douyin'
#   $v.Version / $v.Status / $v.Summary
# =============================================================================

function Get-HashHexV([string]$path, [string]$algo) {
  $fs = $null
  try {
    $fs = [System.IO.File]::OpenRead($path)
    $h = [System.Security.Cryptography.HashAlgorithm]::Create($algo)
    return [System.BitConverter]::ToString($h.ComputeHash($fs)).Replace('-', '').ToLower()
  } finally {
    if ($fs) { $fs.Dispose() }
  }
}

function Get-VersionManifest([string]$ProjectDir) {
  $f = Join-Path $ProjectDir 'versions.json'
  if (-not (Test-Path $f)) { return $null }
  try { return (Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

# 从 md5.json 里取官方哈希（这是判断"我们改没改过"的权威依据）
function Get-OfficialHashes([string]$versionDir) {
  $f = Join-Path $versionDir 'md5.json'
  $out = [ordered]@{ appAsar = $null; preload = $null; entries = 0 }
  if (-not (Test-Path $f)) { return $out }
  try {
    $j = Get-Content $f -Raw | ConvertFrom-Json
    $props = $j.files.PSObject.Properties
    $out.entries = ($props | Measure-Object).Count
    foreach ($p in $props) {
      if ($p.Name -eq 'resources\app.asar') { $out.appAsar = $p.Value }
      elseif ($p.Name -eq 'resources\app.asar.unpacked\preload.js') { $out.preload = $p.Value }
    }
  } catch { }
  return $out
}

<#
 返回兼容性判定结果。字段：
   Version       抖音版本号（launcher_config.cur_path 的目录名）
   Status        verified / compatible / unknown / unsupported / error
   IsSupported   是否允许安装
   Label         给界面显示的一行结论
   Detail        说明
   Warnings      警告数组
   PristineMd5   preload 的原始（未打补丁）哈希：来自固化备份，缺失则用官方值
   IsPatched     当前 preload 是否已被本工具打过补丁
   Manifest      versions.json 内容（可能为 $null）
#>
function Get-DouyinVersionInfo {
  param(
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [string]$ProjectDir = 'D:\Code\dy'
  )

  $r = [ordered]@{
    Version      = ''
    ToolVersion  = ''
    Status       = 'error'
    IsSupported  = $false
    Label        = ''
    Detail       = ''
    Warnings     = @()
    PristineMd5  = ''
    IsPatched    = $false
    Official     = $null
    Manifest     = $null
  }

  $manifest = Get-VersionManifest $ProjectDir
  $r.Manifest = $manifest
  if ($manifest -and $manifest.tool) { $r.ToolVersion = [string]$manifest.tool.version }

  # --- 定位版本目录 ---
  $cfgFile = Join-Path $InstallRoot 'launcher_config.json'
  if (-not (Test-Path $cfgFile)) {
    $r.Label = 'Douyin install folder not recognised'
    $r.Detail = "launcher_config.json not found under $InstallRoot"
    return [pscustomobject]$r
  }
  try { $cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json } catch {
    $r.Label = 'launcher_config.json is unreadable'
    return [pscustomobject]$r
  }
  $ver = [string]$cfg.cur_path
  if (-not $ver) { $r.Label = 'cur_path missing in launcher_config.json'; return [pscustomobject]$r }
  $r.Version = $ver

  $versionDir = Join-Path $InstallRoot $ver
  $preloadPath = Join-Path $versionDir 'resources\app.asar.unpacked\preload.js'
  $asarPath = Join-Path $versionDir 'resources\app.asar'
  if (-not (Test-Path $preloadPath)) {
    $r.Label = "preload.js not found for version $ver"
    $r.Detail = $preloadPath
    return [pscustomobject]$r
  }

  # --- 原始哈希：优先固化备份，其次 md5.json，最后 versions.json ---
  $pristine = Join-Path $ProjectDir 'backup\loose-preload\preload.js.orig'
  $official = Get-OfficialHashes $versionDir
  $r.Official = $official

  $known = $null
  if ($manifest) {
    $known = $manifest.versions | Where-Object { $_.version -eq $ver } | Select-Object -First 1
  }

  $r.PristineMd5 = if (Test-Path $pristine) { Get-HashHexV $pristine 'MD5' }
                   elseif ($official.preload) { [string]$official.preload }
                   elseif ($known) { [string]$known.md5.preload }
                   else { '' }

  # --- 当前 preload 是否已被打过补丁 ---
  $curMd5 = Get-HashHexV $preloadPath 'MD5'
  if (-not $curMd5) {
    $r.Label = 'preload.js is unreadable'
    return [pscustomobject]$r
  }
  if ($curMd5 -ne $r.PristineMd5) {
    # 可能是补丁，也可能是别的程序改的；用标记判断
    try {
      $txt = Get-Content $preloadPath -Raw
      $r.IsPatched = ($manifest -and $txt.IndexOf([string]$manifest.injection.markBegin) -ge 0)
    } catch { }
    if (-not $r.IsPatched) {
      $r.Warnings += 'preload.js differs from the official original but carries no helper mark.'
    }
  }

  # --- 判定状态 ---
  if ($known) {
    $asmAsarMd5 = Get-HashHexV $asarPath 'MD5'
    $asarOk = (-not $known.md5.appAsar) -or ($asmAsarMd5 -eq [string]$known.md5.appAsar)

    if ($known.status -eq 'unsupported') {
      $r.Status = 'unsupported'
      $r.IsSupported = $false
      $r.Label = "Douyin $ver is marked unsupported by this tool"
      $r.Detail = '请把抖音更新到受支持的版本，或用「② 还原」后等待工具更新。'
      return [pscustomobject]$r
    }

    if (-not $asarOk) {
      $r.Status = 'compatible'
      $r.IsSupported = $true
      $r.Label = "Douyin $ver (recorded, but app.asar hash differs)"
      $r.Detail = "app.asar=$asmAsarMd5 expected=$($known.md5.appAsar)"
      $r.Warnings += 'app.asar differs from the recorded build; the layout may have changed.'
      return [pscustomobject]$r
    }

    $r.Status = 'verified'
    $r.IsSupported = $true
    $r.Label = "Douyin $ver - verified"
    $r.Detail = "实测通过（$($known.testedAt)）"
    return [pscustomobject]$r
  }

  # 清单里没有这个版本
  $policy = if ($manifest) { [string]$manifest.policy.onUnknownVersion } else { 'allow-with-warning' }
  $r.Status = 'unknown'
  $r.IsSupported = ($policy -ne 'refuse')
  $r.Label = "Douyin $ver - not in the tested list"
  $r.Detail = '结构与已知版本一致即可用；请安装后打开视频验证，并用 -Action check 确认。'
  $r.Warnings += 'This Douyin version has not been verified with this tool.'
  return [pscustomobject]$r
}

# 把当前版本登记进 versions.json（实测通过后调用）
function Add-DouyinVersionRecord {
  param(
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [string]$ProjectDir = 'D:\Code\dy',
    [string]$Status = 'verified',
    [string]$ToolVersion = ''
  )
  $manifest = Get-VersionManifest $ProjectDir
  if (-not $manifest) { throw 'versions.json not found or unreadable' }

  $cfg = Get-Content (Join-Path $InstallRoot 'launcher_config.json') -Raw | ConvertFrom-Json
  $ver = [string]$cfg.cur_path
  $versionDir = Join-Path $InstallRoot $ver
  $official = Get-OfficialHashes $versionDir

  $nat = Join-Path $env:APPDATA 'douyin\native_config'
  if (-not (Test-Path $nat)) { $nat = Join-Path $env:APPDATA 'douyin\native_config_temp' }
  $electron = ''
  if (Test-Path $nat) {
    $b = [System.IO.File]::ReadAllBytes($nat)
    $s = -join ($b | ForEach-Object { if ($_ -ge 32 -and $_ -lt 127) { [char]$_ } else { ' ' } })
    $m = [regex]::Match($s, '"electron_version"\s*:\s*"([^"]+)"')
    if ($m.Success) { $electron = $m.Groups[1].Value }
  }

  $preloadPath = Join-Path $versionDir 'resources\app.asar.unpacked\preload.js'

  # 记录【原始未打补丁】的 preload 大小：它才是可跨机比对的版本指纹。
  # 优先用固化原始备份；没有备份时若当前文件未被改动则用当前大小；否则留空。
  $pristinePath = Join-Path $ProjectDir 'backup\loose-preload\preload.js.orig'
  $curMd5 = Get-HashHexV $preloadPath 'MD5'
  $origMd5 = if ($official.preload) { [string]$official.preload } else { '' }
  $pristineSize = 0
  if (Test-Path $pristinePath) {
    $pristineSize = (Get-Item $pristinePath).Length
  } elseif ($origMd5 -and $curMd5 -eq $origMd5) {
    $pristineSize = (Get-Item $preloadPath).Length
  }

  $entry = [ordered]@{
    version   = $ver
    status    = $Status
    testedAt  = (Get-Date -Format 'yyyy-MM-dd')
    toolVersion = if ($ToolVersion) { $ToolVersion } else { [string]$manifest.tool.version }
    electronVersion = $electron
    md5 = [ordered]@{
      appAsar = if ($official.appAsar) { [string]$official.appAsar } else { Get-HashHexV (Join-Path $versionDir 'resources\app.asar') 'MD5' }
      preload = $origMd5
    }
    signatures = [ordered]@{
      pristinePreloadSize = $pristineSize
      md5JsonEntries = $official.entries
    }
    verified = @()
    knownIssues = @()
  }

  $existing = $manifest.versions | Where-Object { $_.version -eq $ver }
  if ($existing) {
    $list = @($manifest.versions | Where-Object { $_.version -ne $ver })
    $list += [pscustomobject]$entry
  } else {
    $list = @($manifest.versions) + @([pscustomobject]$entry)
  }
  $manifest.versions = $list
  [System.IO.File]::WriteAllText(
    (Join-Path $ProjectDir 'versions.json'),
    ($manifest | ConvertTo-Json -Depth 12),
    (New-Object System.Text.UTF8Encoding($false)))
  return [pscustomobject]$entry
}
