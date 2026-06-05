import Cocoa

/// Replaces text by simulating keystrokes (CGEvent), for fields that reject
/// Accessibility writes — Terminal, iTerm, and other read-only-AX apps. It sends
/// N backspaces to delete the wrong word, then types the corrected word as a
/// Unicode string event (no clipboard clobber, no dependency on current layout).
///
/// All injected events are tagged with `marker` via the event source's userData,
/// so KeyboardMonitor can recognize and ignore Kysy's own synthetic keystrokes.
enum KeystrokeReplacer {
    /// Sentinel written to CGEventSource.userData on every injected event.
    static let marker: Int64 = 0x6B79_7379   // "kysy"

    /// Delete `originalLength` characters, then type `replacement`.
    static func replaceLastWord(originalLength: Int, replacement: String) {
        guard originalLength > 0, let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.userData = marker

        for _ in 0..<originalLength {
            postKey(0x33, source: source)   // kVK_Delete (backspace)
            usleep(6_000)
        }
        usleep(10_000)                       // let the deletes settle
        typeUnicode(replacement, source: source)
    }

    // MARK: - Low-level

    private static func postKey(_ keyCode: CGKeyCode, source: CGEventSource) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func typeUnicode(_ string: String, source: CGEventSource) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        var chars = Array(string.utf16)
        down.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
