import Cocoa
import FlutterMacOS

class KeyboardStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        promptAccessibilityIfNeeded()
        startKeyboardMonitoring()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopKeyboardMonitoring()
        self.eventSink = nil
        return nil
    }

    // MARK: - Accessibility

    private func promptAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("[Kysy] Accessibility not granted — prompting user.")
        }
    }

    // MARK: - CGEventTap

    private func startKeyboardMonitoring() {
        guard AXIsProcessTrusted() else {
            DispatchQueue.main.async {
                self.eventSink?(FlutterError(
                    code: "PERMISSION_DENIED",
                    message: "Accessibility access required. Enable Kysy in System Settings → Privacy & Security → Accessibility, then restart.",
                    details: nil
                ))
            }
            return
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let handler = Unmanaged<KeyboardStreamHandler>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                handler.forward(event: event, type: type)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[Kysy] CGEvent.tapCreate failed — check Accessibility permissions.")
            DispatchQueue.main.async {
                self.eventSink?(FlutterError(
                    code: "TAP_FAILED",
                    message: "Failed to create keyboard tap. Grant Accessibility access in System Settings → Privacy & Security → Accessibility.",
                    details: nil
                ))
            }
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[Kysy] Keyboard monitoring started.")
    }

    private func stopKeyboardMonitoring() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        print("[Kysy] Keyboard monitoring stopped.")
    }

    // MARK: - Event handling

    private func forward(event: CGEvent, type: CGEventType) {
        guard let sink = eventSink else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let isDown: Bool
        switch type {
        case .keyDown:
            isDown = true
        case .keyUp:
            isDown = false
        case .flagsChanged:
            isDown = modifierIsDown(keyCode: keyCode, flags: flags)
        default:
            return
        }

        let payload: [String: Any] = [
            "keyCode": keyCode,
            "isKeyDown": isDown,
            "modifiers": [
                "shift": flags.contains(.maskShift),
                "ctrl":  flags.contains(.maskControl),
                "alt":   flags.contains(.maskAlternate),
                "meta":  flags.contains(.maskCommand),
            ],
            "timestamp": Date().timeIntervalSince1970,
        ]

        DispatchQueue.main.async { sink(payload) }
    }

    private func modifierIsDown(keyCode: Int64, flags: CGEventFlags) -> Bool {
        switch Int(keyCode) {
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
