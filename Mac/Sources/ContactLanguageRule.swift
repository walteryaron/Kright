import Foundation
import AppKit

/// The two chat apps whose open conversation Kright can detect. Each maps to a
/// bundle ID (used to tell when it's frontmost) and drives the app-specific
/// detection strategy in `ChatContactDetector`.
enum ContactApp: String, Codable, CaseIterable {
    case whatsapp
    case teams

    var bundleID: String {
        switch self {
        case .whatsapp: return "net.whatsapp.WhatsApp"
        case .teams:    return "com.microsoft.teams2"
        }
    }

    var displayName: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .teams:    return "Microsoft Teams"
        }
    }

    /// SF Symbol used as the row glyph (chat apps don't expose a stable icon path
    /// the way per-app rules do, so a symbol keeps it simple and consistent).
    var symbolName: String {
        switch self {
        case .whatsapp: return "message.fill"
        case .teams:    return "person.2.fill"
        }
    }

    static func from(bundleID: String) -> ContactApp? {
        allCases.first { $0.bundleID == bundleID }
    }
}

/// A rule: "when the open conversation in <app> is <contactName>, switch the
/// keyboard to <inputSourceID>". Mirrors `AppLanguageRule` but keyed on a
/// contact display name instead of a bundle ID.
struct ContactLanguageRule: Codable, Identifiable {
    var id: UUID = UUID()
    var app: ContactApp
    var contactName: String
    var inputSourceID: String
    var layoutName: String
}

final class ContactLanguageRuleStore: ObservableObject {
    @Published var rules: [ContactLanguageRule] = [] {
        didSet { save() }
    }

    private let key = "contact_language_rules"

    init() { load() }

    /// Adds a rule for the given already-detected contact. The contact comes from
    /// `ContactLanguageEnforcer.lastContactName` (captured while the chat app was
    /// frontmost), NOT read live here — by the time the Settings popover is open,
    /// the chat app is no longer frontmost. Returns a status string for the UI.
    @discardableResult
    func add(app: ContactApp, contactName: String, inputSourceID: String, layoutName: String) -> String {
        let name = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "No open chat detected" }
        guard !rules.contains(where: { $0.app == app && $0.contactName == name }) else {
            return "Rule for \(name) already exists"
        }
        rules.append(ContactLanguageRule(
            app: app, contactName: name,
            inputSourceID: inputSourceID, layoutName: layoutName))
        return "Added \(name)"
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ContactLanguageRule].self, from: data) else { return }
        rules = decoded
    }
}
