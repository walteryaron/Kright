import Foundation

/// A single global keyboard event observed by the passive event tap.
struct KeyEvent: Identifiable {
    let id = UUID()
    let keyCode: Int
    let isDown: Bool
    let shift: Bool
    let ctrl: Bool
    let alt: Bool
    let meta: Bool
    let timestamp: Date

    var modifierString: String {
        var parts: [String] = []
        if meta { parts.append("⌘") }
        if shift { parts.append("⇧") }
        if alt { parts.append("⌥") }
        if ctrl { parts.append("⌃") }
        return parts.joined()
    }
}

/// A keyboard input source (language/layout) enabled on the system.
struct InputSource: Identifiable {
    let id: String
    let name: String
    let lang: String
    let isCurrent: Bool
}

/// Snapshot of the currently focused UI element from the Accessibility API.
struct FocusedField {
    let trusted: Bool
    let hasElement: Bool
    let isSelf: Bool
    let appName: String?
    let pid: Int?
    let attributes: [String: String]

    static let empty = FocusedField(
        trusted: false, hasElement: false, isSelf: false,
        appName: nil, pid: nil, attributes: [:])

    var role: String? { attributes["AXRole"] }
    var subrole: String? { attributes["AXSubrole"] }
    var placeholder: String? { attributes["AXPlaceholderValue"] }
    var title: String? { attributes["AXTitle"] }
    var fieldDescription: String? { attributes["AXDescription"] }
    var help: String? { attributes["AXHelp"] }
    var value: String { attributes["AXValue"] ?? "" }

    /// Best-effort inference of the field's purpose.
    var guess: FieldGuess {
        if subrole == "AXSecureTextField" {
            return FieldGuess(label: "Password", basis: "AXSecureTextField subrole", confidence: 1.0)
        }
        let isTextish = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role ?? "")
        let hay = [placeholder, title, fieldDescription, help, attributes["AXRoleDescription"]]
            .compactMap { $0 }.joined(separator: " ").lowercased()

        func any(_ needles: [String]) -> Bool { needles.contains { hay.contains($0) } }

        if role == "AXSearchField" || hay.contains("search") {
            return FieldGuess(label: "Search", basis: "role/label", confidence: 0.8)
        }
        if any(["phone", "tel", "mobile", "cell"]) {
            return FieldGuess(label: "Phone number", basis: "label keyword", confidence: 0.7)
        }
        if any(["email", "e-mail"]) {
            return FieldGuess(label: "Email", basis: "label keyword", confidence: 0.7)
        }
        if any(["first name", "last name", "full name", "name"]) {
            return FieldGuess(label: "Name", basis: "label keyword", confidence: 0.6)
        }
        if any(["address", "street", "city", "zip", "postal"]) {
            return FieldGuess(label: "Address", basis: "label keyword", confidence: 0.6)
        }
        if any(["url", "website", "http"]) {
            return FieldGuess(label: "URL", basis: "label keyword", confidence: 0.6)
        }
        if any(["card", "cvv", "expiry", "expiration"]) {
            return FieldGuess(label: "Payment", basis: "label keyword", confidence: 0.5)
        }
        if any(["date", "birthday", "dob"]) {
            return FieldGuess(label: "Date", basis: "label keyword", confidence: 0.5)
        }
        if isTextish {
            return FieldGuess(label: "Generic text field", basis: "role only", confidence: 0.3)
        }
        return FieldGuess(label: "Not a text field", basis: "role", confidence: 0.0)
    }
}

struct FieldGuess {
    let label: String
    let basis: String
    let confidence: Double
}
