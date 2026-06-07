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
