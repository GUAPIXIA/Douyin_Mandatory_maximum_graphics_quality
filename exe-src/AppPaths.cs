using System;
using System.IO;
using System.Reflection;

namespace DouyinQualityHelper
{
    /// <summary>
    /// All writable data lives next to the EXE (portable green package).
    /// </summary>
    public static class AppPaths
    {
        public static string AppDir
        {
            get
            {
                string exe = Assembly.GetExecutingAssembly().Location;
                return Path.GetDirectoryName(exe) ?? AppDomain.CurrentDomain.BaseDirectory;
            }
        }

        public static string ConfigFile { get { return Path.Combine(AppDir, "config.json"); } }
        public static string VersionsFile { get { return Path.Combine(AppDir, "versions.json"); } }
        public static string BackupDir { get { return Path.Combine(AppDir, "backup"); } }
        public static string OrigPreload { get { return Path.Combine(BackupDir, "loose-preload", "preload.js.orig"); } }
        public static string AsarOrig { get { return Path.Combine(BackupDir, "app.asar.orig"); } }
        public static string BuildDir { get { return Path.Combine(AppDir, "work", "build"); } }
        public static string UserData { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "douyin"); } }
        public static string PageLog { get { return Path.Combine(UserData, "dy-force.log"); } }
        public static string CrashLog { get { return Path.Combine(AppDir, "error.log"); } }

        public static string ReadEmbeddedText(string name)
        {
            string full = "DouyinQualityHelper.Resources." + name;
            using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(full))
            {
                if (s == null) throw new FileNotFoundException("Embedded resource missing: " + name);
                using (var r = new StreamReader(s, System.Text.Encoding.UTF8))
                    return r.ReadToEnd();
            }
        }

        public static void EnsureVersionsFile()
        {
            if (File.Exists(VersionsFile)) return;
            Directory.CreateDirectory(AppDir);
            File.WriteAllText(VersionsFile, ReadEmbeddedText("versions.json"), new System.Text.UTF8Encoding(false));
        }

        public static void WriteCrashLog(Exception ex)
        {
            try
            {
                string text = DateTime.Now.ToString("o") + "\r\n" + ex + "\r\n\r\n";
                File.AppendAllText(CrashLog, text, new System.Text.UTF8Encoding(false));
            }
            catch { }
        }
    }

    public sealed class InstallPaths
    {
        public string Root { get; set; }
        public string VersionDir { get; set; }
        public string Preload { get; set; }
        public string Asar { get; set; }
        public string Md5Json { get; set; }
        public string LauncherConfig { get; set; }
    }
}
