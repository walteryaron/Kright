using System.Drawing;
using System.Media;
using System.Windows;
using System.Windows.Forms; // NotifyIcon (tray)
using Kright.Services;
using NetSparkleUpdater;
using NetSparkleUpdater.Enums;
using NetSparkleUpdater.SignatureVerifiers;
using Application = System.Windows.Application;

namespace Kright;

public partial class App : Application
{
    private NotifyIcon _tray = null!;
    private MainWindow? _window;
    private SparkleUpdater? _sparkle;

    // Sparkle auto-update feed (separate from macOS: Windows binaries + key differ).
    // Reachable over HTTPS by every install — works once the repo is public, else
    // host appcast-win.xml + the installer somewhere public and update this URL.
    private const string AppcastUrl =
        "https://raw.githubusercontent.com/walteryaron/Kright/main/appcast-win.xml";
    // Ed25519 PUBLIC key — paste the value printed by `netsparkle-generate-appcast
    // --generate-keys` (run once on the build machine; keep the private key safe).
    // SecurityMode.Strict means updates are REJECTED until this is set correctly.
    private const string Ed25519PublicKey = "uywCRbRonAfBNWIj9q2C6O7OtW4pBCinuktq094zyc4=";

    public static HotkeyManager Hotkey { get; private set; } = null!;
    public static FocusLanguageEnforcer Enforcer { get; private set; } = null!;
    public static AppLanguageEnforcer AppEnforcer { get; private set; } = null!;
    public static PrivacyMonitor Privacy { get; private set; } = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        Hotkey = new HotkeyManager();
        Hotkey.Triggered += FixFocusedLayout;

        Enforcer = new FocusLanguageEnforcer();
        Enforcer.StartIfEnabled();

        AppEnforcer = new AppLanguageEnforcer();
        AppEnforcer.Start();

        SetupTray();

        // Blind mode: when a password field is focused, show a slashed-eye icon
        // and stop Kright reading the field (see FixFocusedLayout).
        Privacy = new PrivacyMonitor();
        Privacy.SensitiveChanged += OnSensitiveChanged;
        Privacy.Start();

        SetupUpdater();
    }

    // ---- Auto-update (NetSparkle) ----

    private void SetupUpdater()
    {
        _sparkle = new SparkleUpdater(
            AppcastUrl,
            new Ed25519Checker(SecurityMode.Strict, Ed25519PublicKey))
        {
            UIFactory = new NetSparkleUpdater.UI.WPF.UIFactory(),
            RelaunchAfterUpdate = true,
        };

        // First run: ask whether to check for updates automatically — parity with
        // Sparkle's first-run prompt on macOS, so the user consents to the only
        // network call this otherwise-offline app makes. The choice is persisted;
        // the tray's "Check for Updates…" item works regardless of the answer.
        if (AppSettings.Current.AutoUpdateCheck is null)
        {
            // Fully-qualified: System.Windows.Forms is also imported (tray) and
            // also has a MessageBox, so the bare name is ambiguous.
            var answer = System.Windows.MessageBox.Show(
                "Should Kright automatically check for updates? You can always " +
                "check for updates manually from the tray menu.",
                "Check for updates automatically?",
                MessageBoxButton.YesNo, MessageBoxImage.Question);
            AppSettings.Current.AutoUpdateCheck = answer == MessageBoxResult.Yes;
            AppSettings.Save();
        }

        // Scheduled background checks (true = also check once at launch) — only if
        // the user opted in.
        if (AppSettings.Current.AutoUpdateCheck == true)
            _ = _sparkle.StartLoop(true);
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
        menu.Items.Add("Check for Updates…", null,
            async (_, _) => { if (_sparkle is not null) await _sparkle.CheckForUpdatesAtUserRequest(); });
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
        AppEnforcer.Dispose();
        _sparkle?.Dispose();
        base.OnExit(e);
    }
}
