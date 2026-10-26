import AppKit
import PDFKit
import XCTest
@testable import Gota

final class DocumentTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A Word document with a page break, written by macOS itself.
    private func makeDocx() throws -> URL {
        let text = NSMutableAttributedString(string: "Hola Gota\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 28)])
        text.append(NSAttributedString(string: "\u{0C}Segunda página\n", attributes: [.font: NSFont.systemFont(ofSize: 14)]))
        let data = try text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        let url = dir.appendingPathComponent("carta.docx")
        try data.write(to: url)
        return url
    }

    @MainActor
    func testNativeEngineRendersEveryPage() throws {
        let output = dir.appendingPathComponent("carta.pdf")
        try DocumentRenderer.pdf(from: try makeDocx(), to: output)
        let pdf = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(pdf.pageCount, 2)
        XCTAssertTrue(pdf.page(at: 0)?.string?.contains("Hola Gota") == true)
        XCTAssertTrue(pdf.page(at: 1)?.string?.contains("Segunda página") == true)
        if let keep = ProcessInfo.processInfo.environment["GOTA_KEEP_PDF"] {
            try? FileManager.default.copyItem(at: output, to: URL(fileURLWithPath: keep))
        }
    }

    func testNativeEngineIsTheFallbackButNotForPages() {
        let native = NativeDocumentEngine()
        XCTAssertTrue(native.canConvert(dir.appendingPathComponent("a.DOCX")))
        XCTAssertFalse(native.canConvert(dir.appendingPathComponent("a.pages")))
    }

    func testPDFToWordKeepsTextAndPages() throws {
        let pdf = dir.appendingPathComponent("carta.pdf")
        try DocumentRenderer.write(
            NSAttributedString(string: "Uno\u{0C}Dos"),
            paper: DocumentRenderer.defaultPaper,
            margins: NSEdgeInsets(top: 72, left: 72, bottom: 72, right: 72),
            to: pdf
        )
        let docx = try PDFTools.toWord([pdf])
        XCTAssertEqual(docx.pathExtension, "docx")
        let back = try NSAttributedString(url: docx, options: [:], documentAttributes: nil).string
        XCTAssertTrue(back.contains("Uno"))
        XCTAssertTrue(back.contains("Dos"))
        XCTAssertTrue(back.contains("\u{0C}"), "each PDF page should start a new Word page")
    }

    func testPDFOffersWord() {
        let ids = Catalog.actions(for: [dir.appendingPathComponent("a.pdf")], mode: .convert).map(\.id)
        XCTAssertEqual(ids.first, "pdf-docx")
    }

    func testWordIsOffByDefault() {
        UserDefaults.standard.removeObject(forKey: Preferences.useMicrosoftOfficeKey)
        XCTAssertFalse(MicrosoftWordEngine().isAvailable)
    }
}
