import XCTest
@testable import Gota

final class WheelLayoutTests: XCTestCase {
    private let center = CGPoint(x: WheelLayout.panelSize / 2, y: WheelLayout.panelSize / 2)

    func testPointingAtEachBubbleSelectsIt() {
        for count in 1...WheelLayout.maxItems {
            for index in 0..<count {
                let offset = WheelLayout.offset(for: index, count: count)
                let point = CGPoint(x: center.x + offset.width, y: center.y + offset.height)
                XCTAssertEqual(WheelLayout.index(at: point, center: center, count: count), index, "count \(count), index \(index)")
            }
        }
    }

    func testFirstBubbleIsAtTheTop() {
        let offset = WheelLayout.offset(for: 0, count: 4)
        XCTAssertEqual(offset.width, 0, accuracy: 0.001)
        XCTAssertLessThan(offset.height, 0) // SwiftUI: negative y is up
    }

    func testCenterSelectsNothing() {
        XCTAssertNil(WheelLayout.index(at: center, center: center, count: 6))
        let nearCenter = CGPoint(x: center.x + WheelLayout.deadZone - 1, y: center.y)
        XCTAssertNil(WheelLayout.index(at: nearCenter, center: center, count: 6))
    }

    func testOutsideTheWheelSelectsNothing() {
        let far = CGPoint(x: center.x + WheelLayout.panelSize, y: center.y)
        XCTAssertNil(WheelLayout.index(at: far, center: center, count: 6))
    }

    func testNoItemsSelectsNothing() {
        XCTAssertNil(WheelLayout.index(at: CGPoint(x: center.x, y: 10), center: center, count: 0))
    }
}
