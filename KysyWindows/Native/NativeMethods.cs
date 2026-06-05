using System.Runtime.InteropServices;
using System.Text;

namespace Kysy.Native;

/// <summary>All raw Win32 interop used by the app, in one place.</summary>
internal static class NativeMethods
{
    // ---- Foreground window / threads ----
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    // ---- Keyboard layouts ----
    [DllImport("user32.dll")] public static extern IntPtr GetKeyboardLayout(uint idThread);
    [DllImport("user32.dll")] public static extern int GetKeyboardLayoutList(int nBuff, [Out] IntPtr[] lpList);
    [DllImport("user32.dll")] public static extern IntPtr ActivateKeyboardLayout(IntPtr hkl, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint flags);

    [DllImport("user32.dll")]
    public static extern uint MapVirtualKeyEx(uint uCode, uint uMapType, IntPtr dwhkl);

    [DllImport("user32.dll")]
    public static extern int ToUnicodeEx(
        uint wVirtKey, uint wScanCode, byte[] lpKeyState,
        [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pwszBuff,
        int cchBuff, uint wFlags, IntPtr dwhkl);

    public const uint MAPVK_VK_TO_VSC = 0;

    // Switch another window's input language.
    public const int WM_INPUTLANGCHANGEREQUEST = 0x0050;
    [DllImport("user32.dll")]
    public static extern IntPtr PostMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    // ---- Global hotkey ----
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public const int WM_HOTKEY = 0x0312;
    public const uint MOD_ALT = 0x0001, MOD_CONTROL = 0x0002, MOD_SHIFT = 0x0004,
                      MOD_WIN = 0x0008, MOD_NOREPEAT = 0x4000;

    // ---- Low-level keyboard hook (Key Log + recording) ----
    public const int WH_KEYBOARD_LL = 13;
    public const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105;

    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    [StructLayout(LayoutKind.Sequential)]
    public struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    // ---- SendInput (keystroke replacement for read-only fields) ----
    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    public const int INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYUP = 0x0002, KEYEVENTF_UNICODE = 0x0004;
    public const ushort VK_BACK = 0x08;

    // Marker placed in dwExtraInfo so our own injected events are recognizable.
    public static readonly UIntPtr KYSY_MARKER = (UIntPtr)0x6B797379; // "kysy"

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT { public int type; public InputUnion u; }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion { [FieldOffset(0)] public KEYBDINPUT ki; }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }
}
