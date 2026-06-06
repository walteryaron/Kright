using System.Windows.Threading;

namespace Kysy.Services;

/// <summary>Watches the focused field and switches the keyboard to English when
/// it lands on an email / URL / password / payment field. Opt-in. Runs on a
/// light DispatcherTimer; acts only on focus change.</summary>
public sealed class FocusLanguageEnforcer
{
    private static readonly HashSet<string> LatinKinds = new() { "Email", "URL", "Password", "Payment" };
    private readonly DispatcherTimer _timer;
    private string _lastSignature = "";

    public bool Enabled
    {
        get => AppSettings.Current.AutoEnglishOnLatinFields;
        set
        {
            AppSettings.Current.AutoEnglishOnLatinFields = value;
            AppSettings.Save();
            if (value) _timer.Start(); else _timer.Stop();
        }
    }

    public string? LastAction { get; private set; }

    public FocusLanguageEnforcer()
    {
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(400) };
        _timer.Tick += (_, _) => Tick();
    }

    public void StartIfEnabled() { if (Enabled) _timer.Start(); }

    private void Tick()
    {
        var field = FocusInspector.Focused();
        if (field is null) return;

        string sig = $"{field.ControlType}|{field.Name}|{field.IsPassword}";
        if (sig == _lastSignature) return;
        _lastSignature = sig;

        if (!LatinKinds.Contains(field.Guess)) return;

        // Already on a Latin layout (English, French, Spanish…)? Leave it — only
        // a non-Latin script (Hebrew, Arabic, Cyrillic…) garbles these fields.
        var current = LanguageManager.Current();
        if (current is null || LanguageManager.IsLatin(current.Hkl)) return;
        var target = LanguageManager.FirstLatin();
        if (target is null) return;

        LanguageManager.Switch(target.Hkl);
        LastAction = $"Switched to {target.Name} for {field.Guess} field";
    }
}
