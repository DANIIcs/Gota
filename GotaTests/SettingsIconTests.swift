import AppKit
import XCTest
@testable import Gota

final class SettingsIconTests: XCTestCase {
    /// The About pane showed macOS's empty placeholder: the icon must come from Gota's asset catalog.
    func testAppIconLoadsFromTheAssetCatalog() {
        XCTAssertNotNil(NSImage(named: "AppIcon"))
    }

    /// The panes borrow System Settings' own icons; where a Mac doesn't have them (CI runners, or a
    /// future macOS) the drawn fallback is used, so this only checks Macs that do have them.
    func testSystemSettingsIconsExistOnThisMac() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/System/Library/ExtensionKit/Extensions/GeneralSettings.appex"),
                          "this Mac has no System Settings pane bundles: Gota draws its own icons")
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

    /// Re-registering with Launch Services refreshes the icon after an update: once per build, not at every launch.
    func testRefreshesRegistrationOncePerBuild() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "gota-tests-\(UUID().uuidString)"))
        var registered: [URL] = []
        XCTAssertTrue(AppIcon.refreshRegistrationIfUpdated(defaults: defaults) { registered.append($0) })
        XCTAssertFalse(AppIcon.refreshRegistrationIfUpdated(defaults: defaults) { registered.append($0) })
        XCTAssertEqual(registered, [Bundle.main.bundleURL])
        defaults.set("an older build", forKey: AppIcon.registeredBuildKey)
        XCTAssertTrue(AppIcon.refreshRegistrationIfUpdated(defaults: defaults) { registered.append($0) })
    }
}
