import XCTest
@testable import Gota

/// Conversions must fail loudly when the tool produced nothing, not report a file that isn't there.
final class ToolOutputTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testRequireCreatedThrowsForMissingFile() {
        let input = dir.appendingPathComponent("informe.docx")
        XCTAssertThrowsError(try Output.requireCreated(dir.appendingPathComponent(".gota-tmp.pdf"), by: "test", from: input)) { error in
            XCTAssertTrue(error.localizedDescription.contains("informe.docx"), "the error names the user's file")
        }
    }

    /// textutil can't read .pages yet exits with 0: Gota used to call that a success.
    func testTextutilFailureIsReported() async throws {
        let pages = dir.appendingPathComponent("doc.pages")
        try FileManager.default.createDirectory(at: pages, withIntermediateDirectories: false)
        do {
            _ = try await FileActions.textutil(pages, to: "txt")
            XCTFail("textutil can't read this file, the conversion must throw")
        } catch {}
    }

    func testTextutilConvertsPlainText() async throws {
        let input = dir.appendingPathComponent("nota.txt")
        try "hola".write(to: input, atomically: true, encoding: .utf8)
        let output = try await FileActions.textutil(input, to: "html")
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    /// A missing engine points the user to LibreOffice's official page; other errors carry no link.
    func testMissingEngineLinksToLibreOffice() {
        XCTAssertEqual(ConversionError.noEngine("x").helpURL?.host(), "www.libreoffice.org")
        XCTAssertEqual(ConversionError.noEngine("x").helpURL?.scheme, "https")
        XCTAssertNil(ConversionError.unsupported("x").helpURL)
    }
}
