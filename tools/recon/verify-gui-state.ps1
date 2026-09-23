Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

# 找到窗口（标题：抖音画质助手），用 UI Automation 读取按钮是否可点
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::NameProperty, '抖音画质助手')
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)

if (-not $win) { Write-Output 'WINDOW-NOT-FOUND'; exit 1 }
Write-Output ('window found: ' + $win.Current.Name)

# 找所有按钮
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button)
$buttons = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
Write-Output ('buttons: ' + $buttons.Count)
foreach ($b in $buttons) {
  Write-Output ('  [' + $(if ($b.Current.IsEnabled) { '可点' } else { '禁用' }) + '] ' + $b.Current.Name)
}

# 找所有可读文本，确认路径框提示
$txtCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Text)
$texts = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $txtCond)
$names = @()
foreach ($t in $texts) { if ($t.Current.Name) { $names += $t.Current.Name } }
Write-Output ''
Write-Output ('texts found: ' + $names.Count)
$interesting = $names | Where-Object { $_ -match '尚未选择|请选择|浏览|第一步|一键启用|还原|检查' } | Select-Object -Unique
foreach ($n in $interesting) { Write-Output ('  ' + $n) }

# 判定
$installBtn = $buttons | Where-Object { $_.Current.Name -match '一键启用' } | Select-Object -First 1
$browseBtn = $buttons | Where-Object { $_.Current.Name -match '浏览' } | Select-Object -First 1
$hasNotChosen = ($names -join '|') -match '尚未选择'

Write-Output ''
if ($installBtn -and -not $installBtn.Current.IsEnabled -and $browseBtn -and $browseBtn.Current.IsEnabled -and $hasNotChosen) {
  Write-Output 'VERDICT: OK - path not chosen, Enable is disabled, Browse is enabled'
} elseif ($installBtn -and $installBtn.Current.IsEnabled) {
  Write-Output 'VERDICT: BAD - Enable is clickable before choosing douyin.exe'
} else {
  Write-Output 'VERDICT: partial - inspect the output above'
}
