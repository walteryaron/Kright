using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using Kright.Native;

namespace Kright.Services;

/// <summary>Switches the keyboard based on which conversation is open inside a
/// supported chat app (WhatsApp / Teams). Complements <see cref="AppLanguageEnforcer"/>:
/// that one acts on app switches (per exe); this one acts on chat switches
/// *within* an app (per contact).
///
/// There's no OS event for "the open chat changed", so while a watched app is
/// foreground we poll on a light timer. Polling only runs while such an app is
/// foreground — never globally — and the WhatsApp UIA walk is node-budgeted, so
/// the cost stays low. When no contact rule matches we do nothing, leaving any
/// per-app rule in effect (contact rules refine, not replace, per-app rules).</summary>
public sealed class ContactLanguageEnforcer : IDisposable
{
    // For the "Add current contact" button in Settings (read on the UI thread).
    public ContactApp? LastContactApp { get; private set; }
    public string? LastContactName { get; private set; }

    public bool Enabled
    {
        get => AppSettings.Current.ContactLanguageRulesEnabled;
        set { AppSettings.Current.ContactLanguageRulesEnabled = value; AppSettings.Save(); }
    }

    private readonly NativeMethods.WinEventDelegate _hookProc;
    private IntPtr _hook = IntPtr.Zero;
    private Timer? _timer;
    private ContactApp? _currentApp;
    private string? _lastContact;
    private static readonly uint OwnPid = (uint)Environment.ProcessId;

    private const int PollMs = 700;

    public ContactLanguageEnforcer()
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

        // Handle the app that's already foreground at start time.
        BeginWatching(AppFor(NativeMethods.GetForegroundWindow()));
    }

    public void Stop()
    {
        if (_hook != IntPtr.Zero) { NativeMethods.UnhookWinEvent(_hook); _hook = IntPtr.Zero; }
        StopPolling();
    }

    public void Dispose() => Stop();

    private void WinEventProc(IntPtr hHook, uint eventType, IntPtr hwnd,
        int idObject, int idChild, uint dwThread, uint dwTime)
    {
        if (hwnd == IntPtr.Zero) return;
        BeginWatching(AppFor(hwnd));
    }

    /// <summary>Identify which watched chat app (if any) owns a window.</summary>
    private static ContactApp? AppFor(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return null;
        NativeMethods.GetWindowThreadProcessId(hwnd, out uint pid);
        if (pid == OwnPid) return null;
        return ContactAppExtensions.FromExePath(GetProcessPath(pid));
    }

    private void BeginWatching(ContactApp? app)
    {
        if (app == null) { StopPolling(); return; }
        _currentApp = app;
        _lastContact = null;                 // force re-apply on (re)entering the app
        _timer?.Dispose();
        // First tick slightly late so it lands *after* AppLanguageEnforcer's per-app
        // switch on foreground change — the contact rule wins.
        _timer = new Timer(_ => Poll(), null, 350, PollMs);
    }

    private void StopPolling()
    {
        _timer?.Dispose();
        _timer = null;
        _currentApp = null;
        _lastContact = null;
    }

    private void Poll()
    {
        var app = _currentApp;
        if (app == null) return;

        var hwnd = NativeMethods.GetForegroundWindow();
        // Bail if the watched app is no longer foreground (the hook will have or
        // will shortly stop us; avoids reading an unrelated window).
        if (AppFor(hwnd) != app) return;

        var contact = ChatContactDetector.CurrentContact(app.Value, hwnd);
        if (contact == null) return;

        LastContactApp = app;
        LastContactName = contact;

        if (!Enabled || contact == _lastContact) return;
        _lastContact = contact;

        var rule = AppSettings.Current.ContactLanguageRules
            .FirstOrDefault(r => r.App == app.Value && r.ContactName == contact);
        if (rule == null) return;

        var lang = LanguageManager.Enabled().FirstOrDefault(l => (long)l.Hkl == rule.HklValue);
        if (lang != null) LanguageManager.Switch(lang.Hkl);
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
}
