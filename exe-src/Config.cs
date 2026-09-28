using System;
using System.IO;
using System.Text;

namespace DouyinQualityHelper
{
    public static class Config
    {
        public static string ReadDouyinDir()
        {
            try
            {
                if (!File.Exists(AppPaths.ConfigFile)) return null;
                var d = JsonUtil.AsDict(JsonUtil.Parse(File.ReadAllText(AppPaths.ConfigFile, Encoding.UTF8)));
                string dir = JsonUtil.GetString(d, "douyinDir");
                return string.IsNullOrEmpty(dir) ? null : dir;
            }
            catch { return null; }
        }

        public static bool SaveDouyinDir(string dir)
        {
            try
            {
                var obj = new System.Collections.Generic.Dictionary<string, object>
                {
                    { "douyinDir", dir },
                    { "savedAt", DateTime.Now.ToString("o") }
                };
                File.WriteAllText(AppPaths.ConfigFile, JsonUtil.Serialize(obj), new UTF8Encoding(false));
                return true;
            }
            catch { return false; }
        }
    }
}
