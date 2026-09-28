using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace DouyinQualityHelper
{
    public static class HashUtil
    {
        public static string GetMd5(string path)
        {
            return HashFile(path, "MD5");
        }

        public static string GetSha256(string path)
        {
            return HashFile(path, "SHA256").ToUpperInvariant();
        }

        public static string HashFile(string path, string algo)
        {
            if (string.IsNullOrEmpty(path) || !File.Exists(path)) return string.Empty;
            using (var fs = File.OpenRead(path))
            using (var h = HashAlgorithm.Create(algo))
            {
                byte[] buf = h.ComputeHash(fs);
                var sb = new StringBuilder(buf.Length * 2);
                foreach (byte b in buf) sb.Append(b.ToString("x2"));
                return sb.ToString();
            }
        }

        public static string Md5OfText(string text)
        {
            using (var h = HashAlgorithm.Create("MD5"))
            {
                byte[] buf = h.ComputeHash(Encoding.UTF8.GetBytes(text));
                var sb = new StringBuilder(buf.Length * 2);
                foreach (byte b in buf) sb.Append(b.ToString("x2"));
                return sb.ToString();
            }
        }
    }
}
