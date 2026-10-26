import AppKit
import PDFKit
import XCTest
@testable import Gota

/// The bundled .docx engine. Skipped when Gota was built without it (no Rust, see Engines/docxide).
final class DocxideTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(DocxideEngine().isAvailable, "docxide-pdf not bundled in this build")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    /// A Word document with a Calibri heading and a page break, written by macOS.
    private func makeDocx() throws -> URL {
        let text = NSMutableAttributedString(string: "Informe\n", attributes: [.font: NSFont(name: "Calibri", size: 28) ?? .boldSystemFont(ofSize: 28)])
        text.append(NSAttributedString(string: "Primera página\n\u{0C}Segunda página\n"))
        let data = try text.data(from: NSRange(location: 0, length: text.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
        let url = dir.appendingPathComponent("informe.docx")
        try data.write(to: url)
        return url
    }

    func testConvertsWordDocuments() async throws {
        let output = dir.appendingPathComponent("informe.pdf")
        try await DocxideEngine().convertToPDF(try makeDocx(), output: output)
        let pdf = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(pdf.pageCount, 2)
        XCTAssertTrue(pdf.string?.contains("Segunda página") == true)
    }

    func testIsTheFirstSilentEngineForDocx() {
        UserDefaults.standard.removeObject(forKey: Preferences.useMicrosoftOfficeKey)
        let docx = dir.appendingPathComponent("a.docx")
        XCTAssertEqual(DocumentEngines.preferred(for: docx)?.name, DocxideEngine().name)
        XCTAssertNotEqual(DocumentEngines.preferred(for: dir.appendingPathComponent("a.doc"))?.name, DocxideEngine().name)
    }

    /// A crafted .docx whose only picture is a link to a private file on the Mac (written by hand, as an
    /// attacker would: macOS's own DOCX writer drops images). It must not end up in the PDF.
    func testDoesNotEmbedLinkedFiles() async throws {
        let privada = dir.appendingPathComponent("privada.png")
        let picture = NSImage(size: NSSize(width: 40, height: 40), flipped: false) { rect in
            NSColor.blue.setFill()
            rect.fill()
            return true
        }
        try NSBitmapImageRep(data: picture.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: privada)

        let package = dir.appendingPathComponent("paquete")
        let files: [String: String] = [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/>\
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\
            </Types>
            """,
            "_rels/.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\
            </Relationships>
            """,
            "word/_rels/document.xml.rels": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" \
            Target="file://\(privada.path)" TargetMode="External"/>\
            </Relationships>
            """,
            "word/document.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" \
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" \
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" \
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
            xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>\
            <w:p><w:r><w:t>Hola</w:t></w:r></w:p>\
            <w:p><w:r><w:drawing><wp:inline><wp:extent cx="914400" cy="914400"/><wp:docPr id="1" name="foto"/>\
            <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic>\
            <pic:nvPicPr><pic:cNvPr id="1" name="foto"/><pic:cNvPicPr/></pic:nvPicPr>\
            <pic:blipFill><a:blip r:link="rId9"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>\
            <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="914400" cy="914400"/></a:xfrm><a:prstGeom prst="rect"/></pic:spPr>\
            </pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>\
            </w:body></w:document>
            """,
        ]
        for (path, contents) in files {
            let url = package.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        let crafted = dir.appendingPathComponent("enlace.docx")
        try await Shell.run("/usr/bin/zip", ["-q", "-r", crafted.path, "."], currentDirectory: package)

        let output = dir.appendingPathComponent("enlace.pdf")
        try await DocxideEngine().convertToPDF(crafted, output: output)
        let text = String(decoding: try Data(contentsOf: output), as: UTF8.self)
        XCTAssertTrue(PDFDocument(url: output)?.string?.contains("Hola") == true, "the document itself was converted")
        XCTAssertFalse(text.contains("/Subtype /Image") || text.contains("/Subtype/Image"), "the linked private picture was embedded")
    }
}
