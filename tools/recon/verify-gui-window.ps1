Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WE2 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static List<string> List() {
    var res = new List<string>();
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var sb = new StringBuilder(512);
      GetWindowTextW(h, sb, 512);
      string t = sb.ToString();
      if (t.Length == 0) return true;
      uint pid; GetWindowThreadProcessId(h, out pid);
      RECT r; GetWindowRect(h, out r);
      res.Add(h.ToInt64() + "|" + pid + "|" + (r.R-r.L) + "|" + (r.B-r.T) + "|" + t);
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
"@

# 找 GUI 进程
$guiPids = @()
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | ForEach-Object {
  if ($_.CommandLine -like '*douyin-quality-gui*') { $guiPids += [int]$_.ProcessId }
}
Write-Output ("GUI pids: " + ($guiPids -join ','))

$found = $null
foreach ($w in [WE2]::List()) {
  $p = $w -split '\|', 5
  if ($guiPids -contains [int]$p[1]) { $found = $p; break }
}

if (-not $found) { Write-Output 'VERDICT: NO WINDOW for the GUI process'; exit 1 }

Write-Output ("window pid  : " + $found[1])
Write-Output ("window size : " + $found[2] + "x" + $found[3])
Write-Output ("window title: " + $found[4])

$h = [IntPtr][int64]$found[0]
$r = New-Object WE2+RECT
[void][WE2]::GetWindowRect($h, [ref]$r)
$w = [int]$found[2]; $ht = [int]$found[3]
[void][WE2]::SetForegroundWindow($h)
Start-Sleep -Milliseconds 700
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$g.Dispose()
$colors = @{}
for ($y = 0; $y -lt $ht; $y += 4) { for ($x = 0; $x -lt $w; $x += 4) { $c = $bmp.GetPixel($x,$y); $colors["$($c.R),$($c.G),$($c.B)"] = 1 } }
$bmp.Save('D:\Code\dy\work\gui-window.png', [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("distinct colors: " + $colors.Count)
if ($colors.Count -gt 15) { Write-Output 'VERDICT: window rendered with content (OK)' } else { Write-Output 'VERDICT: looks blank (BAD)' }
