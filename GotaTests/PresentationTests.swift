import AppKit
import PDFKit
import XCTest
@testable import Gota

final class PresentationTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testPresentationsAreRecognized() {
        for name in ["a.pptx", "a.PPT", "a.key", "a.odp", "a.ppsx"] {
            XCTAssertEqual(FileKind.of(dir.appendingPathComponent(name)), .presentation, name)
        }
    }

    func testPresentationsOfferPDFAndImages() {
        let one = Catalog.actions(for: [dir.appendingPathComponent("a.pptx")], mode: .convert).map(\.id)
        XCTAssertEqual(one, ["slides-pdf", "slides-png", "slides-jpeg"])
        let two = Catalog.actions(for: [dir.appendingPathComponent("a.pptx"), dir.appendingPathComponent("b.key")], mode: .convert)
        XCTAssertTrue(two.map(\.id).contains("slides-pdf-combined"))
    }

    func testOnlyPresentationEnginesTakeSlides() {
        let slides = dir.appendingPathComponent("a.pptx")
        XCTAssertTrue(MicrosoftPowerPointEngine().canConvert(slides))
        XCTAssertFalse(MicrosoftPowerPointEngine().canConvert(dir.appendingPathComponent("a.key")))
        XCTAssertFalse(MicrosoftPowerPointEngine().canConvert(dir.appendingPathComponent("a.docx")))
        XCTAssertFalse(MicrosoftWordEngine().canConvert(slides))
        XCTAssertFalse(NativeDocumentEngine().canConvert(slides))
        XCTAssertTrue(KeynoteEngine().canConvert(slides))
        XCTAssertFalse(KeynoteEngine().canConvert(dir.appendingPathComponent("a.docx")))
    }

    /// Without Office, the measured order is LibreOffice before Keynote, and Office stays off by default.
    func testEngineOrderFollowsTheFidelityMeasurements() {
        UserDefaults.standard.removeObject(forKey: Preferences.useMicrosoftOfficeKey)
        XCTAssertFalse(MicrosoftPowerPointEngine().isAvailable)
        let names = DocumentEngines.all.map(\.name)
        let libreOffice = try? XCTUnwrap(names.firstIndex(of: "LibreOffice"))
        let keynote = try? XCTUnwrap(names.firstIndex(of: "Keynote"))
        XCTAssertLessThan(libreOffice ?? .max, keynote ?? .min)
    }

    /// A real 2-slide .pptx, made by LibreOffice from a PDF, converted back by Gota.
    func testPowerPointToPDFAndSlideImages() async throws {
        let soffice = URL(fileURLWithPath: "/Applications/LibreOffice.app/Contents/MacOS/soffice")
        try XCTSkipUnless(LibreOfficeEngine().isAvailable && FileManager.default.isExecutableFile(atPath: soffice.path),
                          "LibreOffice not installed")
        let pptx = try await makePresentation(with: soffice)

        UserDefaults.standard.removeObject(forKey: Preferences.useMicrosoftOfficeKey)
        let pdf = try await DocumentEngines.toPDF(pptx)
        XCTAssertEqual(PDFDocument(url: pdf)?.pageCount, 2)

        let folder = try await DocumentEngines.toImages(pptx, type: .png)
        XCTAssertEqual(folder.lastPathComponent, "charla diapositivas")
        let slides = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(slides, ["Diapositiva 1.png", "Diapositiva 2.png"])
    }

    private func makePresentation(with soffice: URL) async throws -> URL {
        let source = dir.appendingPathComponent("charla.pdf")
        var box = CGRect(x: 0, y: 0, width: 960, height: 540)
        let context = try XCTUnwrap(CGContext(source as CFURL, mediaBox: &box, nil))
        for _ in 0..<2 {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.systemBlue.cgColor)
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()
        try await Output.withTemporaryDirectory { profile in
            try await Shell.run(soffice.path, [
                "-env:UserInstallation=\(profile.absoluteString)",
                "--headless", "--infilter=impress_pdf_import", "--convert-to", "pptx",
                "--outdir", dir.path, source.path,
            ])
        }
        try FileManager.default.removeItem(at: source) // so the PDF Gota makes is "charla.pdf" again
        let pptx = dir.appendingPathComponent("charla.pptx")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pptx.path))
        return pptx
    }
}
