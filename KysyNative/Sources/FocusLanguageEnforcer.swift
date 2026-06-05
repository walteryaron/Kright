import Cocoa
import Combine

/// Watches which field is focused (system-wide) and, when it lands on a field
/// that must be typed in English (email / URL / password / payment), switches
/// the keyboard to an English input source. Runs in the background regardless of
/// whether the panel is open. Opt-in via Settings.
final class FocusLanguageEnforcer: ObservableObject {
    @Published var enabled: Bool = UserDefaults.standard.bool(forKey: "auto_lang_enabled") {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "auto_lang_enabled")
            enabled ? start() : stop()
        }
    }
    @Published var lastAction: String?

    /// Field kinds (from FocusedField.guess) that should be typed in Latin.
    private let latinKinds: Set<String> = ["Email", "URL", "Password", "Payment"]

    private var timer: Timer?
    private let ownPid = getpid()
    private var lastSignature = ""

    func startIfEnabled() { if enabled { start() } }

    func start() {
        timer?.invalidate()
        // Light: only reads ~7 attributes per tick, and only acts on focus change.
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastSignature = ""
    }

    private func tick() {
        guard AXIsProcessTrusted(),
              let field = AXInspector.focusedFieldLight(ignoring: ownPid) else { return }

        // Only act when focus actually moves to a new field.
        let sig = "\(field.pid ?? 0)|\(field.role ?? "")|\(field.placeholder ?? "")|\(field.title ?? "")"
        if sig == lastSignature { return }
        lastSignature = sig

        let kind = field.guess.label
        guard latinKinds.contains(kind) else { return }

        // Already on English? Nothing to do.
        guard let current = KeyboardLanguage.current(), !current.lang.hasPrefix("en") else { return }
        guard let english = KeyboardLanguage.firstEnglish() else { return }

        _ = KeyboardLanguage.select(id: english.id)
        DispatchQueue.main.async {
            self.lastAction = "Switched to \(english.name) for \(kind) field"
        }
    }
}
