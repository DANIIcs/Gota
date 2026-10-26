import Foundation
import UniformTypeIdentifiers

/// One bubble on the wheel: what it shows and what it does with the dropped files.
/// `perform` returns the files it created (empty for actions like AirDrop).
struct WheelAction: Identifiable, Sendable {
    let id: String
    let title: String
    let symbol: String
    /// The format it creates: the wheel shows macOS's own icon for it (as Finder does) instead of `symbol`.
    var output: UTType?
    /// Several files into one: the icon is drawn as a stack.
    var combined = false
    let perform: @Sendable ([URL]) async throws -> [URL]

    func producing(_ type: UTType, combined: Bool = false) -> WheelAction {
        var action = self
        action.output = type
        action.combined = combined
        return action
    }

    /// Runs `transform` on every file, one after another, and collects the outputs.
    static func eachFile(
        id: String,
        title: String,
        symbol: String,
        _ transform: @escaping @Sendable (URL) async throws -> URL
    ) -> WheelAction {
        WheelAction(id: id, title: title, symbol: symbol) { files in
            var outputs: [URL] = []
            for file in files {
                outputs.append(try await transform(file))
            }
            return outputs
        }
    }
}

enum ConversionError: LocalizedError {
    case unreadable(URL)
    case unsupported(String)
    case toolFailed(tool: String, output: String)
    case noEngine(String)

    /// Where the user can fix it: a missing engine links to its download page.
    var helpURL: URL? {
        if case .noEngine = self { return LibreOfficeEngine.downloadPage }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            String(localized: "No se pudo leer \(url.lastPathComponent).")
        case .unsupported(let what):
            String(localized: "Formato no soportado: \(what).")
        case .toolFailed(let tool, let output):
            String(localized: "\(tool) falló: \(String(output.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)))")
        case .noEngine(let message):
            message
        }
    }
}
