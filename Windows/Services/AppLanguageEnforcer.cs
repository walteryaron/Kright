using System.Diagnostics;
using System.IO;
using System.Text;
using Kright.Native;

namespace Kright.Services;

/// <summary>Watches foreground-window changes via SetWinEventHook and switches
/// the keyboard layout when the newly-focused app matches a saved rule.
/// Also tracks the last non-Kright foreground app so the Settings window can
/// offer "Add current app" reliably (the WPF window itself would otherwise be
/// the foreground app when the button is clicked).</summary>
public sealed class AppLanguageEnforcer : IDisposable
{
    public string? LastExternalExePath { get; private set; }
    public string? LastExternalAppName { get; private set; }

    public bool Enabled
    {
        get => AppSettings.Current.AppLanguageRulesEnabled;
        set { AppSettings.Current.AppLanguageRulesEnabled = value; AppSettings.Save(); }
    }

    private readonly NativeMethods.WinEventDelegate _hookProc;
    private IntPtr _hook = IntPtr.Zero;
    private static readonly uint OwnPid = (uint)Environment.ProcessId;

    public AppLanguageEnforcer()
    {
        _hookProc = WinEventProc; // hold reference — prevents GC while hook is live
    }

    public void Start()
    {
        if (_hook != IntPtr.Zero) return;
        _hook = NativeMethods.SetWinEventHook(
            NativeMethods.EVENT_SYSTEM_FOREGROUND,
            NativeMethods.EVENT_SYSTEM_FOREGROUND,
            IntPtr.Zero, _hookProc,
            0, 0, NativeMethods.WINEVENT_OUTOFCONTEXT);
    }

    public void Stop()
    {
        if (_hook == IntPtr.Zero) return;
        NativeMethods.UnhookWinEvent(_hook);
        _hook = IntPtr.Zero;
    }

    public void Dispose() => Stop();

    private void WinEventProc(IntPtr hHook, uint eventType, IntPtr hwnd,
        int idObject, int idChild, uint dwThread, uint dwTime)
    {
        if (hwnd == IntPtr.Zero) return;
        NativeMethods.GetWindowThreadProcessId(hwnd, out uint pid);

        string? exePath = GetProcessPath(pid);

        // Always track the last non-Kright foreground app (even when disabled)
        // so "Add current app" can read it from the Settings window.
        if (pid != OwnPid && exePath != null)
        {
            LastExternalExePath = exePath;
            LastExternalAppName = GetAppName(exePath, pid);
        }

        if (!Enabled || pid == OwnPid || exePath == null) return;

        var rule = AppSettings.Current.AppLanguageRules.FirstOrDefault(r =>
            string.Equals(r.ExePath, exePath, StringComparison.OrdinalIgnoreCase));
        if (rule == null) return;

        var lang = LanguageManager.Enabled()
            .FirstOrDefault(l => (long)l.Hkl == rule.HklValue);
        if (lang != null)
            LanguageManager.Switch(lang.Hkl);
    }

    private static string? GetProcessPath(uint pid)
    {
        var handle = NativeMethods.OpenProcess(
            NativeMethods.PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (handle == IntPtr.Zero) return null;
        try
        {
            var sb = new StringBuilder(1024);
            uint size = (uint)sb.Capacity;
            return NativeMethods.QueryFullProcessImageName(handle, 0, sb, ref size)
                ? sb.ToString() : null;
        }
        catch { return null; }
        finally { NativeMethods.CloseHandle(handle); }
    }

    private static string GetAppName(string exePath, uint pid)
    {
        try
        {
            var productName = FileVersionInfo.GetVersionInfo(exePath).ProductName?.Trim();
            if (!string.IsNullOrEmpty(productName)) return productName;
        }
        catch { }
        try
        {
            var desc = FileVersionInfo.GetVersionInfo(exePath).FileDescription?.Trim();
            if (!string.IsNullOrEmpty(desc)) return desc;
        }
        catch { }
        return Path.GetFileNameWithoutExtension(exePath);
    }
}
