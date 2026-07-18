import AppKit

/// Switches the keyboard based on which conversation is open inside a supported
/// chat app (WhatsApp / Teams). Complements `AppLanguageEnforcer`: that one acts
/// on app switches (per bundle ID); this one acts on chat switches *within* an
/// app (per contact).
///
/// There's no system notification for "the open chat changed", so while a watched
/// app is frontmost we poll on a light timer. Polling only runs while such an app
/// is frontmost — never globally — and the WhatsApp AX walk is node-budgeted, so
/// the cost stays low. When no contact rule matches, we do nothing and leave any
/// per-app rule in effect (contact rules refine, not replace, per-app rules).
final class ContactLanguageEnforcer: ObservableObject {
    @Published var enabled: Bool = (UserDefaults.standard.object(forKey: "contact_lang_rules_enabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "contact_lang_rules_enabled")
            enabled ? start() : stop()
        }
    }

    /// The most recent chat Kright saw while a watched app was frontmost — read by
    /// the Settings "Add current contact" button. Captured during polling (while
    /// the app is genuinely frontmost), so it survives the user opening Kright's
    /// popover, which changes what's frontmost. Mirrors the Windows enforcer's
    /// LastContactApp/LastContactName.
    @Published var lastContactApp: ContactApp?
    @Published var lastContactName: String?

    private let store: ContactLanguageRuleStore
    private var observer: Any?
    private var timer: Timer?
    private var currentApp: ContactApp?
    private var lastSwitched: String?

    init(store: ContactLanguageRuleStore) {
        self.store = store
    }

    func startIfEnabled() { if enabled { start() } }

    func start() {
        stop()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            self?.appDidActivate(note)
        }
        // Handle the app that's already frontmost at start time.
        if let front = NSWorkspace.shared.frontmostApplication,
           let bundleID = front.bundleIdentifier {
            beginWatching(ContactApp.from(bundleID: bundleID))
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        stopPolling()
    }

    private func appDidActivate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        beginWatching(app.bundleIdentifier.flatMap(ContactApp.from(bundleID:)))
    }

    /// Start (or stop) polling depending on whether a watched app is now frontmost.
    private func beginWatching(_ app: ContactApp?) {
        stopPolling()                // clears any prior timer + currentApp first
        guard let app else { return }
        currentApp = app
        lastSwitched = nil           // force a re-apply on (re)entering the app
        // Fire the first check slightly late so it lands *after* AppLanguageEnforcer's
        // synchronous per-app switch on activation — the contact rule wins.
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            self?.poll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.poll() }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
        currentApp = nil
        lastSwitched = nil
        // Keep lastContactApp/lastContactName — the Settings button needs the last
        // chat we saw even after leaving the app (to open Kright's popover).
    }

    private func poll() {
        guard let app = currentApp else { return }
        guard let contact = ChatContactDetector.currentContact(for: app) else { return }

        // Remember it for the "Add current contact" button, regardless of rules.
        lastContactApp = app
        lastContactName = contact

        guard contact != lastSwitched else { return }
        lastSwitched = contact
        guard let rule = store.rules.first(where: { $0.app == app && $0.contactName == contact }) else { return }
        KeyboardLanguage.select(id: rule.inputSourceID)
    }
}
