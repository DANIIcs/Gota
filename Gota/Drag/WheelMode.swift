import AppKit

/// What the wheel offers. Picked by the modifier key held while dragging.
enum WheelMode: String, CaseIterable, Sendable {
    case convert
    case tools
    case actions

    var title: String {
        switch self {
        case .convert: String(localized: "Convertir")
        case .tools: String(localized: "Herramientas")
        case .actions: String(localized: "Acciones")
        }
    }

    /// The key that opens this mode, as macOS writes it in menus.
    var key: String {
        switch self {
        case .convert: "⇧"
        case .tools: "⌥"
        case .actions: "⌃"
        }
    }

    var keyName: String {
        switch self {
        case .convert: "Shift"
        case .tools: "Option"
        case .actions: "Control"
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
