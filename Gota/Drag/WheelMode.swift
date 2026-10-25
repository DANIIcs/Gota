import AppKit

/// What the wheel offers. Picked by the modifier key held while dragging.
enum WheelMode: String, CaseIterable, Sendable {
    case convert
    case tools
    case actions

    var title: String {
        switch self {
        case .convert: "Convertir"
        case .tools: "Herramientas"
        case .actions: "Acciones"
        }
    }

    var symbol: String {
        switch self {
        case .convert: "arrow.triangle.2.circlepath"
        case .tools: "wand.and.stars"
        case .actions: "square.and.arrow.up"
        }
    }

    /// ⇧ → convert, ⌥ → tools, ⌃ → actions. ⌘ is left alone: Finder uses it to move files.
    static func from(_ flags: NSEvent.ModifierFlags) -> WheelMode? {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.shift) { return .convert }
        if flags.contains(.option) { return .tools }
        if flags.contains(.control) { return .actions }
        return nil
    }
}
