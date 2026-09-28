using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Markup;
using System.Xml;

namespace DouyinQualityHelper
{
    public static class Program
    {
        [DllImport("kernel32.dll")]
        static extern bool AttachConsole(int pid);

        [DllImport("kernel32.dll")]
        static extern bool AllocConsole();

        const int ATTACH_PARENT_PROCESS = -1;

        [STAThread]
        public static int Main(string[] args)
        {
            bool cli = args != null && args.Length > 0;
            if (cli)
            {
                if (!AttachConsole(ATTACH_PARENT_PROCESS)) AllocConsole();
                Console.OutputEncoding = System.Text.Encoding.UTF8;
            }

            if (cli)
            {
                string cmd = args[0].ToLowerInvariant();
                if (cmd == "--selftest" || cmd == "/selftest") return SelfTest();
                if (cmd == "--patch")
                {
                    try
                    {
                        string src = null, payload = null, output = null;
                        for (int i = 1; i < args.Length; i++)
                        {
                            if (args[i] == "--src" && i + 1 < args.Length) src = args[++i];
                            else if (args[i] == "--payload" && i + 1 < args.Length) payload = args[++i];
                            else if (args[i] == "--out" && i + 1 < args.Length) output = args[++i];
                        }
                        if (src == null || payload == null || output == null)
                        {
                            Console.Error.WriteLine("usage: --patch --src <preload.js> --payload <payload.js> --out <out.js>");
                            return 2;
                        }
                        Patcher.PatchFile(src, payload, output);
                        Console.WriteLine("[ok] wrote " + output);
                        return 0;
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine("[x] " + ex.Message);
                        try { System.IO.File.WriteAllText(System.IO.Path.Combine(AppPaths.AppDir, "patch-error.txt"), ex.ToString()); } catch { }
                        return 1;
                    }
                }
                if (cmd == "--version" || cmd == "/version")
                {
                    Console.WriteLine("douyin-quality-helper " + typeof(Program).Assembly.GetName().Version);
                    Console.WriteLine("tool " + VersionChecker.GetToolVersion());
                    return 0;
                }
            }

            var app = new Application { ShutdownMode = ShutdownMode.OnMainWindowClose };
            app.DispatcherUnhandledException += (s, e) =>
            {
                try { AppPaths.WriteCrashLog(e.Exception); } catch { }
                MessageBox.Show(
                    "程序出错了：\n\n" + e.Exception.Message + "\n\n详细信息已写入 error.log",
                    "抖音画质助手", MessageBoxButton.OK, MessageBoxImage.Error);
                e.Handled = true;
            };

            try
            {
                AppPaths.EnsureVersionsFile();
                string xaml = AppPaths.ReadEmbeddedText("MainWindow.xaml");
                xaml = xaml.Replace("x:Class=\"DouyinQualityHelper.MainWindow\"", "");
                var doc = new XmlDocument();
                doc.LoadXml(xaml);
                var win = (Window)XamlReader.Load(new XmlNodeReader(doc));
                var logic = new MainWindow();
                logic.Bind(win);
                win.Loaded += (s, e) => logic.OnLoadedInternal();
                app.Run(win);
                return 0;
            }
            catch (Exception ex)
            {
                try { AppPaths.WriteCrashLog(ex); } catch { }
                MessageBox.Show("启动失败：\n\n" + ex.Message, "抖音画质助手", MessageBoxButton.OK, MessageBoxImage.Error);
                return 1;
            }
        }

        static int _failed;
        static System.IO.StreamWriter _selftestLog;

        static void Check(string name, bool ok, string detail)
        {
            string line = (ok ? "PASS " : "FAIL ") + name + (string.IsNullOrEmpty(detail) ? "" : (" :: " + detail));
            Console.WriteLine(line);
            if (_selftestLog != null) _selftestLog.WriteLine(line);
            if (!ok) _failed++;
        }

        /// <summary>
        /// Headless checks used by the packaging script. No GUI, no Node.
        /// </summary>
        static int SelfTest()
        {
            _failed = 0;
            string logPath = System.IO.Path.Combine(AppPaths.AppDir, "selftest.txt");
            _selftestLog = new System.IO.StreamWriter(logPath, false, System.Text.Encoding.UTF8);
            try
            {
                AppPaths.EnsureVersionsFile();
                Check("versions.json", System.IO.File.Exists(AppPaths.VersionsFile), AppPaths.VersionsFile);
                string tool = VersionChecker.GetToolVersion();
                Check("tool version", !string.IsNullOrEmpty(tool), tool);

                string payload = AppPaths.ReadEmbeddedText("payload.js");
                Check("payload embedded", payload.Contains("MANUAL_SWITCH") && payload.Contains("PICK_4K"), "len=" + payload.Length);

                string xaml = AppPaths.ReadEmbeddedText("MainWindow.xaml");
                Check("xaml embedded", xaml.Contains("BtnInstall") && xaml.Contains("LogBox"), "len=" + xaml.Length);

                string orig = "/* head */\nfunction x() { return 1; }\n//# sourceMappingURL=app.js.map\n";
                string patched = Patcher.PatchText(orig, payload);
                Check("patch inserts marks", patched.Contains(Patcher.MARK_BEGIN) && patched.Contains(Patcher.MARK_END), null);
                Check("mapUrl stays last", patched.TrimEnd().EndsWith("//# sourceMappingURL=app.js.map"), null);
                string stripped;
                bool strippedOk = Patcher.TryStrip(patched, out stripped) && stripped == orig;
                Check("strip round-trip", strippedOk, null);

                Check("orig md5 constant", Patcher.ORIG_PRELOAD_MD5 == "bfcb8e31fae5a7370c5bee258ffcdfad", null);
                Check("no node dependency", true, "patcher is pure C#");
            }
            catch (Exception ex)
            {
                Console.WriteLine("FAIL exception :: " + ex.Message);
                _failed++;
            }

            string verdict = _failed == 0 ? "SELFTEST-OK" : ("SELFTEST-FAILED " + _failed);
            Console.WriteLine(verdict);
            if (_selftestLog != null)
            {
                _selftestLog.WriteLine(verdict);
                _selftestLog.Flush();
                _selftestLog.Dispose();
                _selftestLog = null;
            }
            return _failed == 0 ? 0 : 2;
        }
    }
}
