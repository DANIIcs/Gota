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
}
