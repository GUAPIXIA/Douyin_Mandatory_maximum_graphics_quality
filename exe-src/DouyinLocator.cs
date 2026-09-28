using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace DouyinQualityHelper
{
    public static class DouyinLocator
    {
        public static bool TestInstallRoot(string dir)
        {
            if (string.IsNullOrWhiteSpace(dir)) return false;
            string cfg = Path.Combine(dir, "launcher_config.json");
            if (!File.Exists(cfg)) return false;
            try
            {
                var c = JsonUtil.AsDict(JsonUtil.Parse(File.ReadAllText(cfg, System.Text.Encoding.UTF8)));
                string cur = JsonUtil.GetString(c, "cur_path");
                if (string.IsNullOrEmpty(cur)) return false;
                string pre = Path.Combine(Path.Combine(dir, cur), "resources\\app.asar.unpacked\\preload.js");
                return File.Exists(pre);
            }
            catch { return false; }
        }

        public static string ResolveInstallRoot(string picked)
        {
            if (string.IsNullOrWhiteSpace(picked)) return null;
            var candidates = new List<string>();

            string full = picked;
            if (File.Exists(picked) || Directory.Exists(picked))
            {
                var attr = File.GetAttributes(picked);
                if ((attr & FileAttributes.Directory) == 0)
                    full = Path.GetDirectoryName(picked);
                else
                    full = picked;
            }
            candidates.Add(full);
            try { candidates.Add(Path.GetDirectoryName(full)); } catch { }

            string d = full;
            for (int i = 0; i < 4; i++)
            {
                try
                {
                    d = Path.GetDirectoryName(d);
                    if (!string.IsNullOrEmpty(d)) candidates.Add(d);
                    else break;
                }
                catch { break; }
            }

            foreach (var c in candidates)
            {
                if (TestInstallRoot(c))
                {
                    try { return Path.GetFullPath(c); }
                    catch { return c; }
                }
            }
            return null;
        }

        public static IEnumerable<string> AutoDetectCandidates()
        {
            var list = new List<string>();

            try
            {
                foreach (var p in Process.GetProcessesByName("douyin"))
                {
                    try
                    {
                        if (!string.IsNullOrEmpty(p.MainModule.FileName))
                            list.Add(Path.GetDirectoryName(p.MainModule.FileName));
                    }
                    catch { }
                }
            }
            catch { }

            foreach (var c in new[]
            {
                @"D:\douyin", @"C:\douyin", @"E:\douyin", @"F:\douyin",
                @"C:\Program Files\douyin", @"C:\Program Files (x86)\douyin",
                @"D:\Program Files\douyin", @"D:\Program Files (x86)\douyin",
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "douyin"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "douyin"),
                @"D:\software\douyin", @"D:\soft\douyin", @"D:\apps\douyin"
            })
            {
                list.Add(c);
            }

            try
            {
                foreach (var keyName in new[]
                {
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                    @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                })
                {
                    using (var k = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(keyName))
                        AddFromUninstallKey(k, list);
                }
                using (var k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"))
                    AddFromUninstallKey(k, list);
            }
            catch { }

            try
            {
                foreach (var drive in DriveInfo.GetDrives())
                {
                    if (drive.DriveType != DriveType.Fixed) continue;
                    try
                    {
                        foreach (var dir in Directory.EnumerateDirectories(drive.RootDirectory.FullName))
                        {
                            string name = Path.GetFileName(dir);
                            if (Regex.IsMatch(name, "douyin|抖音", RegexOptions.IgnoreCase))
                                list.Add(dir);
                        }
                    }
                    catch { }
                }
            }
            catch { }

            return list;
        }

        static void AddFromUninstallKey(Microsoft.Win32.RegistryKey parent, List<string> list)
        {
            if (parent == null) return;
            foreach (var subName in parent.GetSubKeyNames())
            {
                try
                {
                    using (var sk = parent.OpenSubKey(subName))
                    {
                        if (sk == null) continue;
                        string display = (sk.GetValue("DisplayName") as string) ?? "";
                        string icon = (sk.GetValue("DisplayIcon") as string) ?? "";
                        string loc = (sk.GetValue("InstallLocation") as string) ?? "";
                        string uninst = (sk.GetValue("UninstallString") as string) ?? "";
                        if (!Regex.IsMatch(display + " " + icon, "douyin", RegexOptions.IgnoreCase)) continue;
                        if (!string.IsNullOrEmpty(loc)) list.Add(loc);
                        if (!string.IsNullOrEmpty(icon))
                        {
                            string ic = icon.Split(',')[0].Trim().Trim('"');
                            if (File.Exists(ic)) list.Add(Path.GetDirectoryName(ic));
                        }
                        if (!string.IsNullOrEmpty(uninst))
                        {
                            string us = uninst.Split(' ')[0].Trim().Trim('"');
                            if (File.Exists(us)) list.Add(Path.GetDirectoryName(us));
                        }
                    }
                }
                catch { }
            }
        }

        public static string FindHintDir()
        {
            foreach (var c in AutoDetectCandidates())
            {
                string r = ResolveInstallRoot(c);
                if (r != null) return r;
            }
            return null;
        }

        public static bool IsDouyinRunning()
        {
            foreach (var name in new[] { "douyin", "douyin_guard", "parfait_crash_handler" })
            {
                if (Process.GetProcessesByName(name).Length > 0) return true;
            }
            return false;
        }

        public static InstallPaths GetInstallPaths(string root)
        {
            if (!TestInstallRoot(root)) throw new InvalidOperationException("不是有效的抖音安装目录：" + root);
            var cfg = JsonUtil.AsDict(JsonUtil.Parse(File.ReadAllText(Path.Combine(root, "launcher_config.json"), System.Text.Encoding.UTF8)));
            string ver = JsonUtil.GetString(cfg, "cur_path");
            string versionDir = Path.Combine(root, ver);
            return new InstallPaths
            {
                Root = root,
                VersionDir = versionDir,
                Preload = Path.Combine(versionDir, "resources\\app.asar.unpacked\\preload.js"),
                Asar = Path.Combine(versionDir, "resources\\app.asar"),
                Md5Json = Path.Combine(versionDir, "md5.json"),
                LauncherConfig = Path.Combine(root, "launcher_config.json")
            };
        }
    }
}
