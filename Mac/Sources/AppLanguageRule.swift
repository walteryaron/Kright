import Foundation
import AppKit

struct AppLanguageRule: Codable, Identifiable {
    var id: UUID = UUID()
    var bundleID: String
    var appName: String
    var inputSourceID: String
    var layoutName: String
}

final class AppLanguageRuleStore: ObservableObject {
    @Published var rules: [AppLanguageRule] = [] {
        didSet { save() }
    }

    private let key = "app_language_rules"

    init() { load() }

    /// Reads the current frontmost app (works because Kright is LSUIElement —
    /// it never claims frontmost status, so NSWorkspace still reports the real
    /// last-focused regular app even while the Settings popover is open).
    @discardableResult
    func addFrontmostApp(inputSourceID: String, layoutName: String) -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier,
              !rules.contains(where: { $0.bundleID == bundleID }) else { return nil }
        let name = app.localizedName ?? bundleID
        rules.append(AppLanguageRule(
            bundleID: bundleID, appName: name,
            inputSourceID: inputSourceID, layoutName: layoutName))
        return name
    }

    static func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AppLanguageRule].self, from: data) else { return }
        rules = decoded
    }
}
