import Cocoa
import ApplicationServices

/// Reads the system-wide focused UI element and all its Accessibility attributes,
/// and can write a corrected value back into it.
enum AXInspector {

    /// Most recent focused element that wasn't Kysy itself, kept so we can write
    /// back even after Kysy steals focus. AX value-setting doesn't require focus.
    static var lastFocusedElement: AXUIElement?

    static func isTrusted() -> Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestAccess() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func focusedField(ignoring ownPid: pid_t) -> FocusedField {
        guard AXIsProcessTrusted() else { return .empty }

        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focused)

        guard err == .success, let focusedRef = focused else {
            return FocusedField(trusted: true, hasElement: false, isSelf: false,
                                appName: nil, pid: nil, attributes: [:])
        }
        let element = focusedRef as! AXUIElement

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid == ownPid {
            return FocusedField(trusted: true, hasElement: false, isSelf: true,
                                appName: nil, pid: Int(pid), attributes: [:])
        }

        lastFocusedElement = element

        var appName: String?
        if let app = NSRunningApplication(processIdentifier: pid) {
            appName = app.localizedName
        }

        var attributes: [String: String] = [:]
        var namesRef: CFArray?
        if AXUIElementCopyAttributeNames(element, &namesRef) == .success,
           let names = namesRef as? [String] {
            for name in names {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
                   let value = value {
                    attributes[name] = stringify(value)
                }
            }
        }
        return FocusedField(trusted: true, hasElement: true, isSelf: false,
                            appName: appName, pid: Int(pid), attributes: attributes)
    }

    /// Cheap read of only the type-relevant attributes of the focused element —
    /// for the background language enforcer (avoids enumerating everything).
    /// Returns nil if not trusted, no element, or the element is Kysy itself.
    static func focusedFieldLight(ignoring ownPid: pid_t) -> FocusedField? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let ref = focused else { return nil }
        let element = ref as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid == ownPid { return nil }

        var attrs: [String: String] = [:]
        let keys = ["AXRole", "AXSubrole", "AXPlaceholderValue", "AXTitle",
                    "AXDescription", "AXHelp", "AXRoleDescription"]
        for key in keys {
            var v: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, key as CFString, &v) == .success,
               let s = v as? String {
                attrs[key] = s
            }
        }
        return FocusedField(trusted: true, hasElement: true, isSelf: false,
                            appName: nil, pid: Int(pid), attributes: attrs)
    }

    /// Reads the currently focused (non-Kysy) element and its text value, fresh —
    /// used by the global hotkey, which fires while the target app is focused
    /// (no panel open, so `lastFocusedElement` may be stale).
    static func focusedValue() -> (element: AXUIElement, value: String)? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let ref = focused else { return nil }
        let element = ref as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid == getpid() { return nil }
        var v: CFTypeRef?
        let value = (AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &v) == .success
                     ? (v as? String) : nil) ?? ""
        return (element, value)
    }

    /// Writes `text` into a specific element. Returns success + error.
    @discardableResult
    static func setValue(_ text: String, on element: AXUIElement) -> (ok: Bool, error: String) {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        if settable == false { return (false, "value not settable on this field") }
        let err = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        return (err == .success, describe(error: err))
    }

    /// Writes `text` into the last focused (non-Kysy) field. Returns success + error.
    static func setFocusedValue(_ text: String) -> (ok: Bool, error: String) {
        guard AXIsProcessTrusted() else { return (false, "not trusted") }
        guard let el = lastFocusedElement else { return (false, "no remembered element") }

        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable)
        if settable == false { return (false, "value not settable on this field") }

        let err = AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, text as CFTypeRef)
        return (err == .success, describe(error: err))
    }

    // MARK: - Helpers

    private static func stringify(_ value: CFTypeRef) -> String {
        let typeID = CFGetTypeID(value)
        if typeID == CFStringGetTypeID() { return value as! String }
        if typeID == CFBooleanGetTypeID() { return (value as! Bool) ? "true" : "false" }
        if typeID == CFNumberGetTypeID() { return "\(value as! NSNumber)" }
        if typeID == AXUIElementGetTypeID() {
            let el = value as! AXUIElement
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role) == .success,
               let r = role as? String {
                return "<\(r)>"
            }
            return "<AXUIElement>"
        }
        if typeID == AXValueGetTypeID() { return describe(axValue: value as! AXValue) }
        if typeID == CFArrayGetTypeID() {
            let arr = value as! [AnyObject]
            return "[\(arr.count) items]"
        }
        return "\(value)"
    }

    private static func describe(axValue: AXValue) -> String {
        switch AXValueGetType(axValue) {
        case .cgPoint:
            var p = CGPoint.zero; AXValueGetValue(axValue, .cgPoint, &p)
            return "(\(Int(p.x)), \(Int(p.y)))"
        case .cgSize:
            var s = CGSize.zero; AXValueGetValue(axValue, .cgSize, &s)
            return "\(Int(s.width))×\(Int(s.height))"
        case .cgRect:
            var r = CGRect.zero; AXValueGetValue(axValue, .cgRect, &r)
            return "(\(Int(r.origin.x)), \(Int(r.origin.y))) \(Int(r.size.width))×\(Int(r.size.height))"
        case .cfRange:
            var range = CFRange(location: 0, length: 0); AXValueGetValue(axValue, .cfRange, &range)
            return "loc \(range.location), len \(range.length)"
        default:
            return "<AXValue>"
        }
    }

    private static func describe(error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .noValue: return "noValue"
        case .attributeUnsupported: return "attributeUnsupported"
        case .cannotComplete: return "cannotComplete"
        case .notImplemented: return "notImplemented"
        case .apiDisabled: return "apiDisabled"
        case .invalidUIElement: return "invalidUIElement"
        default: return "axError(\(error.rawValue))"
        }
    }
}
