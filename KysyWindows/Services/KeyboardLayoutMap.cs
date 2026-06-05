using System.Text;
using Kysy.Native;

namespace Kysy.Services;

/// <summary>
/// Reads the REAL character each virtual key produces under a given keyboard
/// layout (HKL) via ToUnicodeEx, so wrong-layout conversion matches what the
/// user's keyboard actually types — for any language pair. Equivalent to the
/// macOS UCKeyTranslate approach.
/// </summary>
public static class KeyboardLayoutMap
{
    // Virtual-key codes that produce text: letters, digits, and common OEM keys.
    private static readonly uint[] VKeys = BuildVKeyList();

    // hkl -> (vk -> char). Layouts are static, so cache.
    private static readonly Dictionary<IntPtr, Dictionary<uint, string>> ForwardCache = new();

    public static string? Convert(string text, IntPtr fromHkl, IntPtr toHkl)
    {
        var fromReverse = ReverseMap(fromHkl);   // char -> vk
        var toForward = ForwardMap(toHkl);        // vk -> char
        if (fromReverse.Count == 0 || toForward.Count == 0) return null;

        var sb = new StringBuilder(text.Length);
        bool changed = false;
        foreach (var ch in text)
        {
            if (fromReverse.TryGetValue(ch, out var vk) &&
                toForward.TryGetValue(vk, out var mapped) && mapped.Length > 0)
            {
                if (mapped[0] != ch) changed = true;
                sb.Append(mapped[0]);
            }
            else sb.Append(ch);
        }
        return changed ? sb.ToString() : null;
    }

    public static Dictionary<uint, string> ForwardMap(IntPtr hkl)
    {
        if (ForwardCache.TryGetValue(hkl, out var cached)) return cached;
        var map = new Dictionary<uint, string>();
        foreach (var vk in VKeys)
        {
            var ch = CharFor(vk, hkl);
            if (!string.IsNullOrEmpty(ch) && ch != " ")
                map[vk] = ch!;
        }
        ForwardCache[hkl] = map;
        return map;
    }

    private static Dictionary<char, uint> ReverseMap(IntPtr hkl)
    {
        var map = new Dictionary<char, uint>();
        foreach (var kv in ForwardMap(hkl))
            if (kv.Value.Length == 1 && !map.ContainsKey(kv.Value[0]))
                map[kv.Value[0]] = kv.Key;
        return map;
    }

    private static string? CharFor(uint vk, IntPtr hkl)
    {
        uint scan = NativeMethods.MapVirtualKeyEx(vk, NativeMethods.MAPVK_VK_TO_VSC, hkl);
        var keyState = new byte[256]; // all up: base (unshifted) character
        var sb = new StringBuilder(8);
        int rc = NativeMethods.ToUnicodeEx(vk, scan, keyState, sb, sb.Capacity, 0, hkl);
        // rc > 0: that many chars written. rc < 0: dead key. 0: no translation.
        return rc > 0 ? sb.ToString() : null;
    }

    private static uint[] BuildVKeyList()
    {
        var list = new List<uint>();
        for (uint k = 0x30; k <= 0x39; k++) list.Add(k); // 0-9
        for (uint k = 0x41; k <= 0x5A; k++) list.Add(k); // A-Z
        // OEM punctuation keys that differ across layouts.
        uint[] oem = { 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE, 0xE2 };
        list.AddRange(oem);
        return list.ToArray();
    }
}
