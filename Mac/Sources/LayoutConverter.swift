import Foundation

/// Converts text between English (QWERTY) and Hebrew (standard Israeli) keyboard
/// layouts — same physical keys, different characters. "exit" typed while Hebrew
/// is active comes out "קסןא".
enum LayoutConverter {
    static let enToHe: [Character: Character] = [
        "q": "/", "w": "׳", "e": "ק", "r": "ר", "t": "א", "y": "ט", "u": "ו",
        "i": "ן", "o": "ם", "p": "פ", "a": "ש", "s": "ד", "d": "ג", "f": "כ",
        "g": "ע", "h": "י", "j": "ח", "k": "ל", "l": "ך", "z": "ז", "x": "ס",
        "c": "ב", "v": "ה", "b": "נ", "n": "מ", "m": "צ",
        ",": "ת", ".": "ץ", ";": "ף", "'": ",", "/": ".", "`": ";",
    ]

    static let heToEn: [Character: Character] = {
        var m: [Character: Character] = [:]
        for (k, v) in enToHe { m[v] = k }
        return m
    }()

    static func enToHebrew(_ s: String) -> String {
        String(s.map { ch in
            let lower = Character(ch.lowercased())
            return enToHe[lower] ?? ch
        })
    }

    static func heToEnglish(_ s: String) -> String {
        String(s.map { heToEn[$0] ?? $0 })
    }

    static func isHebrew(_ c: Character) -> Bool {
        guard let u = c.unicodeScalars.first?.value else { return false }
        return u >= 0x0590 && u <= 0x05FF
    }

    static func isLatin(_ c: Character) -> Bool {
        guard let u = Character(c.lowercased()).unicodeScalars.first?.value else { return false }
        return u >= 0x61 && u <= 0x7A
    }

    /// Returns a wrong-layout correction candidate, or nil if nothing to fix.
    /// Operates on the LAST whitespace-delimited word, so it works even when the
    /// field value is a whole buffer (e.g. Terminal). Requires ≥3 letters.
    /// Used by the panel, which reads a raw AX value of unknown extent.
    static func suggest(_ fullText: String) -> LayoutSuggestion? {
        guard let token = fullText.split(whereSeparator: { $0.isWhitespace }).last else { return nil }
        return build(unit: String(token), within: fullText)
    }

    /// Converts an ENTIRE typed phrase (which may span several words separated by
    /// spaces), not just the last word — for the layout-fix hotkey, where we hold
    /// the precise run of characters the user just typed. Spaces are preserved.
    static func suggestPhrase(_ phrase: String) -> LayoutSuggestion? {
        guard !phrase.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return build(unit: phrase, within: phrase)
    }

    /// Shared core: decide the conversion direction from the letters in `unit`,
    /// convert the whole `unit` (spaces and other non-mapped chars pass through),
    /// and rebuild `fullText` with `unit` swapped in place.
    private static func build(unit: String, within fullText: String) -> LayoutSuggestion? {
        guard unit.count <= 240 else { return nil }

        // Direction is decided by Latin vs ANY non-Latin script (Hebrew, Cyrillic,
        // Greek, Arabic…), so it works for any installed layout pair — not just
        // Hebrew. (For Hebrew/Latin input the counts are identical to before.)
        let letters = unit.filter { $0.isLetter }
        guard letters.count >= 3 else { return nil }
        let latinCount = letters.filter(isLatin).count
        let otherCount = letters.count - latinCount
        guard latinCount != otherCount else { return nil }
        let typedIsLatin = latinCount > otherCount
        let hebrewScript = letters.contains(where: isHebrew)

        // Prefer the REAL installed layouts (any language pair, incl. quirks like
        // Hebrew w → ׳). The built-in table is a Hebrew-only fallback for when a
        // source's layout data can't be read.
        let english = KeyboardLanguage.firstEnglish()
        let other = KeyboardLanguage.firstNonEnglish()

        let convertedOpt: String?
        let from: String, to: String, toID: String?, fromLang: String, toLang: String
        if typedIsLatin {
            // Latin was typed but the other language was meant → convert to it.
            from = english?.name ?? "English"; to = other?.name ?? "—"; toID = other?.id
            fromLang = english?.lang ?? "en"; toLang = other?.lang ?? ""
            let real = (english != nil && other != nil)
                ? KeyboardLayoutMap.convert(unit, fromID: english!.id, toID: other!.id) : nil
            convertedOpt = real ?? ((other?.lang.hasPrefix("he") ?? false) ? enToHebrew(unit) : nil)
        } else {
            // A non-Latin script was typed but English was meant → convert to it.
            from = other?.name ?? "—"; to = english?.name ?? "English"; toID = english?.id
            fromLang = other?.lang ?? ""; toLang = english?.lang ?? "en"
            let real = (english != nil && other != nil)
                ? KeyboardLayoutMap.convert(unit, fromID: other!.id, toID: english!.id) : nil
            convertedOpt = real ?? (hebrewScript ? heToEnglish(unit) : nil)
        }
        guard let converted = convertedOpt else { return nil }

        // Rebuild the full value with only the converted unit swapped, so Replace
        // doesn't wipe the rest of the field.
        var fullReplacement = converted
        if unit != fullText, let range = fullText.range(of: unit, options: .backwards) {
            fullReplacement = fullText.replacingCharacters(in: range, with: converted)
        }

        return LayoutSuggestion(original: unit, converted: converted,
                                fullReplacement: fullReplacement,
                                fromLayout: from, toLayout: to, toLayoutID: toID,
                                fromLang: fromLang, toLang: toLang)
    }
}

struct LayoutSuggestion {
    let original: String
    let converted: String
    let fullReplacement: String
    let fromLayout: String
    let toLayout: String
    /// Input-source id of the corrected text's layout, so the caller can switch
    /// the keyboard to it (continue typing in the right language). nil if the real
    /// layouts weren't available and the built-in table was used.
    var toLayoutID: String? = nil
    /// BCP-47 language codes of the text as typed (`fromLang`) and as corrected
    /// (`toLang`) — used to pick the right gibberish-detection model.
    var fromLang: String = ""
    var toLang: String = ""

    var isMeaningful: Bool {
        converted != original && !converted.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
