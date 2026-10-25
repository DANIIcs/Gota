import AppKit
import PDFKit
import XCTest
@testable import Gota

/// Crafted input files must not pull the user's other files into the results, nor crash Gota.
final class SecurityTests: XCTestCase {
    private var dir: URL!
    private var page: URL! // the folder the "received" HTML lives in

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        page = dir.appendingPathComponent("descargas")
        try FileManager.default.createDirectory(at: page, withIntermediateDirectories: true)
        // A private picture outside the page's folder, and the page's own picture next to it.
        try png(color: .red).write(to: dir.appendingPathComponent("privada.png"))
        try png(color: .blue).write(to: page.appendingPathComponent("propia.png"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func png(color: NSColor) -> Data {
        let image = NSImage(size: NSSize(width: 40, height: 40), flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return rep.representation(using: .png, properties: [:])!
    }

    private func maliciousHTML() throws -> URL {
        let html = """
        <html><body><p>Hola</p>
        <img src="propia.png">
        <img src="../privada.png">
        <img src="file://\(dir.path)/privada.png">
        </body></html>
        """
        let url = page.appendingPathComponent("pagina.html")
        try html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func imageCount(inPDF url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        return text.components(separatedBy: "/Subtype /Image").count - 1
    }

    /// What macOS hands back for `<img src="../privada.png">` and `<img src="propia.png">`:
    /// attachments carrying each file's name and bytes. Only the page's own image may stay.
    func testHTMLKeepsOnlyImagesFromItsOwnFolder() throws {
        func attachment(_ url: URL) throws -> NSAttributedString {
            let wrapper = FileWrapper(regularFileWithContents: try Data(contentsOf: url))
            wrapper.preferredFilename = url.lastPathComponent
            return NSAttributedString(attachment: NSTextAttachment(fileWrapper: wrapper))
        }
        let text = NSMutableAttributedString(string: "Hola ")
        text.append(try attachment(page.appendingPathComponent("propia.png")))
        text.append(try attachment(dir.appendingPathComponent("privada.png")))

        let kept = DocumentRenderer.keepingOnlyImages(in: page, from: text)
        var names: [String] = []
        kept.enumerateAttribute(.attachment, in: NSRange(location: 0, length: kept.length)) { value, _, _ in
            if let name = (value as? NSTextAttachment)?.fileWrapper?.preferredFilename { names.append(name) }
        }
        XCTAssertEqual(names, ["propia.png"])
        XCTAssertTrue(kept.string.hasPrefix("Hola"))
    }

    /// Same name as a file in the folder but other bytes (the private picture renamed) is still dropped.
    func testSameNameDifferentContentIsDropped() throws {
        let wrapper = FileWrapper(regularFileWithContents: try Data(contentsOf: dir.appendingPathComponent("privada.png")))
        wrapper.preferredFilename = "propia.png"
        let text = NSAttributedString(attachment: NSTextAttachment(fileWrapper: wrapper))
        XCTAssertEqual(DocumentRenderer.keepingOnlyImages(in: page, from: text).length, 0)
    }

    func testLibreOfficeDoesNotEmbedLinkedFiles() async throws {
        let engine = LibreOfficeEngine()
        try XCTSkipUnless(engine.isAvailable, "LibreOffice not installed")
        let output = dir.appendingPathComponent("lo.pdf")
        try await engine.convertToPDF(try maliciousHTML(), output: output)
        XCTAssertEqual(try imageCount(inPDF: output), 0)
    }

    func testHugePDFPageIsCapped() throws {
        // A page 20 000 pt wide: at 2× it would be a 40 000 px, multi-GB image.
        let pdf = dir.appendingPathComponent("enorme.pdf")
        var box = CGRect(x: 0, y: 0, width: 20_000, height: 100)
        let context = try XCTUnwrap(CGContext(pdf as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()

        let folder = try PDFTools.pagesToImages(pdf, type: .png)
        let image = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: image)))
        XCTAssertLessThanOrEqual(rep.pixelsWide, Int(PDFTools.maxPagePixels))
    }
}
