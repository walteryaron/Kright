import Cocoa
import Combine

/// Passive global keyboard listener (CGEventTap in `.listenOnly` mode, so it
/// never delays typing). Publishes recent key events for the Key Log view.
final class KeyboardMonitor: ObservableObject {
    @Published var events: [KeyEvent] = []
    @Published var trusted: Bool = AXIsProcessTrusted()
    @Published var lastError: String?

    /// The contiguous run of text the user is currently typing — the exact
    /// characters the OS produced (e.g. "קסןא getz"), INCLUDING the spaces
    /// between words, so the layout-fix hotkey can convert a whole multi-word
    /// phrase and knows precisely how many characters to delete. Resets on hard
    /// boundaries (Enter/Tab/Esc/arrows), not on Space. Independent of any AX
    /// value, which is why it works in Terminal/consoles.
    private(set) var currentPhrase = ""

    /// Call after a fix so the buffer reflects what's now in the field.
    func resetWord(to value: String = "") { currentPhrase = value }

    /// Blind mode: while true (set by PrivacyMonitor when a password field is
    /// focused), the tap records nothing — no word buffer, no key log.
    var paused = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?

    private static let maxEvents = 200

    func start() {
        if eventTap != nil { return }
        trusted = AXIsProcessTrusted()
        guard trusted else {
            scheduleRetry()
            return
        }
        createTap()
    }

    func requestAccess() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(opts)
        if trusted { start() }
    }

    // MARK: - Tap

    private func scheduleRetry() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.trusted = true
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                self.createTap()
            }
        }
    }

    private func createTap() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,           // passive — never gates input delivery
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                if let refcon = refcon {
                    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    monitor.handle(event: event, type: type)
                }
                return nil // ignored for listen-only taps
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "Failed to create keyboard tap. Grant Accessibility access."
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        lastError = nil
    }

    private func handle(event: CGEvent, type: CGEventType) {
        // Blind mode: a password field is focused — record nothing at all.
        if paused { return }
        // Ignore Kysy's own synthetic keystrokes (the Terminal/iTerm replacer).
        if event.getIntegerValueField(.eventSourceUserData) == KeystrokeReplacer.marker { return }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if type == .keyDown { updateWordBuffer(event: event, keyCode: keyCode, flags: flags) }

        let isDown: Bool
        switch type {
        case .keyDown: isDown = true
        case .keyUp: isDown = false
        case .flagsChanged: isDown = modifierIsDown(keyCode: keyCode, flags: flags)
        default: return
        }

        let ev = KeyEvent(
            keyCode: keyCode,
            isDown: isDown,
            shift: flags.contains(.maskShift),
            ctrl: flags.contains(.maskControl),
            alt: flags.contains(.maskAlternate),
            meta: flags.contains(.maskCommand),
            timestamp: Date())

        DispatchQueue.main.async {
            self.events.insert(ev, at: 0)
            if self.events.count > Self.maxEvents { self.events.removeLast() }
        }
    }

    /// Maintains `currentPhrase` from real keystrokes.
    private func updateWordBuffer(event: CGEvent, keyCode: Int, flags: CGEventFlags) {
        // Shortcuts (incl. our ⌃⌥K hotkey) aren't typing — don't record them.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) { return }

        switch keyCode {
        case 51:                                   // delete/backspace
            if !currentPhrase.isEmpty { currentPhrase.removeLast() }
            return
        case 49:                                   // space — keep it so words stay joined
            appendSpace()
            return
        case 36, 76, 48, 53,                       // return, enter, tab, esc
             123, 124, 125, 126,                   // arrows (cursor moved)
             115, 119, 116, 121:                   // home/end/page up/down
            currentPhrase = ""
            return
        default:
            break
        }

        // Translate the keycode with OUR OWN cached layout map. Crucially we do
        // NOT call keyboardGetUnicodeString on the live event — doing that inside
        // a tap corrupts the OS translation state and makes the user's actual
        // typed characters come out wrong (garbage/<ffff>).
        let sourceID = KeyboardLanguage.currentSourceID()
        guard let ch = KeyboardLayoutMap.forwardMap(sourceID)[UInt16(keyCode)],
              let c = ch.first else { return }
        if c.isWhitespace { appendSpace() }
        else if c.isLetter { currentPhrase += String(c) }  // letters build up the phrase
        else if producesLetterInLatin(keyCode: keyCode) {
            // The current layout emits punctuation here, but the SAME physical key
            // is a letter in the Latin layout (e.g. Hebrew "/" and "'" are the
            // "q" and "w" keys). Keep it so the layout-fix can convert it.
            currentPhrase += String(c)
        } else {
            currentPhrase = ""                             // real punctuation ends the phrase
        }
    }

    /// Whether `keyCode` types a letter in the first English/Latin layout — used
    /// to tell "a key that happens to print punctuation in this layout" (keep it)
    /// from genuine punctuation (ends the word).
    private func producesLetterInLatin(keyCode: Int) -> Bool {
        guard let en = KeyboardLanguage.firstEnglish() else { return false }
        return KeyboardLayoutMap.forwardMap(en.id)[UInt16(keyCode)]?.first?.isLetter == true
    }

    /// Append a single space between words, never leading or doubled — keeps the
    /// phrase a clean run of "word word word".
    private func appendSpace() {
        if !currentPhrase.isEmpty, currentPhrase.last != " " { currentPhrase += " " }
    }

    private func modifierIsDown(keyCode: Int, flags: CGEventFlags) -> Bool {
        switch keyCode {
        case 56, 60: return flags.contains(.maskShift)
        case 55, 54: return flags.contains(.maskCommand)
        case 58, 61: return flags.contains(.maskAlternate)
        case 59, 62: return flags.contains(.maskControl)
        case 57:     return flags.contains(.maskAlphaShift)
        case 63:     return flags.contains(.maskSecondaryFn)
        default:     return false
        }
    }
}
