using System.Windows.Interop;
using Kright.Native;

namespace Kright.Services;

/// <summary>Registers a system-wide hotkey via RegisterHotKey and raises
/// <see cref="Triggered"/> when pressed. Uses a message-only window to receive
/// WM_HOTKEY. Supports re-recording the combo.</summary>
public sealed class HotkeyManager : IDisposable
{
    private const int HotkeyId = 1;
    private readonly HwndSource _source;
    public event Action? Triggered;

    public uint Modifiers { get; private set; }   // MOD_* flags
    public uint VirtualKey { get; private set; }

    public HotkeyManager()
    {
        // Message-only window (HWND_MESSAGE = -3).
        var p = new HwndSourceParameters("KrightHotkey")
        {
            ParentWindow = new IntPtr(-3),
            WindowStyle = 0
        };
        _source = new HwndSource(p);
        _source.AddHook(WndProc);

        Modifiers = AppSettings.Current.HotkeyModifiers;
        VirtualKey = AppSettings.Current.HotkeyVk;
        Register();
    }

    public string DisplayString => Describe(Modifiers, VirtualKey);

    public void Update(uint modifiers, uint vk)
    {
        Modifiers = modifiers;
        VirtualKey = vk;
        AppSettings.Current.HotkeyModifiers = modifiers;
        AppSettings.Current.HotkeyVk = vk;
        AppSettings.Save();
        Register();
    }

    /// <summary>Registers the current combo. Returns false if the OS rejected it
    /// (e.g. another app already owns that hotkey).</summary>
    public bool Register()
    {
        NativeMethods.UnregisterHotKey(_source.Handle, HotkeyId);
        return NativeMethods.RegisterHotKey(_source.Handle, HotkeyId,
            Modifiers | NativeMethods.MOD_NOREPEAT, VirtualKey);
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == NativeMethods.WM_HOTKEY && wParam.ToInt32() == HotkeyId)
        {
            Triggered?.Invoke();
            handled = true;
        }
        return IntPtr.Zero;
    }

    public static string Describe(uint mods, uint vk)
    {
        string s = "";
        if ((mods & NativeMethods.MOD_CONTROL) != 0) s += "Ctrl+";
        if ((mods & NativeMethods.MOD_ALT) != 0) s += "Alt+";
        if ((mods & NativeMethods.MOD_SHIFT) != 0) s += "Shift+";
        if ((mods & NativeMethods.MOD_WIN) != 0) s += "Win+";
        return s + KeyName(vk);
    }

    private static string KeyName(uint vk)
    {
        if (vk >= 0x41 && vk <= 0x5A) return ((char)vk).ToString();           // A-Z
        if (vk >= 0x30 && vk <= 0x39) return ((char)vk).ToString();           // 0-9
        return $"VK{vk:X2}";
    }

    public void Dispose()
    {
        NativeMethods.UnregisterHotKey(_source.Handle, HotkeyId);
        _source.Dispose();
    }
}
