import Carbon
import Cocoa

/// Reads the REAL character produced by each physical key in a given input
/// source (via UCKeyTranslate on the layout's Unicode data), so wrong-layout
/// conversion matches what the user's keyboard actually types — including
/// quirks like Hebrew `w` → `׳` that a hardcoded table gets wrong. Works for any
/// language pair, not just Hebrew.
enum KeyboardLayoutMap {
    // Physical keys that produce text (letters/digits/punctuation live in 0...50).
    private static let keyCodes: [UInt16] = Array(0...50)

    // keycode → produced character, cached per input-source id (layouts are static).
    private static var forwardCache: [String: [UInt16: String]] = [:]
    private static var shiftedCache: [String: [UInt16: String]] = [:]

    static func convert(_ text: String, fromID: String, toID: String) -> String? {
        let fromReverse = reverseMap(fromID)   // char → keycode (source layout)
        let toForward = forwardMap(toID)        // keycode → char (target layout)
        guard !fromReverse.isEmpty, !toForward.isEmpty else { return nil }

        var changed = false
        let result = String(text.map { ch -> Character in
            if let kc = fromReverse[String(ch)], let mapped = toForward[kc]?.first {
                if mapped != ch { changed = true }
                return mapped
            }
            return ch
        })
        return changed ? result : nil
    }

    // MARK: - Maps

    static func forwardMap(_ sourceID: String) -> [UInt16: String] {
        if let cached = forwardCache[sourceID] { return cached }
        var map: [UInt16: String] = [:]
        if let data = layoutData(for: sourceID) {
            for kc in keyCodes {
                if let ch = character(keyCode: kc, layoutData: data, modifiers: 0),
                   !ch.isEmpty, ch != " " {
                    map[kc] = ch
                }
            }
        }
        forwardCache[sourceID] = map
        return map
    }

    /// Characters each key produces when Shift is held (Shift modifierKeyState = 2
    /// in UCKeyTranslate terms). Used to resolve Shift+digit → !, @, # etc.
    static func shiftedForwardMap(_ sourceID: String) -> [UInt16: String] {
        if let cached = shiftedCache[sourceID] { return cached }
        var map: [UInt16: String] = [:]
        if let data = layoutData(for: sourceID) {
            for kc in keyCodes {
                if let ch = character(keyCode: kc, layoutData: data, modifiers: 2),
                   !ch.isEmpty, ch != " " {
                    map[kc] = ch
                }
            }
        }
        shiftedCache[sourceID] = map
        return map
    }

    private static func reverseMap(_ sourceID: String) -> [String: UInt16] {
        var map: [String: UInt16] = [:]
        for (kc, ch) in forwardMap(sourceID) where map[ch] == nil {
            map[ch] = kc
        }
        return map
    }

    // MARK: - UCKeyTranslate

    private static func layoutData(for sourceID: String) -> CFData? {
        let props = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary
        guard let list = TISCreateInputSourceList(props, false)?.takeRetainedValue()
                as? [TISInputSource] else { return nil }
        for src in list {
            guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID),
                  (Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? String) == sourceID
            else { continue }
            guard let dataPtr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return nil }
            return (Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue())
        }
        return nil
    }

    private static func character(keyCode: UInt16, layoutData: CFData, modifiers: UInt32) -> String? {
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }
        return bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layoutPtr -> String? in
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let err = UCKeyTranslate(
                layoutPtr,
                keyCode,
                UInt16(kUCKeyActionDown),
                modifiers,                          // 0 = base, 2 = Shift
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars)
            guard err == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}
