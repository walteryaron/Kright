import XCTest
@testable import Kright

/// Pure-logic tests — no OS permissions, input sources, or AX needed.

final class LayoutConverterTests: XCTestCase {

    func testScriptDetection() {
        XCTAssertTrue(LayoutConverter.isHebrew("ש"))
        XCTAssertTrue(LayoutConverter.isHebrew("ת"))
        XCTAssertFalse(LayoutConverter.isHebrew("a"))
        XCTAssertTrue(LayoutConverter.isLatin("a"))
        XCTAssertTrue(LayoutConverter.isLatin("Z"))
        XCTAssertFalse(LayoutConverter.isLatin("ש"))
        XCTAssertFalse(LayoutConverter.isLatin("5"))
    }

    func testEnglishToHebrewAndBack() {
        // "exit" typed on a Hebrew layout comes out "קסןא" (e→ק x→ס i→ן t→א).
        XCTAssertEqual(LayoutConverter.enToHebrew("exit"), "קסןא")
        XCTAssertEqual(LayoutConverter.heToEnglish("קסןא"), "exit")
    }

    func testRoundTripLatin() {
        for word in ["hello", "world", "keyboard", "shalom", "right"] {
            XCTAssertEqual(LayoutConverter.heToEnglish(LayoutConverter.enToHebrew(word)), word,
                           "round-trip failed for \(word)")
        }
    }

    func testSpacesAndUnmappedPassThrough() {
        XCTAssertEqual(LayoutConverter.enToHebrew("a b"), "ש נ")   // space passes through
        XCTAssertEqual(LayoutConverter.enToHebrew("a1"), "ש1")     // digit passes through
    }
}

final class LanguageModelTests: XCTestCase {

    func testBundledModelsPresent() {
        for code in ["he", "ru", "uk", "bg", "sr", "mk", "el", "fa", "hy", "ka"] {
            XCTAssertNotNil(LanguageModelData.byLang[code], "missing bundled model: \(code)")
        }
    }

    /// Each model should score real words of its language well above random
    /// strings from the same alphabet — that's what powers the detector.
    func testModelsScoreRealWordsHigher() {
        func model(_ code: String) -> BigramModel { BigramModel(entry: LanguageModelData.byLang[code]!) }

        let ru = model("ru")
        XCTAssertGreaterThan(ru.score("мама"), ru.score("ъыь"))
        XCTAssertGreaterThan(ru.score("россия"), ru.score("щщщщ"))

        let he = model("he")
        XCTAssertGreaterThan(he.score("שלום"), he.score("ךךךך"))

        let el = model("el")
        XCTAssertGreaterThan(el.score("καλη"), el.score("ψψψψ"))
    }
}

final class KeyboardLanguageTests: XCTestCase {

    func testLatinLanguages() {
        for code in ["en", "en-US", "fr", "de", "es", "it", "pt", "nl", "tr", "vi", ""] {
            XCTAssertTrue(KeyboardLanguage.isLatinLanguage(code), "\(code) should be Latin")
        }
    }

    func testNonLatinLanguages() {
        for code in ["he", "iw", "ar", "fa", "ru", "uk", "el", "hy", "ka",
                     "zh", "zh-Hans", "ja", "ko", "th", "hi"] {
            XCTAssertFalse(KeyboardLanguage.isLatinLanguage(code), "\(code) should be non-Latin")
        }
    }
}

// MARK: - Punctuation key mappings (EN↔HE fallback table)

final class LayoutConverterPunctuationTests: XCTestCase {

    // ---- Individual keys ----

    func testSemicolon_enToHe() { XCTAssertEqual(LayoutConverter.enToHebrew(";"),  "ף") }
    func testSemicolon_heToEn() { XCTAssertEqual(LayoutConverter.heToEnglish("ף"), ";") }

    func testApostrophe_enToHe() { XCTAssertEqual(LayoutConverter.enToHebrew("'"),  ",") }
    func testApostrophe_heToEn() { XCTAssertEqual(LayoutConverter.heToEnglish(","), "'") }

    func testComma_enToHe() { XCTAssertEqual(LayoutConverter.enToHebrew(","),  "ת") }
    func testComma_heToEn() { XCTAssertEqual(LayoutConverter.heToEnglish("ת"), ",") }

    func testPeriod_enToHe() { XCTAssertEqual(LayoutConverter.enToHebrew("."),  "ץ") }
    func testPeriod_heToEn() { XCTAssertEqual(LayoutConverter.heToEnglish("ץ"), ".") }

    func testSlash_enToHe() { XCTAssertEqual(LayoutConverter.enToHebrew("/"),  ".") }
    func testSlash_heToEn() { XCTAssertEqual(LayoutConverter.heToEnglish("."), "/") }

    func testGrave_enToHe() { XCTAssertEqual(LayoutConverter.enToHebrew("`"),  ";") }
    func testGrave_heToEn() { XCTAssertEqual(LayoutConverter.heToEnglish(";"), "`") }

    // W key: real Israeli keyboard produces Hebrew Geresh ׳ (U+05F3), not ASCII apostrophe.
    func testW_enToHe() { XCTAssertEqual(LayoutConverter.enToHebrew("w"),  "׳") }
    func testW_heToEn() { XCTAssertEqual(LayoutConverter.heToEnglish("׳"), "w") }

    // ---- Phrases with punctuation ----

    func testPhrase_helloComma_enToHe() {
        // h→י e→ק l→ך l→ך o→ם ,→ת
        XCTAssertEqual(LayoutConverter.enToHebrew("hello,"), "יקךךםת")
    }

    func testPhrase_helloComma_heToEn() {
        XCTAssertEqual(LayoutConverter.heToEnglish("יקךךםת"), "hello,")
    }

    func testPhrase_dont_enToHe() {
        // apostrophe key in Hebrew layout produces comma: '→,
        XCTAssertEqual(LayoutConverter.enToHebrew("don't"), "גםמ,א")
    }

    func testPhrase_dont_heToEn() {
        XCTAssertEqual(LayoutConverter.heToEnglish("גםמ,א"), "don't")
    }

    // ---- Round-trips ----

    func testAllPunctuationRoundTrip() {
        // Every punctuation key: EN→HE→EN must return to original.
        let keys = ";',./" + "`" + "w"
        XCTAssertEqual(LayoutConverter.heToEnglish(LayoutConverter.enToHebrew(keys)), keys)
    }
}
