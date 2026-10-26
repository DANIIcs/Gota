import PDFKit
import XCTest
@testable import Gota

final class CatalogTests: XCTestCase {
    private func file(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/gota-tests/\(name)")
    }

    func testFileKinds() {
        XCTAssertEqual(FileKind.of(file("a.png")), .image)
        XCTAssertEqual(FileKind.of(file("a.HEIC")), .image)
        XCTAssertEqual(FileKind.of(file("a.pdf")), .pdf)
        XCTAssertEqual(FileKind.of(file("a.mov")), .video)
        XCTAssertEqual(FileKind.of(file("a.mp3")), .audio)
        XCTAssertEqual(FileKind.of(file("a.docx")), .document)
        XCTAssertEqual(FileKind.of(file("a.unknownext")), .other)
    }

    func testMixedFilesAreOther() {
        XCTAssertEqual(FileKind.common([file("a.png"), file("b.pdf")]), .other)
        XCTAssertEqual(FileKind.common([file("a.png"), file("b.jpg")]), .image)
    }

    func testImageConvertDoesNotOfferTheSameFormat() {
        let ids = Catalog.actions(for: [file("a.png")], mode: .convert).map(\.id)
        XCTAssertFalse(ids.contains("image-PNG"))
        XCTAssertTrue(ids.contains("image-JPEG"))
    }

    func testMediaAndDocumentsDoNotOfferTheSameFormat() {
        let video = Catalog.actions(for: [file("a.MP4")], mode: .convert).map(\.id)
        XCTAssertFalse(video.contains("video-mp4"))
        XCTAssertTrue(video.contains("video-mov"))

        let audio = Catalog.actions(for: [file("a.wav")], mode: .convert).map(\.id)
        XCTAssertEqual(audio, ["audio-m4a", "audio-aiff"])

        let doc = Catalog.actions(for: [file("a.htm")], mode: .convert).map(\.id)
        XCTAssertFalse(doc.contains("doc-html"))
        XCTAssertTrue(doc.contains("doc-docx"))
    }

    func testMixedFormatsStillOfferEveryTarget() {
        let ids = Catalog.actions(for: [file("a.wav"), file("b.mp3")], mode: .convert).map(\.id)
        XCTAssertTrue(ids.contains("audio-wav"))
    }

    func testPagesOnlyOffersPDF() {
        XCTAssertEqual(Catalog.actions(for: [file("a.pages")], mode: .convert).map(\.id), ["doc-pdf"])
    }

    func testMergeOnlyWithSeveralPDFs() {
        let one = Catalog.actions(for: [file("a.pdf")], mode: .tools).map(\.id)
        let two = Catalog.actions(for: [file("a.pdf"), file("b.pdf")], mode: .tools).map(\.id)
        XCTAssertFalse(one.contains("pdf-merge"))
        XCTAssertTrue(two.contains("pdf-merge"))
    }

    func testActionsWorkForAnyFile() {
        XCTAssertFalse(Catalog.actions(for: [file("a.unknownext")], mode: .actions).isEmpty)
    }

    func testNeverMoreThanTheWheelHolds() {
        for mode in WheelMode.allCases {
            XCTAssertLessThanOrEqual(Catalog.actions(for: [file("a.png")], mode: mode).count, WheelLayout.maxItems)
        }
    }

    func testOutputNeverOverwrites() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let input = dir.appendingPathComponent("foto.heic")
        let first = Output.file(for: input, extension: "png")
        XCTAssertEqual(first.lastPathComponent, "foto.png")
        FileManager.default.createFile(atPath: first.path, contents: Data())
        XCTAssertEqual(Output.file(for: input, extension: "png").lastPathComponent, "foto 2.png")
    }
}

final class MultipleFilesTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func ids(_ names: [String], _ mode: WheelMode) -> [String] {
        Catalog.actions(for: names.map { dir.appendingPathComponent($0) }, mode: mode).map(\.id)
    }

    func testOneFileHasNoCombinedOption() {
        XCTAssertFalse(ids(["a.pdf"], .convert).contains { $0.hasSuffix("-combined") })
        XCTAssertFalse(ids(["a.pdf"], .actions).contains("action-zip-each"))
    }

    func testSeveralFilesOfferEachAndCombined() {
        let pdfs = ids(["a.pdf", "b.pdf"], .convert)
        XCTAssertTrue(pdfs.contains("pdf-docx") && pdfs.contains("pdf-docx-combined"))
        XCTAssertTrue(pdfs.contains("pdf-text") && pdfs.contains("pdf-text-combined"))
        let images = ids(["a.png", "b.jpg"], .convert)
        XCTAssertTrue(images.contains("image-pdf") && images.contains("image-pdf-combined"))
        let docs = ids(["a.docx", "b.rtf"], .convert)
        XCTAssertTrue(docs.contains("doc-pdf") && docs.contains("doc-pdf-combined"))
        XCTAssertTrue(ids(["a.png", "b.pdf"], .actions).contains("action-zip-each"))
    }

    func testCombinedTextKeepsTheDragOrder() throws {
        func pdf(_ name: String, _ text: String) throws -> URL {
            let url = dir.appendingPathComponent(name)
            try DocumentRenderer.write(NSAttributedString(string: text), paper: DocumentRenderer.defaultPaper,
                                       margins: NSEdgeInsets(top: 72, left: 72, bottom: 72, right: 72), to: url)
            return url
        }
        let output = try PDFTools.text([try pdf("b.pdf", "Segundo"), try pdf("a.pdf", "Primero")])
        XCTAssertEqual(output.lastPathComponent, "b unido.txt")
        let text = try String(contentsOf: output, encoding: .utf8)
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "Segundo")).lowerBound, try XCTUnwrap(text.range(of: "Primero")).lowerBound)
    }

    func testDocumentsIntoOnePDF() async throws {
        let a = dir.appendingPathComponent("a.txt"), b = dir.appendingPathComponent("b.txt")
        try "Uno".write(to: a, atomically: true, encoding: .utf8)
        try "Dos".write(to: b, atomically: true, encoding: .utf8)
        UserDefaults.standard.removeObject(forKey: Preferences.useMicrosoftOfficeKey)
        let output = try await DocumentEngines.toSinglePDF([a, b])
        XCTAssertEqual(output.lastPathComponent, "a unido.pdf")
        XCTAssertEqual(output.deletingLastPathComponent().standardizedFileURL, dir.standardizedFileURL)
        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 2)
    }
}
