import AppKit

/// Watches which app gains focus (system-wide) and switches the keyboard to
/// the layout configured for that app. Uses NSWorkspace notifications — no
/// polling. Always switches when a matching rule is found, regardless of the
/// current layout (unlike FocusLanguageEnforcer which only acts on non-Latin).
final class AppLanguageEnforcer: ObservableObject {
    @Published var enabled: Bool = (UserDefaults.standard.object(forKey: "app_lang_rules_enabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "app_lang_rules_enabled")
            enabled ? start() : stop()
        }
    }

    private let store: AppLanguageRuleStore
    private var observer: Any?

    init(store: AppLanguageRuleStore) {
        self.store = store
    }

    func startIfEnabled() { if enabled { start() } }

    func start() {
        stop()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.appDidActivate(note)
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private func appDidActivate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }
        guard let rule = store.rules.first(where: { $0.bundleID == bundleID }) else { return }
        KeyboardLanguage.select(id: rule.inputSourceID)
    }
}
