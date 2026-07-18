using System.Text;
using System.Windows.Threading;
using Kright.Native;

namespace Kright.Services;

/// <summary>Switches the keyboard based on which conversation is open inside a
/// supported chat app (Teams). Polls the foreground window on the WPF UI thread
/// via DispatcherTimer — no WinEvent hook needed, works reliably with Store apps.</summary>
public sealed class ContactLanguageEnforcer : IDisposable
{
    public ContactApp? LastContactApp { get; private set; }
    public string? LastContactName { get; private set; }

    public bool Enabled
    {
        get => AppSettings.Current.ContactLanguageRulesEnabled;
        set { AppSettings.Current.ContactLanguageRulesEnabled = value; AppSettings.Save(); }
    }

    private DispatcherTimer? _timer;
    private string? _lastContact;
    private static readonly uint OwnPid = (uint)Environment.ProcessId;

    private const double PollSeconds = 0.8;

    public void Start()
    {
        if (_timer != null) return;
        _timer = new DispatcherTimer(DispatcherPriority.Background)
        {
            Interval = TimeSpan.FromSeconds(PollSeconds)
        };
        _timer.Tick += (_, _) => Poll();
        _timer.Start();
    }

    public void Stop()
    {
        _timer?.Stop();
        _timer = null;
        _lastContact = null;
    }

    public void Dispose() => Stop();

    private void Poll()
    {
        try
        {
            var hwnd = NativeMethods.GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return;

            NativeMethods.GetWindowThreadProcessId(hwnd, out uint pid);
            if (pid == OwnPid) return;

            var app = ContactAppExtensions.FromExePath(GetProcessPath(pid));
            if (app == null) { _lastContact = null; return; }

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
        catch { /* best-effort poll — never let a transient UIA/process error crash the timer */ }
    }

    // ---- helpers ----

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
