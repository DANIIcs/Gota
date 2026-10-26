import SwiftUI

/// The kind of glass the bubbles are made of. Chosen in Settings, read by `WheelView` through `@AppStorage`.
/// How solid they look is a separate slider (`opacityKey`): 0 is pure glass, 1 fully opaque.
enum WheelMaterial: String, CaseIterable, Identifiable {
    case glass
    case clear

    static let key = "wheelMaterial"
    static let opacityKey = "wheelOpacity"

    var id: Self { self }

    var title: String {
        switch self {
        case .glass: "Liquid Glass"
        case .clear: String(localized: "Transparente")
        }
    }

    var glass: Glass {
        self == .clear ? .clear : .regular
    }
}

/// The wheel's color, like the accent colors in System Settings, plus a black and a rainbow.
enum WheelColor: String, CaseIterable, Identifiable {
    case automatic
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case graphite
    case spaceBlack
    case rgb

    static let key = "wheelColor"
    /// Seconds for the RGB wheel to go once around the rainbow.
    static let rgbCycle = 4.0

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Automático (color de acento)")
        case .blue: String(localized: "Azul")
        case .purple: String(localized: "Morado")
        case .pink: String(localized: "Rosa")
        case .red: String(localized: "Rojo")
        case .orange: String(localized: "Naranja")
        case .yellow: String(localized: "Amarillo")
        case .green: String(localized: "Verde")
        case .graphite: String(localized: "Grafito")
        case .spaceBlack: String(localized: "Negro espacial")
        case .rgb: "RGB"
        }
    }

    /// The color for one bubble. `phase` (0…1) only matters for RGB: each bubble gets its own hue,
    /// so the wheel is a rainbow, and `date` spins it.
    func color(phase: Double = 0, at date: Date = .now) -> Color {
        switch self {
        case .automatic: .accentColor
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .graphite: .gray
        case .spaceBlack: Color(red: 0.1, green: 0.1, blue: 0.12)
        case .rgb:
            Color(hue: (date.timeIntervalSinceReferenceDate / Self.rgbCycle + phase).truncatingRemainder(dividingBy: 1),
                  saturation: 0.8, brightness: 1)
        }
    }

    /// What a bubble is painted with: the color, except space black, which is brushed metal
    /// (lighter graphite where light hits the top-left, near black at the bottom-right).
    func fill(phase: Double = 0, at date: Date = .now) -> AnyShapeStyle {
        guard self == .spaceBlack else { return AnyShapeStyle(color(phase: phase, at: date)) }
        return AnyShapeStyle(LinearGradient(
            stops: [
                .init(color: Color(white: 0.36), location: 0),
                .init(color: Color(white: 0.17), location: 0.45),
                .init(color: Color(white: 0.07), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }

    /// Metal catches light on its edge: a thin highlight around space black bubbles.
    var hasMetalRim: Bool { self == .spaceBlack }

    /// How strongly bubbles that aren't hovered are tinted: "automatic" keeps the plain system glass.
    var restingTint: Double {
        switch self {
        case .automatic: 0
        case .spaceBlack: 0.8
        default: 0.3
        }
    }

    /// The hovered bubble: clearly colored, but still a little see-through.
    static let hoveredTint = 0.85

    /// Dark bubbles need light icons even when not hovered.
    var isDark: Bool { self == .spaceBlack }
}
