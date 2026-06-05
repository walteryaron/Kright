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
    }

    public void SelectTab(int index) => Tabs.SelectedIndex = index;

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
        }
        else
        {
            TypedText.Text = "Type ≥3 letters in a field to see a suggestion.";
            ConvertedText.Text = "";
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

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        if (!_recording) { base.OnPreviewKeyDown(e); return; }
        e.Handled = true;

        if (e.Key == Key.Escape) { StopRecording(); return; }

        // Ignore lone modifier presses.
        if (e.Key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
            or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin) return;

        var mods = Keyboard.Modifiers;
        if (mods == ModifierKeys.None) return; // require a modifier

        uint fs = 0;
        if (mods.HasFlag(ModifierKeys.Control)) fs |= NativeMethods.MOD_CONTROL;
        if (mods.HasFlag(ModifierKeys.Alt)) fs |= NativeMethods.MOD_ALT;
        if (mods.HasFlag(ModifierKeys.Shift)) fs |= NativeMethods.MOD_SHIFT;
        if (mods.HasFlag(ModifierKeys.Windows)) fs |= NativeMethods.MOD_WIN;

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(e.Key == Key.System ? e.SystemKey : e.Key);
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

    private void Quit_Click(object sender, RoutedEventArgs e)
        => System.Windows.Application.Current.Shutdown();
}
