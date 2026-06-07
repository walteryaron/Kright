using System.Windows.Threading;

namespace Kright.Services;

/// <summary>Always-on watcher that flips Kright into "blind mode" while a password
/// field is focused. In blind mode the tray icon shows a slashed eye and Kright
/// refuses to read the focused field — so it's visibly clear Kright isn't looking
/// at the password. Runs on a light DispatcherTimer regardless of any opt-in.</summary>
public sealed class PrivacyMonitor
{
    private readonly DispatcherTimer _timer;

    /// <summary>True while the focused field is a password field.</summary>
    public bool Sensitive { get; private set; }

    /// <summary>Raised on the UI thread whenever <see cref="Sensitive"/> flips.</summary>
    public event Action<bool>? SensitiveChanged;

    public PrivacyMonitor()
    {
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(300) };
        _timer.Tick += (_, _) => Tick();
    }

    public void Start() => _timer.Start();
    public void Stop() => _timer.Stop();

    private void Tick()
    {
        bool s = FocusInspector.Focused()?.IsPassword ?? false;
        if (s == Sensitive) return;
        Sensitive = s;
        SensitiveChanged?.Invoke(s);
    }
}
