import AppKit
import Foundation

/// Actions that don't convert: share, compress into a ZIP, copy paths…
enum FileActions {
    @MainActor
    static func airDrop(_ files: [URL]) {
        NSApp.activate()
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: files)
    }

    @MainActor
    static func copyPaths(_ files: [URL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(files.map(\.path).joined(separator: "\n"), forType: .string)
    }

    @MainActor
    static func revealInFinder(_ files: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(files)
    }

    /// One ZIP for everything that was dragged, made with Apple's `ditto` (keeps macOS metadata right).
    static func zip(_ files: [URL]) async throws -> URL {
        guard let first = files.first else { throw ConversionError.unsupported("sin archivos") }
        if files.count == 1 {
            let output = Output.file(for: first, extension: "zip")
            try await Shell.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", first.path, output.path])
            return output
        }
        // Several items: gather them (APFS clones, instant and free) in a folder named "Archivo", then zip it.
        return try await Output.withTemporaryDirectory { scratch in
            let staging = scratch.appendingPathComponent("Archivo")
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
            for file in files {
                try FileManager.default.copyItem(at: file, to: staging.appendingPathComponent(file.lastPathComponent))
            }
            let output = Output.unique(first.deletingLastPathComponent(), base: "Archivo", extension: "zip")
            try await Shell.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", staging.path, output.path])
            return output
        }
    }

    /// Plain conversions between text formats with Apple's `textutil` (txt, rtf, html, docx, odt…).
    static func textutil(_ input: URL, to format: String) async throws -> URL {
        let output = Output.file(for: input, extension: format)
        try await Shell.run("/usr/bin/textutil", ["-convert", format, "-output", output.path, input.path])
        return output
    }
}
