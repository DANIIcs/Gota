import SwiftUI

/// What the bubbles are made of. Chosen in Settings, read by `WheelView` through `@AppStorage`.
enum WheelMaterial: String, CaseIterable, Identifiable {
    case glass
    case clear
    case opaque

    static let key = "wheelMaterial"

    var id: Self { self }

    var title: String {
        switch self {
        case .glass: "Liquid Glass"
        case .clear: "Transparente"
        case .opaque: "Opaco"
        }
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
        case .automatic: "Automático (color de acento)"
        case .blue: "Azul"
        case .purple: "Morado"
        case .pink: "Rosa"
        case .red: "Rojo"
        case .orange: "Naranja"
        case .yellow: "Amarillo"
        case .green: "Verde"
        case .graphite: "Grafito"
        case .spaceBlack: "Negro espacial"
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

    /// How strongly bubbles that aren't hovered are tinted: "automatic" keeps the plain system glass.
    var restingTint: Double {
        switch self {
        case .automatic: 0
        case .spaceBlack: 0.65
        default: 0.3
        }
    }

    /// Dark bubbles need light icons even when not hovered.
    var isDark: Bool { self == .spaceBlack }
}
