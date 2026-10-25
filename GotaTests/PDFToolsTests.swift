import AppKit
import PDFKit
import XCTest
@testable import Gota

final class PDFToolsTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A 200×100 page with no text layer, like a scan.
    private func makePDF(rotation: Int = 0) throws -> URL {
        let image = NSImage(size: NSSize(width: 200, height: 100), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let page = try XCTUnwrap(PDFPage(image: image))
        page.rotation = rotation
        let document = PDFDocument()
        document.insert(page, at: 0)
        let url = dir.appendingPathComponent("doc.pdf")
        XCTAssertTrue(document.write(to: url))
        return url
    }

    func testRotatedPagesKeepTheirResolution() throws {
        let folder = try PDFTools.pagesToImages(try makePDF(rotation: 90), type: .png, scale: 2)
        let page = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: page)))
        XCTAssertEqual(rep.pixelsWide, 200)
        XCTAssertEqual(rep.pixelsHigh, 400)
    }

    func testPDFWithoutTextFailsInsteadOfWritingAnEmptyFile() throws {
        XCTAssertThrowsError(try PDFTools.text(try makePDF()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("doc.txt").path))
    }
}
