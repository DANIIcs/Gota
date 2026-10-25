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
