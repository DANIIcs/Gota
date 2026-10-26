import AppKit
import XCTest
@testable import Gota

final class SettingsIconTests: XCTestCase {
    /// The About pane showed macOS's empty placeholder: the icon must come from Gota's asset catalog.
    func testAppIconLoadsFromTheAssetCatalog() {
        XCTAssertNotNil(NSImage(named: "AppIcon"))
    }

    /// The panes borrow System Settings' own icons; if one disappears in a future macOS, the drawn
    /// fallback is used, so this only documents which ones exist today.
    func testSystemSettingsIconsExistOnThisMac() {
        for name in ["GeneralSettings", "Appearance", "KeyboardSettings", "LoginItems"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: "/System/Library/ExtensionKit/Extensions/\(name).appex"), name)
        }
    }

    /// The About icon must be a real, already-drawn bitmap of the requested size, not a lazy icon
    /// SwiftUI would show as the placeholder grid.
    @MainActor
    func testAboutIconIsDrawnAtItsSize() throws {
        let image = AppIcon.image(points: 96)
        let rep = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        XCTAssertEqual(rep.pixelsWide, 192)
        XCTAssertEqual(image.size, NSSize(width: 96, height: 96))
        // Not blank: the drop's pixels are drawn.
        let center = try XCTUnwrap(rep.colorAt(x: 96, y: 96))
        XCTAssertGreaterThan(center.alphaComponent, 0.5)
    }
}
