using System.Threading;
using Kright.Native;

namespace Kright.Services;

/// <summary>Replaces text by simulating keystrokes (SendInput), for fields that
/// reject UIA writes — consoles (cmd, PowerShell, Windows Terminal), etc. Sends
/// N backspaces then types the correction as Unicode input. Injected events are
/// tagged via dwExtraInfo so the keyboard hook can ignore Kright's own input.</summary>
public static class KeystrokeReplacer
{
    public static void ReplaceLastWord(int originalLength, string replacement)
    {
        if (originalLength <= 0) return;

        for (int i = 0; i < originalLength; i++)
        {
            SendKey(NativeMethods.VK_BACK, '\0', keyUp: false);
            SendKey(NativeMethods.VK_BACK, '\0', keyUp: true);
            Thread.Sleep(6);
        }
        Thread.Sleep(10);
        foreach (var ch in replacement)
        {
            SendKey(0, ch, keyUp: false, unicode: true);
            SendKey(0, ch, keyUp: true, unicode: true);
            Thread.Sleep(2);
        }
    }

    private static void SendKey(ushort vk, char ch, bool keyUp, bool unicode = false)
    {
        var input = new NativeMethods.INPUT
        {
            type = NativeMethods.INPUT_KEYBOARD,
            u = new NativeMethods.InputUnion
            {
                ki = new NativeMethods.KEYBDINPUT
                {
                    wVk = unicode ? (ushort)0 : vk,
                    wScan = unicode ? ch : (ushort)0,
                    dwFlags = (unicode ? NativeMethods.KEYEVENTF_UNICODE : 0)
                              | (keyUp ? NativeMethods.KEYEVENTF_KEYUP : 0),
                    time = 0,
                    dwExtraInfo = NativeMethods.KRIGHT_MARKER,
                }
            }
        };
        NativeMethods.SendInput(1, new[] { input }, System.Runtime.InteropServices.Marshal.SizeOf<NativeMethods.INPUT>());
    }
}
