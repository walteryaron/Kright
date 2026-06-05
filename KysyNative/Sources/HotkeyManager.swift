import Carbon
import AppKit
import Combine

/// Registers a global hotkey (works in any app, and consumes the keypress so it
/// doesn't reach the foreground app) and lets the user re-record it. On trigger
/// it calls `onTrigger`.
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published private(set) var displayString = ""
    @Published var recording = false

    var onTrigger: (() -> Void)?

    private var keyCode: UInt32
    private var modifiers: UInt32           // Carbon modifier mask
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    private init() {
        let d = UserDefaults.standard
        keyCode = UInt32(d.object(forKey: "hotkey_keycode") as? Int ?? kVK_ANSI_K)
        modifiers = UInt32(d.object(forKey: "hotkey_modifiers") as? Int ?? (controlKey | optionKey))
        installHandler()
        register()
        refreshDisplay()
    }

    // MARK: - Registration

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async { HotkeyManager.shared.onTrigger?() }
            return noErr
        }, 1, &spec, nil, &eventHandlerRef)
    }

    private func register() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        let id = EventHotKeyID(signature: OSType(0x4B595359 /* 'KYSY' */), id: 1)
        var ref: EventHotKeyRef?
        if RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr {
            hotKeyRef = ref
        }
    }

    func update(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkey_keycode")
        UserDefaults.standard.set(Int(modifiers), forKey: "hotkey_modifiers")
        register()
        refreshDisplay()
    }

    // MARK: - Recording a new shortcut

    func startRecording() {
        guard !recording else { return }
        recording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.capture(e); return nil   // swallow so it doesn't type
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.capture(e)
        }
    }

    func stopRecording() {
        recording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }

    private func capture(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { return }   // require at least one modifier
        update(keyCode: UInt32(event.keyCode), modifiers: Self.carbonModifiers(from: mods))
        stopRecording()
    }

    // MARK: - Display

    private func refreshDisplay() {
        displayString = Self.describe(keyCode: keyCode, carbonModifiers: modifiers)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    static func describe(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + keyName(keyCode)
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        if let en = KeyboardLanguage.firstEnglish(),
           let ch = KeyboardLayoutMap.forwardMap(en.id)[UInt16(keyCode)] {
            return ch.uppercased()
        }
        return "key\(keyCode)"
    }
}
