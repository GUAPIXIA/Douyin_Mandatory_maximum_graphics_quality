using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace DouyinQualityHelper
{
    public sealed class VersionInfo
    {
        public string Version = "";
        public string ToolVersion = "";
        public string Status = "error";
        public bool IsSupported;
        public string Label = "";
        public string Detail = "";
        public List<string> Warnings = new List<string>();
        public string PristineMd5 = "";
        public bool IsPatched;
        public int OfficialEntries;
        public string OfficialPreloadMd5 = "";
    }

    public static class VersionChecker
    {
        public static Dictionary<string, object> LoadManifest()
        {
            AppPaths.EnsureVersionsFile();
            try
            {
                return JsonUtil.AsDict(JsonUtil.Parse(File.ReadAllText(AppPaths.VersionsFile, Encoding.UTF8)));
            }
            catch { return null; }
        }

        public static string GetToolVersion()
        {
            var m = LoadManifest();
            var tool = JsonUtil.AsDict(JsonUtil.Get(m, "tool"));
            return JsonUtil.GetString(tool, "version");
        }

        static void ReadOfficialHashes(string versionDir, out string appAsar, out string preload, out int entries)
        {
            appAsar = null;
            preload = null;
            entries = 0;
            string f = Path.Combine(versionDir, "md5.json");
            if (!File.Exists(f)) return;
            try
            {
                var j = JsonUtil.AsDict(JsonUtil.Parse(File.ReadAllText(f, Encoding.UTF8)));
                var files = JsonUtil.AsDict(JsonUtil.Get(j, "files"));
                if (files == null) return;
                entries = files.Count;
                foreach (var kv in files)
                {
                    if (kv.Key == "resources\\app.asar") appAsar = kv.Value != null ? kv.Value.ToString() : null;
                    else if (kv.Key == "resources\\app.asar.unpacked\\preload.js") preload = kv.Value != null ? kv.Value.ToString() : null;
                }
            }
            catch { }
        }

        public static VersionInfo GetInfo(string installRoot)
        {
            var r = new VersionInfo();
            var manifest = LoadManifest();
            if (manifest != null)
            {
                var tool = JsonUtil.AsDict(JsonUtil.Get(manifest, "tool"));
                r.ToolVersion = JsonUtil.GetString(tool, "version");
            }

            string cfgFile = Path.Combine(installRoot, "launcher_config.json");
            if (!File.Exists(cfgFile))
            {
                r.Label = "抖音安装目录无法识别";
                r.Detail = "找不到 launcher_config.json：" + cfgFile;
                return r;
            }

            Dictionary<string, object> cfg;
            try { cfg = JsonUtil.AsDict(JsonUtil.Parse(File.ReadAllText(cfgFile, Encoding.UTF8))); }
            catch
            {
                r.Label = "launcher_config.json 无法解析";
                return r;
            }

            string ver = JsonUtil.GetString(cfg, "cur_path");
            if (string.IsNullOrEmpty(ver))
            {
                r.Label = "launcher_config.json 缺少 cur_path";
                return r;
            }
            r.Version = ver;

            string versionDir = Path.Combine(installRoot, ver);
            string preloadPath = Path.Combine(versionDir, "resources\\app.asar.unpacked\\preload.js");
            string asarPath = Path.Combine(versionDir, "resources\\app.asar");
            if (!File.Exists(preloadPath))
            {
                r.Label = "版本 " + ver + " 下找不到 preload.js";
                r.Detail = preloadPath;
                return r;
            }

            string officialPreload;
            string officialAsar;
            int entries;
            ReadOfficialHashes(versionDir, out officialAsar, out officialPreload, out entries);
            r.OfficialPreloadMd5 = officialPreload ?? "";
            r.OfficialEntries = entries;

            Dictionary<string, object> known = null;
            if (manifest != null)
            {
                var versions = JsonUtil.Get(manifest, "versions") as object[];
                if (versions != null)
                {
                    foreach (var item in versions)
                    {
                        var d = JsonUtil.AsDict(item);
                        if (d != null && JsonUtil.GetString(d, "version") == ver) { known = d; break; }
                    }
                }
            }

            if (File.Exists(AppPaths.OrigPreload))
                r.PristineMd5 = HashUtil.GetMd5(AppPaths.OrigPreload);
            else if (!string.IsNullOrEmpty(officialPreload))
                r.PristineMd5 = officialPreload;
            else if (known != null)
            {
                var md5 = JsonUtil.AsDict(JsonUtil.Get(known, "md5"));
                r.PristineMd5 = JsonUtil.GetString(md5, "preload");
            }

            string curMd5 = HashUtil.GetMd5(preloadPath);
            if (string.IsNullOrEmpty(curMd5))
            {
                r.Label = "preload.js 无法读取";
                return r;
            }

            if (curMd5 != r.PristineMd5)
            {
                try
                {
                    string txt = File.ReadAllText(preloadPath, Encoding.UTF8);
                    r.IsPatched = Patcher.HasMark(txt);
                }
                catch { }
                if (!r.IsPatched)
                    r.Warnings.Add("preload.js 与官方原版不一致，但没有本工具的标记。");
            }

            if (known != null)
            {
                string status = JsonUtil.GetString(known, "status");
                if (status == "unsupported")
                {
                    r.Status = "unsupported";
                    r.IsSupported = false;
                    r.Label = "抖音 " + ver + " 已标记为不受支持";
                    r.Detail = "请更新抖音，或先还原后等待工具更新。";
                    return r;
                }

                var knownMd5 = JsonUtil.AsDict(JsonUtil.Get(known, "md5"));
                string knownAsar = JsonUtil.GetString(knownMd5, "appAsar");
                string asmAsarMd5 = HashUtil.GetMd5(asarPath);
                bool asarOk = string.IsNullOrEmpty(knownAsar) || asmAsarMd5 == knownAsar;

                if (!asarOk)
                {
                    r.Status = "compatible";
                    r.IsSupported = true;
                    r.Label = "抖音 " + ver + "（已登记，但 app.asar 哈希不一致）";
                    r.Detail = "app.asar=" + asmAsarMd5 + " 期望=" + knownAsar;
                    r.Warnings.Add("app.asar 与登记构建不一致，目录结构可能已变化。");
                    return r;
                }

                var sig = JsonUtil.AsDict(JsonUtil.Get(known, "signatures"));
                string testedAt = JsonUtil.GetString(known, "testedAt");
                r.Status = "verified";
                r.IsSupported = true;
                r.Label = "抖音 " + ver + "（已实测支持）";
                r.Detail = "实测通过（" + testedAt + "）";
                return r;
            }

            string policy = "allow-with-warning";
            if (manifest != null)
            {
                var pol = JsonUtil.AsDict(JsonUtil.Get(manifest, "policy"));
                string p = JsonUtil.GetString(pol, "onUnknownVersion");
                if (!string.IsNullOrEmpty(p)) policy = p;
            }
            r.Status = "unknown";
            r.IsSupported = policy != "refuse";
            r.Label = "抖音 " + ver + "（未验证的新版本）";
            r.Detail = "结构与已知版本一致即可用；启用后请打开视频验证。";
            r.Warnings.Add("这个抖音版本尚未在本工具实测。");
            return r;
        }
    }
}
