using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using System.Web.Script.Serialization;

namespace DouyinQualityHelper
{
    public static class JsonUtil
    {
        static JavaScriptSerializer Create()
        {
            var s = new JavaScriptSerializer { MaxJsonLength = int.MaxValue, RecursionLimit = 100 };
            return s;
        }

        public static object Parse(string json)
        {
            return Create().DeserializeObject(json);
        }

        public static string Serialize(object obj)
        {
            return Create().Serialize(obj);
        }

        public static Dictionary<string, object> AsDict(object o)
        {
            return o as Dictionary<string, object>;
        }

        public static object Get(Dictionary<string, object> d, string key)
        {
            object v;
            return d != null && d.TryGetValue(key, out v) ? v : null;
        }

        public static string GetString(Dictionary<string, object> d, string key)
        {
            object v = Get(d, key);
            return v == null ? "" : Convert.ToString(v);
        }
    }
}
