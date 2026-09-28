using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;

namespace DouyinQualityHelper
{
    /// <summary>
    /// UI controller. The visual tree is loaded from embedded XAML at runtime,
    /// so this class does not depend on MSBuild-generated InitializeComponent.
    /// </summary>
    public sealed class MainWindow
    {
        Window _win;
        TextBlock StatusIcon, StatusText, StatusDetail, RunBadge, ToolVersionText;
        TextBlock VersionValue, PreloadValue, AsarValue, BackupValue;
        TextBox PathBox, LogBox;
        TextBlock FootText;
        Button BtnBrowse, BtnInstall, BtnRestore, BtnCheck, BtnRefresh;

        string _installRoot;
        string _hintDir;
        VersionInfo _versionInfo;

        public void Bind(Window win)
        {
            _win = win;
            StatusIcon = win.FindName("StatusIcon") as TextBlock;
            StatusText = win.FindName("StatusText") as TextBlock;
            StatusDetail = win.FindName("StatusDetail") as TextBlock;
            RunBadge = win.FindName("RunBadge") as TextBlock;
            ToolVersionText = win.FindName("ToolVersionText") as TextBlock;
            VersionValue = win.FindName("VersionValue") as TextBlock;
            PreloadValue = win.FindName("PreloadValue") as TextBlock;
            AsarValue = win.FindName("AsarValue") as TextBlock;
            BackupValue = win.FindName("BackupValue") as TextBlock;
            PathBox = win.FindName("PathBox") as TextBox;
            LogBox = win.FindName("LogBox") as TextBox;
            FootText = win.FindName("FootText") as TextBlock;
            BtnBrowse = win.FindName("BtnBrowse") as Button;
            BtnInstall = win.FindName("BtnInstall") as Button;
            BtnRestore = win.FindName("BtnRestore") as Button;
            BtnCheck = win.FindName("BtnCheck") as Button;
            BtnRefresh = win.FindName("BtnRefresh") as Button;

            if (StatusIcon == null || BtnInstall == null || LogBox == null)
                throw new InvalidOperationException("gui xaml missing named controls");

            BtnBrowse.Click += (s, e) => InvokeBrowse();
            BtnInstall.Click += (s, e) => InvokeInstall();
            BtnRestore.Click += (s, e) => InvokeRestore();
            BtnCheck.Click += (s, e) => InvokeCheck();
            BtnRefresh.Click += (s, e) =>
            {
                LogBox.Clear();
                WriteLog("状态已刷新。");
                UpdateVersionInfo(_installRoot);
                UpdateView();
            };
        }

        public void OnLoadedInternal()
        {
            try
            {
                AppPaths.EnsureVersionsFile();
                string toolVer = "v" + VersionChecker.GetToolVersion();
                if (ToolVersionText != null) ToolVersionText.Text = toolVer;
                if (FootText != null) FootText.Text = "数据目录：" + AppPaths.AppDir + "  ｜  " + toolVer + "  ｜  无需 Node.js";

                WriteLog("工具已就绪。请先点「浏览…」选择 douyin.exe。");
                string hint = DouyinLocator.FindHintDir();
                if (hint != null)
                {
                    _hintDir = hint;
                    WriteLog("检测到抖音可能在：" + hint);
                    WriteLog("请点「浏览…」选中 douyin.exe 以确认。");
                }
                else
                {
                    WriteLog("未能自动找到抖音，请用「浏览…」手动定位。", "warn");
                }

                SetInstallRoot(null, false);
                SetStatus("?", "请先选择抖音程序", "点下面的「浏览…」，选中抖音安装目录里的 douyin.exe", "#D25F00");
                UpdateView();
                WriteLog("提示：douyin.exe 通常在 <抖音安装目录>\\douyin.exe");
            }
            catch (Exception ex)
            {
                WriteLog("启动出错：" + ex.Message, "err");
            }
        }

        void WriteLog(string msg, string level = "info")
        {
            string ts = DateTime.Now.ToString("HH:mm:ss");
            string prefix = level == "ok" ? "[ OK ]"
                : level == "warn" ? "[WARN]"
                : level == "err" ? "[FAIL]"
                : "[INFO]";
            LogBox.AppendText("[" + ts + "] " + prefix + " " + msg + Environment.NewLine);
            LogBox.ScrollToEnd();
        }

        void SetStatus(string icon, string text, string detail, string color)
        {
            StatusIcon.Text = icon;
            StatusText.Text = text;
            try { StatusText.Foreground = (SolidColorBrush)new BrushConverter().ConvertFromString(color); }
            catch { StatusText.Foreground = Brushes.Black; }
            StatusDetail.Text = detail ?? "";
        }

        void SetBusy(bool busy)
        {
            _win.Cursor = busy ? System.Windows.Input.Cursors.Wait : System.Windows.Input.Cursors.Arrow;
            BtnInstall.IsEnabled = !busy;
            BtnRestore.IsEnabled = !busy;
            BtnCheck.IsEnabled = !busy;
            BtnRefresh.IsEnabled = !busy;
            BtnBrowse.IsEnabled = !busy;
        }

        void SetInstallRoot(string root, bool persist)
        {
            _installRoot = root;
            if (persist && !string.IsNullOrEmpty(root)) Config.SaveDouyinDir(root);
            UpdateVersionInfo(root);
            PathBox.Text = string.IsNullOrEmpty(root) ? "尚未选择" : root;
        }

        void UpdateVersionInfo(string root)
        {
            _versionInfo = null;
            if (string.IsNullOrEmpty(root)) return;
            try { _versionInfo = VersionChecker.GetInfo(root); }
            catch (Exception ex) { WriteLog("版本检查失败：" + ex.Message, "warn"); }
        }

        void UpdateView()
        {
            if (string.IsNullOrEmpty(_installRoot))
            {
                SetStatus("?", "请先选择抖音程序", "点下面的「浏览…」，选中抖音安装目录里的 douyin.exe", "#D25F00");
                BtnInstall.IsEnabled = false;
                BtnRestore.IsEnabled = false;
                BtnCheck.IsEnabled = false;
                BtnBrowse.IsEnabled = true;
                if (string.IsNullOrEmpty(PathBox.Text)) PathBox.Text = "尚未选择";
                VersionValue.Text = "待选择（选好后自动识别）";
                VersionValue.Foreground = new SolidColorBrush(Color.FromRgb(0x86, 0x90, 0x9C));
                PreloadValue.Text = "-";
                AsarValue.Text = "-";
                BackupValue.Text = "-";
                RunBadge.Text = "未就绪";
                return;
            }

            InstallPaths p;
            try { p = DouyinLocator.GetInstallPaths(_installRoot); }
            catch (Exception ex)
            {
                SetStatus("!", "抖音目录有问题", ex.Message, "#C0392B");
                BtnInstall.IsEnabled = false;
                BtnRestore.IsEnabled = false;
                BtnCheck.IsEnabled = false;
                return;
            }

            string curMd5 = HashUtil.GetMd5(p.Preload);
            bool patched = false;
            if (File.Exists(p.Preload))
            {
                try { patched = Patcher.HasMark(File.ReadAllText(p.Preload, Encoding.UTF8)); }
                catch { }
            }

            if (_versionInfo != null)
            {
                VersionValue.Text = _versionInfo.Label;
                VersionValue.Foreground = StatusColor(_versionInfo.Status);
                if (_versionInfo.IsPatched || patched)
                {
                    PreloadValue.Text = "已启用最高画质补丁";
                    PreloadValue.Foreground = new SolidColorBrush(Color.FromRgb(0x00, 0xB4, 0x2A));
                    SetStatus("✓", "最高画质已启用", "启动抖音看视频即可；没有 4K 的会自动降档。", "#00B42A");
                }
                else if (curMd5 == Patcher.ORIG_PRELOAD_MD5 || curMd5 == _versionInfo.PristineMd5)
                {
                    PreloadValue.Text = "官方原版（未启用补丁）";
                    PreloadValue.Foreground = new SolidColorBrush(Color.FromRgb(0x1D, 0x21, 0x29));
                    SetStatus("○", "尚未启用最高画质", "退出抖音后点「① 一键启用最高画质」。", "#165DFF");
                }
                else
                {
                    PreloadValue.Text = "文件与原版不一致（非本工具标记）";
                    PreloadValue.Foreground = new SolidColorBrush(Color.FromRgb(0xFF, 0x7D, 0x00));
                    SetStatus("!", "检测到未知修改", "建议先还原官方原版，再启用补丁。", "#D25F00");
                }
            }
            else
            {
                VersionValue.Text = Path.GetFileName(_installRoot.TrimEnd('\\'));
                PreloadValue.Text = patched ? "已启用补丁" : "未启用";
            }

            if (File.Exists(p.Asar))
            {
                string sha = HashUtil.GetSha256(p.Asar);
                AsarValue.Text = "sha256 " + (sha.Length >= 12 ? sha.Substring(0, 12) : sha) + "…（未改动）";
            }
            else AsarValue.Text = "未找到 app.asar";

            bool hasBackup = File.Exists(AppPaths.OrigPreload) &&
                             HashUtil.GetMd5(AppPaths.OrigPreload) == Patcher.ORIG_PRELOAD_MD5;
            BackupValue.Text = hasBackup ? "已固化（可一键还原）" : "尚未固化（首次启用时自动备份）";
            BackupValue.Foreground = hasBackup
                ? new SolidColorBrush(Color.FromRgb(0x00, 0xB4, 0x2A))
                : new SolidColorBrush(Color.FromRgb(0x86, 0x90, 0x9C));

            bool canInstall = _versionInfo == null || _versionInfo.IsSupported;
            BtnInstall.IsEnabled = canInstall;
            BtnRestore.IsEnabled = true;
            BtnCheck.IsEnabled = File.Exists(AppPaths.PageLog);
            BtnBrowse.IsEnabled = true;

            bool running = DouyinLocator.IsDouyinRunning();
            RunBadge.Text = running ? "抖音运行中" : "抖音未运行";
            RunBadge.Foreground = running
                ? new SolidColorBrush(Color.FromRgb(0x00, 0xB4, 0x2A))
                : new SolidColorBrush(Color.FromRgb(0x86, 0x90, 0x9C));

            if (_versionInfo != null && !_versionInfo.IsSupported)
            {
                SetStatus("×", "此抖音版本不受支持", _versionInfo.Detail, "#C0392B");
                BtnInstall.IsEnabled = false;
            }
        }

        static SolidColorBrush StatusColor(string status)
        {
            switch (status)
            {
                case "verified": return new SolidColorBrush(Color.FromRgb(0x00, 0xB4, 0x2A));
                case "unsupported": return new SolidColorBrush(Color.FromRgb(0xC0, 0x39, 0x2B));
                default: return new SolidColorBrush(Color.FromRgb(0xFF, 0x7D, 0x00));
            }
        }

        void InvokeBrowse()
        {
            var dlg = new OpenFileDialog
            {
                Title = "请选择抖音程序 douyin.exe",
                Filter = "douyin.exe|douyin.exe|可执行文件 (*.exe)|*.exe|所有文件 (*.*)|*.*",
                CheckFileExists = true,
                Multiselect = false
            };
            string hint = _installRoot ?? _hintDir;
            if (!string.IsNullOrEmpty(hint) && Directory.Exists(hint)) dlg.InitialDirectory = hint;

            if (dlg.ShowDialog(_win) != true)
            {
                WriteLog("已取消选择。", "warn");
                return;
            }

            string picked = dlg.FileName;
            WriteLog("已选择：" + picked);
            if (!Regex.IsMatch(Path.GetFileName(picked), @"^douyin.*\.exe$", RegexOptions.IgnoreCase))
                WriteLog("注意：文件名不叫 douyin.exe，继续尝试识别所在目录。", "warn");

            string root = DouyinLocator.ResolveInstallRoot(picked);
            if (root == null)
            {
                WriteLog("该文件不在抖音安装目录里，无法识别。", "err");
                MessageBox.Show(_win,
                    "该文件不在抖音安装目录中，无法识别。\n\n请选择抖音安装目录里的 douyin.exe，例如：\n  D:\\douyin\\douyin.exe\n  C:\\Program Files\\douyin\\douyin.exe",
                    "位置不正确", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            SetInstallRoot(root, true);
            WriteLog("已确认抖音位置：" + root, "ok");
            WriteLog("接下来：退出抖音 → 点「① 一键启用最高画质」");
            UpdateView();
        }

        void InvokeInstall()
        {
            LogBox.Clear();
            WriteLog("开始启用最高画质…");
            if (string.IsNullOrEmpty(_installRoot))
            {
                WriteLog("尚未选择抖音位置，请先点「浏览…」。", "err");
                return;
            }

            InstallPaths p;
            try { p = DouyinLocator.GetInstallPaths(_installRoot); }
            catch (Exception ex) { WriteLog(ex.Message, "err"); return; }

            if (DouyinLocator.IsDouyinRunning())
            {
                WriteLog("抖音正在运行，请先完全退出。", "err");
                MessageBox.Show(_win,
                    "抖音还在运行。\n\n请在右下角托盘图标上右键 → 退出，并在任务管理器确认 douyin.exe 已消失，然后再点一次。",
                    "请先退出抖音", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            SetBusy(true);
            try
            {
                WriteLog("使用安装目录：" + _installRoot);
                WriteLog("检查原始文件备份…");
                Directory.CreateDirectory(Path.GetDirectoryName(AppPaths.OrigPreload));
                bool haveOrig = HashUtil.GetMd5(AppPaths.OrigPreload) == Patcher.ORIG_PRELOAD_MD5;

                if (haveOrig)
                {
                    WriteLog("原始备份已固化并通过校验。", "ok");
                }
                else if (HashUtil.GetMd5(p.Preload) == Patcher.ORIG_PRELOAD_MD5)
                {
                    File.Copy(p.Preload, AppPaths.OrigPreload, true);
                    haveOrig = true;
                    WriteLog("已创建原始文件备份。", "ok");
                }
                else
                {
                    WriteLog("文件已被修改，尝试剥离本工具的标记以还原原始内容…", "warn");
                    string txt = File.ReadAllText(p.Preload, Encoding.UTF8);
                    string stripped;
                    if (Patcher.TryStrip(txt, out stripped))
                    {
                        Directory.CreateDirectory(AppPaths.BuildDir);
                        string tmp = Path.Combine(AppPaths.BuildDir, "recovered-orig.js");
                        File.WriteAllText(tmp, stripped, new UTF8Encoding(false));
                        if (HashUtil.GetMd5(tmp) == Patcher.ORIG_PRELOAD_MD5)
                        {
                            File.Copy(tmp, AppPaths.OrigPreload, true);
                            haveOrig = true;
                            WriteLog("原始文件已成功恢复。", "ok");
                        }
                    }
                }

                if (!haveOrig)
                {
                    WriteLog("无法取得官方原始文件，已中止。", "err");
                    MessageBox.Show(_win,
                        "无法取得官方原始文件，因此没有做任何修改。\n\n请重新安装抖音客户端后再试。",
                        "启用失败", MessageBoxButton.OK, MessageBoxImage.Error);
                    return;
                }

                WriteLog("生成注入文件…");
                string payload = AppPaths.ReadEmbeddedText("payload.js");
                string built = Path.Combine(AppPaths.BuildDir, "gui-patched.js");
                Directory.CreateDirectory(AppPaths.BuildDir);
                string original = File.ReadAllText(AppPaths.OrigPreload, Encoding.UTF8);
                string patched = Patcher.PatchText(original, payload);
                File.WriteAllText(built, patched, new UTF8Encoding(false));
                WriteLog(string.Format("生成成功（{0:N0} 字节）", new FileInfo(built).Length), "ok");

                WriteLog("写入抖音目录…");
                string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
                string snap = Path.Combine(AppPaths.BackupDir, stamp);
                Directory.CreateDirectory(snap);
                File.Copy(p.Preload, Path.Combine(snap, "preload.js.before"), true);
                File.Copy(built, p.Preload, true);
                WriteLog("已写入（md5 " + HashUtil.GetMd5(p.Preload).Substring(0, 8) + "）", "ok");

                try
                {
                    if (File.Exists(AppPaths.PageLog)) File.Delete(AppPaths.PageLog);
                    string mainLog = Path.Combine(AppPaths.UserData, "dy-force-main.log");
                    if (File.Exists(mainLog)) File.Delete(mainLog);
                }
                catch { }

                if (File.Exists(AppPaths.AsarOrig) &&
                    HashUtil.GetSha256(p.Asar) != HashUtil.GetSha256(AppPaths.AsarOrig))
                {
                    File.Copy(AppPaths.AsarOrig, p.Asar, true);
                    WriteLog("app.asar 已还原为官方版本。", "ok");
                }

                try
                {
                    Directory.CreateDirectory(AppPaths.BackupDir);
                    var meta = new System.Collections.Generic.Dictionary<string, object>
                    {
                        { "timestamp", DateTime.Now.ToString("o") },
                        { "versionDir", p.VersionDir },
                        { "targetFile", p.Preload },
                        { "origMd5", Patcher.ORIG_PRELOAD_MD5 },
                        { "newMd5", HashUtil.GetMd5(p.Preload) },
                        { "pristinePath", AppPaths.OrigPreload },
                        { "payload", "embedded" },
                        { "installedBy", "exe" },
                        { "douyinVersion", _versionInfo != null ? _versionInfo.Version : "" },
                        { "toolVersion", _versionInfo != null ? _versionInfo.ToolVersion : VersionChecker.GetToolVersion() }
                    };
                    File.WriteAllText(Path.Combine(AppPaths.BackupDir, "deploy-meta.json"),
                        JsonUtil.Serialize(meta), new UTF8Encoding(false));
                    File.WriteAllText(Path.Combine(AppPaths.BackupDir, "LATEST"), stamp, new UTF8Encoding(false));
                    WriteLog("还原元数据已写入 backup\\deploy-meta.json。", "ok");
                }
                catch (Exception ex)
                {
                    WriteLog("无法写入还原元数据：" + ex.Message, "warn");
                }

                WriteLog("完成。现在可以启动抖音了。", "ok");
                MessageBox.Show(_win,
                    "最高画质已启用。\n\n接下来：\n  1. 正常启动抖音\n  2. 打开任意支持 4K 的视频\n  3. 清晰度会直接是 4K\n\n没有 4K 的视频会自动降为 2K 或 1080P。",
                    "已启用", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                WriteLog("启用出错：" + ex.Message, "err");
                MessageBox.Show(_win, "启用出错：\n\n" + ex.Message, "出错", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                SetBusy(false);
                UpdateView();
            }
        }

        void InvokeRestore()
        {
            LogBox.Clear();
            WriteLog("开始还原…");
            if (string.IsNullOrEmpty(_installRoot))
            {
                WriteLog("尚未选择抖音位置。", "err");
                return;
            }

            InstallPaths p;
            try { p = DouyinLocator.GetInstallPaths(_installRoot); }
            catch (Exception ex) { WriteLog(ex.Message, "err"); return; }

            if (DouyinLocator.IsDouyinRunning())
            {
                WriteLog("抖音正在运行，请先退出。", "err");
                MessageBox.Show(_win, "请先从托盘完全退出抖音。", "请先退出抖音", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var ans = MessageBox.Show(_win,
                "要还原成抖音官方原版吗？\n\n最高画质强制将停止（以后可以再启用）。",
                "确认还原", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (ans != MessageBoxResult.Yes)
            {
                WriteLog("已取消还原。");
                return;
            }

            SetBusy(true);
            try
            {
                if (HashUtil.GetMd5(AppPaths.OrigPreload) != Patcher.ORIG_PRELOAD_MD5)
                    throw new InvalidOperationException("原始备份缺失或校验失败，拒绝还原。");

                File.Copy(AppPaths.OrigPreload, p.Preload, true);
                if (HashUtil.GetMd5(p.Preload) != Patcher.ORIG_PRELOAD_MD5)
                    throw new InvalidOperationException("还原后校验失败");
                WriteLog("preload.js 已还原为官方原版。", "ok");

                if (File.Exists(AppPaths.AsarOrig) &&
                    HashUtil.GetSha256(p.Asar) != HashUtil.GetSha256(AppPaths.AsarOrig))
                {
                    File.Copy(AppPaths.AsarOrig, p.Asar, true);
                    WriteLog("app.asar 已还原为官方原版。", "ok");
                }

                foreach (var n in new[] { "dy-force.log", "dy-force-main.log" })
                {
                    string f = Path.Combine(AppPaths.UserData, n);
                    if (File.Exists(f)) File.Delete(f);
                }

                WriteLog("还原完成，抖音已回到官方状态。", "ok");
                MessageBox.Show(_win, "已还原为官方原版。", "还原完成", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                WriteLog("还原出错：" + ex.Message, "err");
                MessageBox.Show(_win, "还原出错：\n\n" + ex.Message, "出错", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                SetBusy(false);
                UpdateView();
            }
        }

        void InvokeCheck()
        {
            LogBox.Clear();
            WriteLog("读取运行日志…");

            if (!File.Exists(AppPaths.PageLog))
            {
                WriteLog("还没有运行日志。请先启用，再打开一些视频。", "warn");
                MessageBox.Show(_win,
                    "还没有找到运行日志。\n\n请先这样做：\n  1. 退出抖音\n  2. 点「① 一键启用最高画质」\n  3. 启动抖音并打开几个视频\n  4. 回来点「③ 检查生效情况」",
                    "暂无数据", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var lines = File.ReadAllLines(AppPaths.PageLog);
            int onPage = lines.Count(l => Regex.IsMatch(l, "loose-preload .*url=https://www\\.douyin\\.com"));
            int created = lines.Count(l => l.IndexOf("[created]", StringComparison.Ordinal) >= 0);
            int forced = lines.Count(l => l.IndexOf("[forced]", StringComparison.Ordinal) >= 0);
            int skipped = lines.Count(l => l.IndexOf("[skip]", StringComparison.Ordinal) >= 0);
            int errs = lines.Count(l => Regex.IsMatch(l, "SecurityError|ERROR|error"));

            WriteLog("日志行数：" + lines.Length);
            if (onPage > 0) WriteLog("已确认注入到抖音页面。", "ok");
            else WriteLog("没有找到抖音页面注入记录。", "err");
            WriteLog("清晰度写入：created=" + created + " forced=" + forced + " kept-default=" + skipped);
            if (errs > 0) WriteLog("错误行数：" + errs, "warn");

            if (onPage > 0 && (created > 0 || forced > 0))
            {
                WriteLog("结论：工具工作正常。", "ok");
                MessageBox.Show(_win,
                    "工具工作正常。\n\n如果画面仍不像 4K，请检查：\n  - 该视频本身是否有 4K 选项\n  - 是否已登录（4K 通常需要登录）\n  - 打开清晰度菜单看当前档位",
                    "检查结果：正常", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                WriteLog("结论：暂未看到生效记录，请先打开一些视频。", "warn");
                MessageBox.Show(_win,
                    "暂未看到生效记录。\n\n请启动抖音、打开几个视频，然后再点「检查」。",
                    "检查结果：暂无数据", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
    }
}
