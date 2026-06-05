import Foundation

/// Converts text between English (QWERTY) and Hebrew (standard Israeli) keyboard
/// layouts — same physical keys, different characters. "exit" typed while Hebrew
/// is active comes out "קסןא".
enum LayoutConverter {
    static let enToHe: [Character: Character] = [
        "q": "/", "w": "'", "e": "ק", "r": "ר", "t": "א", "y": "ט", "u": "ו",
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
    static func suggest(_ fullText: String) -> LayoutSuggestion? {
        guard let token = fullText.split(whereSeparator: { $0.isWhitespace }).last else { return nil }
        let word = String(token)
        guard word.count <= 120 else { return nil }

        let letters = word.filter { isHebrew($0) || isLatin($0) }
        guard letters.count >= 3 else { return nil }
        let he = letters.filter(isHebrew).count
        let en = letters.filter(isLatin).count
        guard he != en else { return nil }
        let hebrewDominant = he > en

        // Prefer the REAL installed layouts (handles quirks like Hebrew w → ׳,
        // and any language pair). Fall back to the built-in table if a source
        // isn't available.
        let english = KeyboardLanguage.firstEnglish()
        let other = KeyboardLanguage.firstNonEnglish()

        let converted: String, from: String, to: String
        if hebrewDominant {
            from = other?.name ?? "Hebrew"; to = english?.name ?? "English"
            converted = (english != nil && other != nil
                ? KeyboardLayoutMap.convert(word, fromID: other!.id, toID: english!.id) : nil)
                ?? heToEnglish(word)
        } else {
            from = english?.name ?? "English"; to = other?.name ?? "Hebrew"
            converted = (english != nil && other != nil
                ? KeyboardLayoutMap.convert(word, fromID: english!.id, toID: other!.id) : nil)
                ?? enToHebrew(word)
        }

        // Rebuild the full value with only the last word swapped, so Replace
        // doesn't wipe the rest of the field.
        var fullReplacement = converted
        if let range = fullText.range(of: word, options: .backwards) {
            fullReplacement = fullText.replacingCharacters(in: range, with: converted)
        }

        return LayoutSuggestion(original: word, converted: converted,
                                fullReplacement: fullReplacement,
                                fromLayout: from, toLayout: to)
    }
}

struct LayoutSuggestion {
    let original: String
    let converted: String
    let fullReplacement: String
    let fromLayout: String
    let toLayout: String

    var isMeaningful: Bool {
        converted != original && !converted.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
