import Cocoa

/// Replaces text by simulating keystrokes (CGEvent), for fields that reject
/// Accessibility writes — Terminal, iTerm, and other read-only-AX apps. It sends
/// N backspaces to delete the wrong word, then pastes the corrected word via the
/// clipboard (⌘V). Terminals accept real key events and paste, but ignore
/// keycode-less Unicode-string injection — so paste is the reliable path.
///
/// All injected events are tagged with `marker` via the event source's userData,
/// so KeyboardMonitor can recognize and ignore Kysy's own synthetic keystrokes.
enum KeystrokeReplacer {
    /// Sentinel written to CGEventSource.userData on every injected event.
    static let marker: Int64 = 0x6B79_7379   // "kysy"

    /// Delete `originalLength` characters, then paste `replacement`.
    static func replaceLastWord(originalLength: Int, replacement: String) {
        guard originalLength > 0, let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.userData = marker

        for _ in 0..<originalLength {
            postKey(0x33, source: source)   // kVK_Delete (backspace)
            usleep(8_000)
        }
        usleep(12_000)                       // let the deletes settle

        // Paste the correction via the clipboard (⌘V), saving/restoring the
        // user's existing clipboard contents around it.
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)

        pb.clearContents()
        pb.setString(replacement, forType: .string)
        usleep(25_000)                       // give the pasteboard time to settle

        postKey(0x09, source: source, flags: .maskCommand)  // ⌘V  (kVK_ANSI_V)
        usleep(160_000)                      // wait for the paste to land

        pb.clearContents()
        if let saved { pb.setString(saved, forType: .string) }
    }

    // MARK: - Low-level

    private static func postKey(_ keyCode: CGKeyCode, source: CGEventSource, flags: CGEventFlags = []) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
