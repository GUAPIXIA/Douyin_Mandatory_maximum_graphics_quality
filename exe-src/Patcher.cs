using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace DouyinQualityHelper
{
    /// <summary>
    /// Port of tools/patch-preload.js — keep the injected bytes identical.
    /// </summary>
    public static class Patcher
    {
        public const string MARK_BEGIN = "/* ==== DY_FORCE_INJECTOR_BEGIN ==== */";
        public const string MARK_END = "/* ==== DY_FORCE_INJECTOR_END ==== */";
        public const string ORIG_PRELOAD_MD5 = "bfcb8e31fae5a7370c5bee258ffcdfad";

        public static string BuildWrapper(string payload)
        {
            // Mirror patch-preload.js exactly (ASCII-only wrapper + payload verbatim).
            const string NL = "\n";
            var lines = new List<string>
            {
                ";(function () {",
                "  'use strict';",
                "  var fs = null, path = null, logFile = '';",
                "  function wal(line) {",
                "    try {",
                "      if (!fs) { fs = require('fs'); path = require('path'); }",
                "      if (!logFile) {",
                "        var b = process.env.APPDATA || process.cwd();",
                "        logFile = path.join(b, 'douyin', 'dy-force.log');",
                "      }",
                "      fs.appendFileSync(logFile, new Date().toISOString() + ' ' + line + '\\n');",
                "    } catch (e) { /* logging must never break anything */ }",
                "  }",
                "  try {",
                "    wal('[boot] loose-preload loaded url=' + (typeof location !== 'undefined' ? location.href : 'n/a') + ' isolated=' + process.contextIsolated);",
                "  } catch (e) {}",
                "  try { if (typeof window !== 'undefined') { window.__dyForceLog = wal; } } catch (e) {}",
                "  try {",
                payload,
                "    wal('[boot] payload done');",
                "  } catch (e) {",
                "    wal('[boot] payload error: ' + (e && e.stack ? e.stack : e));",
                "  }",
                "})();"
            };
            return string.Join(NL, lines);
        }

        public static string PatchText(string original, string payload)
        {
            if (original.IndexOf(MARK_BEGIN, StringComparison.Ordinal) >= 0)
                throw new InvalidOperationException("source file is already patched; use the pristine original");

            string wrapper = BuildWrapper(payload);
            const string NL = "\n";
            string injection = NL + MARK_BEGIN + NL + wrapper + NL + MARK_END + NL;

            int mapIdx = original.LastIndexOf("//# sourceMappingURL", StringComparison.Ordinal);
            return mapIdx >= 0
                ? original.Substring(0, mapIdx) + injection + original.Substring(mapIdx)
                : original + injection;
        }

        public static void PatchFile(string srcPath, string payloadPath, string outPath)
        {
            string original = File.ReadAllText(srcPath, Encoding.UTF8);
            string payload = File.ReadAllText(payloadPath, Encoding.UTF8);
            string patched = PatchText(original, payload);
            Directory.CreateDirectory(Path.GetDirectoryName(outPath) ?? ".");
            File.WriteAllText(outPath, patched, new UTF8Encoding(false));
        }

        /// <summary>
        /// Symmetric strip of our injected block; returns true if markers were found.
        /// </summary>
        public static bool TryStrip(string text, out string stripped)
        {
            stripped = text;
            int i = text.IndexOf(MARK_BEGIN, StringComparison.Ordinal);
            int j = text.IndexOf(MARK_END, StringComparison.Ordinal);
            if (i < 0 || j <= i) return false;

            int end = j + MARK_END.Length;
            if (i > 0 && i < text.Length && text[i - 1] == '\n') i = i - 1;
            if (end > 0 && end < text.Length && text[end] == '\r') end++;
            if (end > 0 && end < text.Length && text[end] == '\n') end++;
            stripped = text.Substring(0, i) + text.Substring(end);
            return true;
        }

        public static bool HasMark(string text)
        {
            return !string.IsNullOrEmpty(text) && text.IndexOf(MARK_BEGIN, StringComparison.Ordinal) >= 0;
        }
    }
}
