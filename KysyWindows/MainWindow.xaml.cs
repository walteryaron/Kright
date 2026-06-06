using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using Kysy.Native;
using Kysy.Services;

namespace Kysy;

public partial class MainWindow : Window
{
    private readonly DispatcherTimer _timer;
    private bool _recording;
    private LayoutSuggestion? _suggestion;

    public MainWindow()
    {
        InitializeComponent();
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(800) };
        _timer.Tick += (_, _) => RefreshDetect();
        IsVisibleChanged += (_, _) => { if (IsVisible) _timer.Start(); else _timer.Stop(); };

        HotkeyText.Text = App.Hotkey.DisplayString;
        AutoLangCheck.IsChecked = App.Enforcer.Enabled;

        DebugCheck.IsChecked = AppSettings.Current.DebugMode;
        ApplyDebugMode(AppSettings.Current.DebugMode);
    }

    public void SelectTab(int index)
    {
        // Detect (index 0) may be hidden — fall back to Settings.
        if (index == 0 && DetectTab.Visibility != Visibility.Visible) index = 1;
        Tabs.SelectedIndex = index;
    }

    private void ApplyDebugMode(bool on)
    {
        DetectTab.Visibility = on ? Visibility.Visible : Visibility.Collapsed;
        if (!on && ReferenceEquals(Tabs.SelectedItem, DetectTab)) Tabs.SelectedIndex = 1; // Settings
    }

    // Keep the app alive (tray) when the window is closed.
    protected override void OnClosing(CancelEventArgs e)
    {
        e.Cancel = true;
        Hide();
    }

    // ---- Detect tab ----

    private void RefreshDetect()
    {
        var field = FocusInspector.Focused();
        if (field is null)
        {
            AppLabel.Text = "No field focused";
            return;
        }
        AppLabel.Text = $"{field.ControlType}  ·  {field.Name}";
        GuessText.Text = field.Guess;

        var langs = LanguageManager.Enabled();
        LanguagesText.Text = string.Join("   ",
            langs.Select(l => l.IsCurrent ? $"[{l.Name}]" : l.Name));

        _suggestion = LayoutConverter.Suggest(field.Value);
        if (_suggestion is { IsMeaningful: true } s)
        {
            TypedText.Text = $"Typed: {s.Original}   ({s.FromLayout} → {s.ToLayout})";
            ConvertedText.Text = s.Converted;
            ReplaceButton.IsEnabled = true;

            var v = GibberishDetector.LooksWrongLayout(s.Original, s.Converted);
            GibberishText.Text = v.Wrong
                ? $"🧠 Likely wrong layout — {(int)(v.Confidence * 100)}% confident"
                : "🧠 Looks intentional — probably not a layout mistake";
            GibberishText.Foreground = v.Wrong
                ? System.Windows.Media.Brushes.LightGreen
                : System.Windows.Media.Brushes.Gray;
        }
        else
        {
            TypedText.Text = "Type ≥3 letters in a field to see a suggestion.";
            ConvertedText.Text = "";
            GibberishText.Text = "";
            ReplaceButton.IsEnabled = false;
        }

        if (App.Enforcer.LastAction is { } a) AutoLangStatus.Text = a;
    }

    private void ReplaceButton_Click(object sender, RoutedEventArgs e)
    {
        if (_suggestion is not { } s) return;
        bool ok = FocusInspector.TrySetFocusedValue(s.FullReplacement);
        ReplaceResult.Text = ok ? "Replaced ✓" : "Field is read-only — use the global hotkey instead.";
        ReplaceResult.Foreground = ok
            ? System.Windows.Media.Brushes.LightGreen
            : System.Windows.Media.Brushes.IndianRed;
    }

    // ---- Settings tab ----

    private void RecordButton_Click(object sender, RoutedEventArgs e)
    {
        _recording = !_recording;
        RecordButton.Content = _recording ? "Press keys… (Esc to cancel)" : "Change…";
        HotkeyText.Text = _recording ? "…" : App.Hotkey.DisplayString;
    }

    protected override void OnPreviewKeyDown(System.Windows.Input.KeyEventArgs e)
    {
        if (!_recording) { base.OnPreviewKeyDown(e); return; }
        e.Handled = true;

        // When Alt is held, the key arrives as Key.System with the real key in
        // SystemKey — resolve that first so the guard below sees the actual key.
        Key key = e.Key == Key.System ? e.SystemKey : e.Key;

        if (key == Key.Escape) { StopRecording(); return; }

        // Ignore lone modifier presses (incl. when they arrive via Key.System).
        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
            or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin
            or Key.System or Key.None) return;

        // Read each modifier's physical key state directly (both L/R variants).
        // This is more reliable than Keyboard.Modifiers when Alt routes the event
        // through Key.System, and on layouts where AltGr reports as Ctrl+Alt.
        uint fs = 0;
        bool ctrl = Keyboard.IsKeyDown(Key.LeftCtrl) || Keyboard.IsKeyDown(Key.RightCtrl);
        bool alt = Keyboard.IsKeyDown(Key.LeftAlt) || Keyboard.IsKeyDown(Key.RightAlt);
        bool shift = Keyboard.IsKeyDown(Key.LeftShift) || Keyboard.IsKeyDown(Key.RightShift);
        bool win = Keyboard.IsKeyDown(Key.LWin) || Keyboard.IsKeyDown(Key.RWin);
        if (ctrl) fs |= NativeMethods.MOD_CONTROL;
        if (alt) fs |= NativeMethods.MOD_ALT;
        if (shift) fs |= NativeMethods.MOD_SHIFT;
        if (win) fs |= NativeMethods.MOD_WIN;

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(key);

        if (fs == 0) return; // require a modifier
        App.Hotkey.Update(fs, vk);
        StopRecording();
    }

    private void StopRecording()
    {
        _recording = false;
        RecordButton.Content = "Change…";
        HotkeyText.Text = App.Hotkey.DisplayString;
    }

    private void AutoLangCheck_Click(object sender, RoutedEventArgs e)
        => App.Enforcer.Enabled = AutoLangCheck.IsChecked == true;

    private void DebugCheck_Click(object sender, RoutedEventArgs e)
    {
        bool on = DebugCheck.IsChecked == true;
        AppSettings.Current.DebugMode = on;
        AppSettings.Save();
        ApplyDebugMode(on);
    }

    private void Quit_Click(object sender, RoutedEventArgs e)
        => System.Windows.Application.Current.Shutdown();
}
