import Cocoa
import Combine

/// Passive global keyboard listener (CGEventTap in `.listenOnly` mode, so it
/// never delays typing). Publishes recent key events for the Key Log view.
final class KeyboardMonitor: ObservableObject {
    @Published var events: [KeyEvent] = []
    @Published var trusted: Bool = AXIsProcessTrusted()
    @Published var lastError: String?

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
        // Ignore Kysy's own synthetic keystrokes (the Terminal/iTerm replacer).
        if event.getIntegerValueField(.eventSourceUserData) == KeystrokeReplacer.marker { return }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

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
