using System.Drawing;
using System.Media;
using System.Windows;
using System.Windows.Forms; // NotifyIcon (tray)
using Kright.Services;
using Application = System.Windows.Application;

namespace Kright;

public partial class App : Application
{
    private NotifyIcon _tray = null!;
    private MainWindow? _window;

    public static HotkeyManager Hotkey { get; private set; } = null!;
    public static FocusLanguageEnforcer Enforcer { get; private set; } = null!;
    public static PrivacyMonitor Privacy { get; private set; } = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        Hotkey = new HotkeyManager();
        Hotkey.Triggered += FixFocusedLayout;

        Enforcer = new FocusLanguageEnforcer();
        Enforcer.StartIfEnabled();

        SetupTray();

        // Blind mode: when a password field is focused, show a slashed-eye icon
        // and stop Kright reading the field (see FixFocusedLayout).
        Privacy = new PrivacyMonitor();
        Privacy.SensitiveChanged += OnSensitiveChanged;
        Privacy.Start();
    }

    private void OnSensitiveChanged(bool sensitive)
    {
        _tray.Icon = sensitive ? TrayIcons.Blind : TrayIcons.Normal;
        _tray.Text = sensitive ? "Kright — not reading (password field)" : "Kright";
    }

    // ---- Tray ----

    private void SetupTray()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("Open", null, (_, _) => ToggleWindow());
        menu.Items.Add("Settings", null, (_, _) => ShowWindow(tab: 1));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit Kright", null, (_, _) => Shutdown());

        _tray = new NotifyIcon
        {
            Icon = TrayIcons.Normal,
            Visible = true,
            Text = "Kright",
            ContextMenuStrip = menu
        };
        _tray.MouseClick += (_, ev) =>
        {
            if (ev.Button == MouseButtons.Left) ToggleWindow();
        };
    }

    private void ToggleWindow()
    {
        if (_window is { IsVisible: true }) _window.Hide();
        else ShowWindow();
    }

    private void ShowWindow(int tab = 0)
    {
        _window ??= new MainWindow();
        _window.SelectTab(tab);
        _window.Show();
        _window.Activate();
    }

    // ---- The core action: fix the focused field's wrong-layout word ----

    public static void FixFocusedLayout()
    {
        var field = FocusInspector.Focused();
        if (field is null) { SystemSounds.Beep.Play(); return; }

        // Blind mode: never read or touch a password field.
        if (field.IsPassword) { SystemSounds.Beep.Play(); return; }

        // Convert the whole just-typed phrase (all words, e.g. "nrhu dktexh"),
        // falling back to the last word for long values (a console/document
        // buffer we shouldn't rewrite wholesale).
        var s = LayoutConverter.SuggestPhrase(field.Value) ?? LayoutConverter.Suggest(field.Value);
        if (s is null || !s.IsMeaningful) { SystemSounds.Beep.Play(); return; }

        // After fixing, switch the keyboard to the corrected text's language so the
        // user keeps typing in the right layout instead of more gibberish.
        if (s.ToHkl != IntPtr.Zero) LanguageManager.Switch(s.ToHkl);

        if (FocusInspector.TrySetFocusedValue(s.FullReplacement)) return;

        // Read-only (console/terminal) → keystroke fallback on a background thread.
        System.Threading.Tasks.Task.Run(() =>
            KeystrokeReplacer.ReplaceLastWord(s.Original.Length, s.Converted));
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _tray.Visible = false;
        _tray.Dispose();
        Hotkey.Dispose();
        base.OnExit(e);
    }
}
