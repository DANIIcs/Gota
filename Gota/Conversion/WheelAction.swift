import Foundation

/// One bubble on the wheel: what it shows and what it does with the dropped files.
/// `perform` returns the files it created (empty for actions like AirDrop).
struct WheelAction: Identifiable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let perform: @Sendable ([URL]) async throws -> [URL]

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

    var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            "No se pudo leer \(url.lastPathComponent)."
        case .unsupported(let what):
            "Formato no soportado: \(what)."
        case .toolFailed(let tool, let output):
            "\(tool) falló: \(output.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))"
        case .noEngine(let message):
            message
        }
    }
}
