import XCTest
@testable import Gota

/// Gota follows the Mac's language: every string has its English translation.
final class LocalizationTests: XCTestCase {
    private var english: Bundle!

    override func setUpWithError() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"), "the app has an English localization")
        english = Bundle(path: path)
    }

    private func en(_ key: String) -> String {
        english.localizedString(forKey: key, value: "⚠️ missing", table: nil)
    }

    func testMenuAndSettingsAreTranslated() {
        XCTAssertEqual(en("Salir de Gota"), "Quit Gota")
        XCTAssertEqual(en("Buscar actualizaciones…"), "Check for Updates…")
        XCTAssertEqual(en("Motores"), "Engines")
        XCTAssertEqual(en("Convertir"), "Convert")
    }

    func testFileNamesAreTranslated() {
        XCTAssertEqual(en("unido"), "merged")
        XCTAssertEqual(en("diapositivas"), "slides")
        XCTAssertEqual(String(format: en("Página %@.pdf"), "1"), "Page 1.pdf")
    }

    /// "1 archivo" / "3 archivos" in Spanish, "1 file" / "3 files" in English.
    func testFileCountsArePluralized() {
        let format = english.localizedString(forKey: "%lld archivos", value: nil, table: nil)
        XCTAssertEqual(String.localizedStringWithFormat(format, 1), "1 file")
        XCTAssertEqual(String.localizedStringWithFormat(format, 3), "3 files")
        XCTAssertEqual(String(localized: "\(1) archivos"), "1 archivo", "tests run in Spanish")
        XCTAssertEqual(String(localized: "\(3) archivos"), "3 archivos")
    }

    func testEveryStringHasAnEnglishTranslation() throws {
        let catalog = try XCTUnwrap(Bundle.main.url(forResource: "en", withExtension: "lproj"))
        let files = try FileManager.default.contentsOfDirectory(atPath: catalog.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("Localizable") }, "compiled English strings are in the app")
    }
}
