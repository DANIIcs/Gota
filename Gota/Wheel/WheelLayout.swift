import CoreGraphics
import Foundation

/// Geometry of the wheel, kept pure so it can be unit tested.
///
/// Bubbles sit on a circle. Index 0 is at the top and indices go clockwise
/// (SwiftUI coordinates: y grows downwards).
enum WheelLayout {
    /// Side of the square panel that hosts the wheel.
    static let panelSize: CGFloat = 340
    /// Distance from the center to each bubble's center.
    static let radius: CGFloat = 112
    /// Diameter of each bubble.
    static let bubbleSize: CGFloat = 58
    /// Diameter of the central drop.
    static let centerSize: CGFloat = 92
    /// Pointer closer than this to the center selects nothing (lets you "cancel").
    static let deadZone: CGFloat = centerSize / 2 + 4
    /// Bubbles shown at most per mode, so slices stay easy to hit.
    static let maxItems = 8

    static func angle(for index: Int, count: Int) -> Double {
        Double(index) / Double(max(count, 1)) * 2 * .pi - .pi / 2
    }

    /// Offset of a bubble from the wheel's center.
    static func offset(for index: Int, count: Int, radius: CGFloat = radius) -> CGSize {
        let a = angle(for: index, count: count)
        return CGSize(width: cos(a) * radius, height: sin(a) * radius)
    }

    /// Which bubble a point (in the wheel's own coordinates) points at, or nil in the dead zone / outside.
    /// The whole slice around a bubble counts, so you don't have to land exactly on it.
    static func index(at point: CGPoint, center: CGPoint, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance >= Double(deadZone), distance <= Double(panelSize) / 2 else { return nil }

        var theta = atan2(dy, dx) + .pi / 2 // 0 at the top, clockwise
        if theta < 0 { theta += 2 * .pi }
        let slice = 2 * .pi / Double(count)
        return Int((theta / slice).rounded()) % count
    }
}
