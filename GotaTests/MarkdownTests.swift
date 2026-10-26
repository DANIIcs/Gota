import AppKit
import PDFKit
import XCTest
@testable import Gota

final class MarkdownTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func markdown(_ text: String, name: String = "notas.md") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testStructureBecomesHTML() throws {
        let html = try MarkdownConverter.html(from: try markdown("""
        # Título

        Texto **fuerte** y *suave*.

        - uno
          - anidado

        | A | B |
        |---|---|
        | 1 | 2 |
        """))
        for tag in ["<h1>Título</h1>", "<strong>fuerte</strong>", "<em>suave</em>", "<ul><li>", "<th>A", "<td>1"] {
            XCTAssertTrue(html.contains(tag), tag)
        }
        XCTAssertEqual(html.components(separatedBy: "<ul>").count - 1, 2, "the nested list is nested")
    }

    /// A shared .md must not inject markup, run scripts, fetch remote images (tracking pixels) or reach
    /// files outside its folder.
    func testUntrustedMarkdownIsNeutralized() throws {
        let html = try MarkdownConverter.html(from: try markdown("""
        <script>alert(1)</script> & "comillas"

        [peligro](javascript:alert(1)) [web](https://example.com)

        ![pixel](https://tracker.example/p.png) ![fuera](file:///etc/hosts) ![raíz](/etc/hosts) ![propia](foto.png)
        """))
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("javascript:"))
        XCTAssertTrue(html.contains("href=\"https://example.com\""))
        XCTAssertFalse(html.contains("tracker.example"))
        XCTAssertFalse(html.contains("/etc/hosts"))
        XCTAssertTrue(html.contains("<img src=\"foto.png\""))
    }

    @MainActor
    func testConvertsToPDFAndWord() throws {
        let input = try markdown("# Informe\n\nPrimera página.\n")
        let pdf = dir.appendingPathComponent("notas.pdf")
        try MarkdownConverter.toPDF(input, output: pdf)
        XCTAssertTrue(PDFDocument(url: pdf)?.string?.contains("Informe") == true)
        let word = try MarkdownConverter.toWord(input)
        XCTAssertTrue(try NSAttributedString(url: word, options: [:], documentAttributes: nil).string.contains("Primera página"))
    }

    func testCatalogOffersMarkdownConversions() {
        let one = Catalog.actions(for: [dir.appendingPathComponent("a.md")], mode: .convert).map(\.id)
        XCTAssertEqual(one, ["doc-pdf", "md-docx", "md-html"])
        let mixed = Catalog.actions(for: [dir.appendingPathComponent("a.md"), dir.appendingPathComponent("b.docx")], mode: .convert).map(\.id)
        XCTAssertEqual(mixed, ["doc-pdf", "doc-pdf-combined"], "a .md mixed with Word files: only what works for both")
        XCTAssertEqual(DocumentEngines.preferred(for: dir.appendingPathComponent("a.markdown"))?.name, MarkdownEngine().name)
    }
}
