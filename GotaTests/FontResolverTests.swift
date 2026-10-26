import AppKit
import XCTest
@testable import Gota

final class FontResolverTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gota-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A minimal .docx whose text is set in `font`, with Aptos only in its theme.
    private func docx(font: String) async throws -> URL {
        let package = dir.appendingPathComponent("p-\(font)")
        let parts: [String: String] = [
            "[Content_Types].xml": #"<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>"#,
            "word/document.xml": #"<w:document xmlns:w="w"><w:body><w:p><w:r><w:rPr><w:rFonts w:ascii="\#(font)" w:hAnsi="\#(font)"/></w:rPr><w:t>Hola</w:t></w:r></w:p></w:body></w:document>"#,
            "word/styles.xml": #"<w:styles xmlns:w="w"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Times New Roman"/></w:rPr></w:rPrDefault></w:docDefaults></w:styles>"#,
            "word/theme/theme1.xml": #"<a:theme xmlns:a="a"><a:majorFont><a:latin typeface="Aptos Display"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/></a:minorFont></a:theme>"#,
        ]
        for (path, text) in parts {
            let url = package.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        let output = dir.appendingPathComponent("\(font).docx")
        try await Shell.run("/usr/bin/zip", ["-q", "-r", output.path, "."], currentDirectory: package)
        return output
    }

    /// The theme's fonts only count when something uses them: here every run names its font.
    func testFindsTheFontsTheTextUses() async throws {
        let document = try await docx(font: "Poppins")
        let fonts = try await FontResolver.fonts(usedBy: document)
        XCTAssertEqual(fonts, ["Poppins", "Times New Roman"])
    }

    func testInstalledAndBundledFontsAreAvailable() {
        XCTAssertTrue(FontResolver.isAvailable("Times New Roman"))
        XCTAssertTrue(FontResolver.isAvailable("Calibri"), "covered by the bundled Carlito")
        XCTAssertFalse(FontResolver.isAvailable("Fuente Que No Existe"))
    }

    /// A crafted font name must not become an arbitrary path or URL.
    func testFolderNamesAreSanitized() {
        XCTAssertEqual(GoogleFonts.folderName(for: "Open Sans"), "opensans")
        XCTAssertEqual(GoogleFonts.folderName(for: "Poppins"), "poppins")
        for evil in ["../../etc", "a/b", "Poppins?x=1", "Pöppins", "", String(repeating: "a", count: 65)] {
            XCTAssertNil(GoogleFonts.folderName(for: evil), evil)
        }
    }

    func testOnlyFontFilesFromTheRepositoryAreChosen() throws {
        func file(_ name: String, _ url: String, size: Int = 100_000) throws -> GoogleFonts.RemoteFile {
            let json = #"{"name":"\#(name)","size":\#(size),"download_url":"\#(url)"}"#
            return try JSONDecoder().decode(GoogleFonts.RemoteFile.self, from: Data(json.utf8))
        }
        let base = "https://raw.githubusercontent.com/google/fonts/main/ofl/poppins/"
        let chosen = GoogleFonts.choose([
            try file("Poppins-Regular.ttf", base + "Poppins-Regular.ttf"),
            try file("Poppins-Light.ttf", base + "Poppins-Light.ttf"),
            try file("OFL.txt", base + "OFL.txt"),
            try file("Evil.ttf", "https://evil.example/google/fonts/Evil.ttf"),
            try file("Huge.ttf", base + "Huge.ttf", size: 50_000_000),
            try file("Poppins[wght].ttf", base + "Poppins%5Bwght%5D.ttf"),
        ]).map(\.name)
        XCTAssertEqual(chosen, ["Poppins-Regular.ttf"], "only the needed static styles; other hosts, huge files and non-fonts refused")
    }

    func testRejectsFilesThatAreNotFonts() {
        XCTAssertFalse(GoogleFonts.isFont(Data("<html>not a font</html>".utf8)))
        XCTAssertFalse(GoogleFonts.isFont(Data([0, 1, 0, 0, 1, 2, 3])), "right magic, broken font")
        let real = try? Data(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("Fonts/Carlito-Regular.ttf"))
        XCTAssertTrue(real.map(GoogleFonts.isFont) ?? false)
    }

    /// Hits github.com: only with GOTA_NETWORK_TESTS=1.
    func testDownloadsAnOpenFontFamily() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GOTA_NETWORK_TESTS"] == "1", "network test")
        let poppins = try await GoogleFonts.download("Poppins", into: dir)
        XCTAssertTrue(poppins)
        XCTAssertTrue(GoogleFonts.isDownloaded("Poppins", in: dir))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("poppins").path).count, 4)
        let semibold = try await GoogleFonts.download("Poppins SemiBold", into: dir)
        XCTAssertTrue(semibold)
        XCTAssertTrue(GoogleFonts.isDownloaded("Poppins SemiBold", in: dir))
        let aptos = try await GoogleFonts.download("Aptos", into: dir)
        XCTAssertFalse(aptos, "Microsoft's fonts aren't on Google Fonts")
    }

    func testExtraWeightsAreRequestedFromTheBaseFamily() {
        XCTAssertEqual(GoogleFonts.request(for: "Poppins").family, "Poppins")
        XCTAssertEqual(GoogleFonts.request(for: "Poppins SemiBold").family, "Poppins")
        XCTAssertEqual(GoogleFonts.request(for: "Poppins SemiBold").styles, ["SemiBold", "SemiBoldItalic"])
        XCTAssertEqual(GoogleFonts.request(for: "Open Sans").styles, ["Regular", "Bold", "Italic", "BoldItalic"])
    }
}
