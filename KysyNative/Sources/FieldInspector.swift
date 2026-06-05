import Cocoa
import Combine

/// Live inspector for the focused field in other apps. Polls the Accessibility
/// tree while the panel is open and exposes language + replace actions.
final class FieldInspector: ObservableObject {
    @Published var field: FocusedField?
    @Published var languages: [InputSource] = []
    @Published var busy = false
    @Published var replaceResult: String?

    private var timer: Timer?
    private let ownPid = getpid()

    func startPolling() {
        poll()
        loadLanguages()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        let f = AXInspector.focusedField(ignoring: ownPid)
        // Keep the last real element visible while focus is on Kysy itself.
        if f.isSelf, let cur = field, cur.hasElement { return }
        field = f
    }

    // MARK: - Languages

    func loadLanguages() {
        languages = KeyboardLanguage.enabledSources()
    }

    var currentLanguage: InputSource? { languages.first(where: { $0.isCurrent }) }

    /// True when on a language other than the first/primary one.
    var forced: Bool {
        guard languages.count > 1, let cur = currentLanguage else { return false }
        return languages.first?.id != cur.id
    }

    func selectLanguage(_ id: String) {
        _ = KeyboardLanguage.select(id: id)
        loadLanguages()
    }

    func toggleForce(_ on: Bool) {
        guard languages.count > 1 else { return }
        if on {
            _ = KeyboardLanguage.switchToNext()
        } else if let first = languages.first {
            _ = KeyboardLanguage.select(id: first.id)
        }
        loadLanguages()
    }

    // MARK: - Replace (wrong-layout fix)

    func replace(with text: String) {
        guard !busy else { return }
        busy = true
        replaceResult = nil
        let res = AXInspector.setFocusedValue(text)
        busy = false
        replaceResult = res.ok ? "Replaced ✓" : "Could not replace: \(res.error)"
        poll()
    }

    // MARK: - Permission

    func requestAccess() { AXInspector.requestAccess() }
    func openSettings() { AXInspector.openAccessibilitySettings() }
}
