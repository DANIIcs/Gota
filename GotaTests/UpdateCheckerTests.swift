import XCTest
@testable import Gota

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(UpdateChecker.isNewer("0.2.0", than: "0.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("0.10.0", than: "0.9.1"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0", than: "0.99.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.2.0", than: "0.2.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.2", than: "0.2.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.9", than: "0.2.0"))
    }

    func testParsesGitHubsLatestRelease() throws {
        let json = #"{"tag_name":"v0.3.0","html_url":"https://github.com/DANIIcs/Gota/releases/tag/v0.3.0","body":"…"}"#
        let release = try UpdateChecker.parse(Data(json.utf8))
        XCTAssertEqual(release.version, "0.3.0")
        XCTAssertEqual(release.page.absoluteString, "https://github.com/DANIIcs/Gota/releases/tag/v0.3.0")
    }

    /// A tampered answer must not be able to send the user to another site.
    func testRejectsLinksOutsideTheRepository() {
        for link in ["https://evil.example/DANIIcs/Gota/releases/tag/v9", "http://github.com/DANIIcs/Gota/releases/tag/v9",
                     "https://github.com/someone/else/releases/tag/v9"] {
            let json = #"{"tag_name":"v9.0.0","html_url":"\#(link)"}"#
            XCTAssertThrowsError(try UpdateChecker.parse(Data(json.utf8)), link)
        }
    }
}
