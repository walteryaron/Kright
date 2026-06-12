import Cocoa
import Carbon

/// Reads and changes the macOS keyboard input source (the language in the
/// menu-bar input menu).
enum KeyboardLanguage {

    static func enabledSources() -> [InputSource] {
        let current = currentSourceID()
        let raw: [(id: String, layout: String, lang: String)] = keyboardSources()
            .filter { isSelectable($0) }
            .map { src in
                let id = stringProp(src, kTISPropertyInputSourceID) ?? ""
                let langs = getProp(src, kTISPropertyInputSourceLanguages) as? [String] ?? []
                return (id, stringProp(src, kTISPropertyLocalizedName) ?? id, langs.first ?? "")
            }
        // Display the language ("English", "Hebrew") like System Settings, not
        // the layout name ("ABC", "U.S."). Only when two enabled layouts share a
        // language does the layout name come back to tell them apart:
        // "English (ABC)", "English (U.S.)".
        let names = raw.map { languageName($0.lang) ?? $0.layout }
        var counts: [String: Int] = [:]
        names.forEach { counts[$0, default: 0] += 1 }
        return zip(raw, names).map { item, name in
            let display = (counts[name] ?? 0) > 1 && name != item.layout
                ? "\(name) (\(item.layout))" : name
            return InputSource(id: item.id, name: display, lang: item.lang,
                               isCurrent: item.id == current)
        }
    }

    /// "en" → "English", "en-GB" → "English (United Kingdom)"; nil if unknown.
    static func languageName(_ lang: String) -> String? {
        guard !lang.isEmpty else { return nil }
        return Locale(identifier: "en")
            .localizedString(forIdentifier: lang.replacingOccurrences(of: "-", with: "_"))
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
        if !letters.isEmpty {
            let latin = letters.filter { LayoutConverter.isLatin($0) }.count
            return latin * 2 >= letters.count                  // majority Latin
        }
        // No usable letters in the map (e.g. an IME-backed source like Pinyin or
        // Kana) — fall back to the source's language code, otherwise a non-Latin
        // IME would be misread as Latin and the enforcer would never switch.
        let lang = enabledSources().first { $0.id == sourceID }?.lang ?? ""
        return isLatinLanguage(lang)
    }

    /// Best-effort: does this BCP-47 language code use Latin script? Defaults to
    /// true for unknown codes (don't disrupt), but recognises the common
    /// non-Latin scripts. Only used as a fallback when a layout exposes no
    /// character map.
    static func isLatinLanguage(_ lang: String) -> Bool {
        let code = String(lang.lowercased().prefix(2))
        let nonLatin: Set<String> = [
            "he", "iw",                                              // Hebrew
            "ar", "fa", "ur", "ps", "sd",                           // Arabic script
            "ru", "uk", "be", "bg", "sr", "mk", "kk", "ky", "mn", "tg", // Cyrillic
            "el",                                                    // Greek
            "hy", "ka",                                              // Armenian, Georgian
            "zh", "ja", "ko", "yi",                                  // CJK, Yiddish
            "th", "lo", "km", "my",                                  // SE Asian
            "hi", "bn", "ta", "te", "kn", "ml", "gu", "pa", "si", "mr", "ne", // Indic
            "am", "ti",                                              // Ethiopic
        ]
        return code.isEmpty || !nonLatin.contains(code)
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
