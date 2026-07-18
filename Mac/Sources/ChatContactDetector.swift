import Cocoa
import ApplicationServices

/// Detects the currently-open conversation (contact / chat / channel name) in a
/// supported chat app, via the Accessibility API — the same mechanism Kright
/// already uses in `AXInspector`. Read-only.
///
/// Two strategies, chosen per app because their UI toolkits differ:
///  • Teams (WebView2/Chromium): the web content is not exposed to AX, but the
///    window *title* carries the chat name → cheap single-attribute read + parse.
///  • WhatsApp (native Catalyst): the window title is useless ("WhatsApp"), but
///    the AX tree exposes the open conversation → a budgeted tree search.
enum ChatContactDetector {

    /// Caps the WhatsApp AX walk so a poll can never turn into an expensive
    /// full-tree crawl on a huge conversation.
    private static let maxNodes = 2500

    static func currentContact(for app: ContactApp) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let pid = runningPID(for: app) else { return nil }
        let appEl = AXUIElementCreateApplication(pid)

        switch app {
        case .teams:    return teamsContact(appEl)
        case .whatsapp: return whatsappContact(appEl)
        }
    }

    // MARK: - Teams (window title)

    /// Titles observed: 1:1  "Chat | <name> | Microsoft Teams"
    ///                   channel  ", Chat | <name> | Microsoft Teams".
    /// Returns nil for non-chat surfaces (Activity / Calls / Calendar tabs).
    private static func teamsContact(_ appEl: AXUIElement) -> String? {
        guard let title = focusedWindowTitle(appEl) else { return nil }
        var s = title
        if let r = s.range(of: " | Microsoft Teams", options: .backwards) {
            s = String(s[..<r.lowerBound])
        } else if s == "Microsoft Teams" {
            return nil
        }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix(", ") { s.removeFirst(2) }
        if s.hasPrefix("Chat | ") { s.removeFirst("Chat | ".count) }
        s = s.trimmingCharacters(in: .whitespaces)

        // A bare tab name (no conversation) isn't a contact.
        let nonChatTabs: Set<String> = ["Activity", "Chat", "Calls", "Calendar",
                                        "Teams", "Files", "Microsoft Teams", ""]
        return nonChatTabs.contains(s) ? nil : s
    }

    // MARK: - WhatsApp (AX tree)

    private static func whatsappContact(_ appEl: AXUIElement) -> String? {
        guard let window = focusedWindow(appEl) else { return nil }
        var budget = maxNodes

        // The open conversation's messages container is described "Messages in chat
        // with <name>" (often with a leading bidi mark, so clean() the string before
        // matching). This is the one unambiguous anchor for the *open* chat — the
        // window title is useless and header buttons can collide with the sidebar
        // list, so we rely solely on this. Not found → no chat open → nil.
        return search(window, budget: &budget) { desc, _ in
            guard let desc else { return nil }
            let c = clean(desc)
            guard c.hasPrefix(messagesPrefix) else { return nil }
            return clean(String(c.dropFirst(messagesPrefix.count)))
        }
    }

    private static let messagesPrefix = "Messages in chat with "

    /// Depth-first search of the AX subtree for the first element whose
    /// (description, role) the `match` closure maps to a non-nil name. Bounded by
    /// `budget` so it stays cheap even on large trees.
    private static func search(_ element: AXUIElement, budget: inout Int,
                               match: (_ desc: String?, _ role: String?) -> String?) -> String? {
        if budget <= 0 { return nil }
        budget -= 1

        let desc = stringAttr(element, kAXDescriptionAttribute)
        let role = stringAttr(element, kAXRoleAttribute)
        if let hit = match(desc, role) { return hit }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        for child in children {
            if let hit = search(child, budget: &budget, match: match) { return hit }
            if budget <= 0 { return nil }
        }
        return nil
    }

    // MARK: - Helpers

    private static func runningPID(for app: ContactApp) -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
            .first?.processIdentifier
    }

    private static func focusedWindow(_ appEl: AXUIElement) -> AXUIElement? {
        var win: CFTypeRef?
        if AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &win) == .success,
           let w = win { return (w as! AXUIElement) }
        // Fall back to the first window if none is reported focused.
        var wins: CFTypeRef?
        if AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &wins) == .success,
           let arr = wins as? [AXUIElement] { return arr.first }
        return nil
    }

    private static func focusedWindowTitle(_ appEl: AXUIElement) -> String? {
        guard let win = focusedWindow(appEl) else { return nil }
        return stringAttr(win, kAXTitleAttribute)
    }

    private static func stringAttr(_ element: AXUIElement, _ key: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &v) == .success,
              let s = v as? String else { return nil }
        return s
    }

    /// AX strings often carry a leading bidi/LTR mark (U+200E) and stray
    /// whitespace; strip them so rule matching compares clean display names.
    private static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: "\u{200E}\u{200F}\u{202A}\u{202C}")
            .union(.whitespacesAndNewlines))
    }
}
