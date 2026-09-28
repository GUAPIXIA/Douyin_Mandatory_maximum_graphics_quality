using System.Windows;

namespace DouyinQualityHelper
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            DispatcherUnhandledException += (s, args) =>
            {
                try { AppPaths.WriteCrashLog(args.Exception); } catch { }
                MessageBox.Show(
                    "程序出错了：\n\n" + args.Exception.Message + "\n\n详细信息已写入 error.log",
                    "抖音画质助手", MessageBoxButton.OK, MessageBoxImage.Error);
                args.Handled = true;
            };
        }
    }
}
