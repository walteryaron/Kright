import Cocoa
import Carbon

/// Reads and changes the macOS keyboard input source (the language in the
/// menu-bar input menu).
enum KeyboardLanguage {

    static func enabledSources() -> [InputSource] {
        let current = currentSourceID()
        return keyboardSources()
            .filter { isSelectable($0) }
            .map { src in
                let id = stringProp(src, kTISPropertyInputSourceID) ?? ""
                let langs = getProp(src, kTISPropertyInputSourceLanguages) as? [String] ?? []
                return InputSource(
                    id: id,
                    name: stringProp(src, kTISPropertyLocalizedName) ?? id,
                    lang: langs.first ?? "",
                    isCurrent: id == current)
            }
    }

    static func currentSourceID() -> String {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return "" }
        return stringProp(src, kTISPropertyInputSourceID) ?? ""
    }

    /// The current input source as a full InputSource (nil if none).
    static func current() -> InputSource? {
        let id = currentSourceID()
        return enabledSources().first { $0.id == id }
    }

    /// First enabled English/Latin input source, if any.
    static func firstEnglish() -> InputSource? {
        enabledSources().first { $0.lang.hasPrefix("en") }
    }

    /// First enabled non-English input source (e.g. Hebrew), if any.
    static func firstNonEnglish() -> InputSource? {
        enabledSources().first { !$0.lang.hasPrefix("en") }
    }

    /// Whether a layout types Latin letters (English, French, Spanish, German…)
    /// rather than a non-Latin script (Hebrew, Arabic, Cyrillic…). Decided from
    /// the characters the layout actually produces, so it's language-agnostic.
    static func isLatinLayout(_ sourceID: String) -> Bool {
        let map = KeyboardLayoutMap.forwardMap(sourceID)
        let keys: [UInt16] = [0, 1, 2, 3, 4, 5, 38, 40, 37]   // A S D F H G J K L
        let letters = keys.compactMap { map[$0]?.first }.filter { $0.isLetter }
        guard !letters.isEmpty else { return true }            // unknown → don't disrupt
        let latin = letters.filter { LayoutConverter.isLatin($0) }.count
        return latin * 2 >= letters.count                      // majority Latin
    }

    /// First enabled Latin-script input source (prefers English), if any.
    static func firstLatin() -> InputSource? {
        let sources = enabledSources()
        return sources.first { $0.lang.hasPrefix("en") && isLatinLayout($0.id) }
            ?? sources.first { isLatinLayout($0.id) }
    }

    @discardableResult
    static func select(id: String) -> String {
        for src in keyboardSources() where stringProp(src, kTISPropertyInputSourceID) == id {
            TISSelectInputSource(src)
            break
        }
        return currentSourceID()
    }

    @discardableResult
    static func switchToNext() -> String {
        let sources = enabledSources()
        guard sources.count > 1 else { return currentSourceID() }
        let current = currentSourceID()
        let idx = sources.firstIndex { $0.id == current } ?? -1
        let next = sources[(idx + 1) % sources.count]
        return select(id: next.id)
    }

    // MARK: - Helpers

    private static func keyboardSources() -> [TISInputSource] {
        let props = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary
        guard let list = TISCreateInputSourceList(props, false)?.takeRetainedValue()
                as? [TISInputSource] else { return [] }
        return list
    }

    private static func isSelectable(_ src: TISInputSource) -> Bool {
        (getProp(src, kTISPropertyInputSourceIsSelectCapable) as? Bool) ?? false
    }

    private static func getProp(_ src: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
    }

    private static func stringProp(_ src: TISInputSource, _ key: CFString) -> String? {
        getProp(src, key) as? String
    }
}
