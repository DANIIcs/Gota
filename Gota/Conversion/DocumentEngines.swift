import AppKit
import Foundation

/// Something that can turn a Word-like document (DOCX, DOC, ODT, RTF…) into a PDF.
///
/// Gota tries engines in order and uses the first one installed. Adding a new engine
/// (ONLYOFFICE, a Rust engine like Oxi once it exports PDF…) means adding one type here
/// and putting it in `DocumentEngines.all`. See docs/MOTORES.md.
protocol DocumentEngine: Sendable {
    var name: String { get }
    var isAvailable: Bool { get }
    func canConvert(_ input: URL) -> Bool
    func convertToPDF(_ input: URL, output: URL) async throws
}

extension DocumentEngine {
    func canConvert(_ input: URL) -> Bool { true }
}

enum DocumentEngines {
    /// Best fidelity first. The built-in engine is last and always there, so PDF never needs an install.
    static let all: [any DocumentEngine] = [
        MicrosoftWordEngine(),
        LibreOfficeEngine(),
        NativeDocumentEngine(),
    ]

    static func preferred(for input: URL) -> (any DocumentEngine)? {
        all.first { $0.isAvailable && $0.canConvert(input) }
    }

    static func toPDF(_ input: URL) async throws -> URL {
        guard let engine = preferred(for: input) else {
            throw ConversionError.noEngine("Para convertir este documento a PDF instala LibreOffice.")
        }
        let output = Output.file(for: input, extension: "pdf")
        try await engine.convertToPDF(input, output: output)
        return output
    }
}

/// Microsoft Word itself, driven by AppleScript: the exact layout, because it *is* Word.
/// Off unless the user turns it on in Settings: the first time macOS asks to let Gota control Word,
/// and Word (sandboxed) asks for access to the folder, which is too much friction for a default.
struct MicrosoftWordEngine: DocumentEngine {
    let name = "Microsoft Word"

    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Word") != nil
    }

    var isAvailable: Bool {
        Preferences.useMicrosoftWord && Self.isInstalled
    }

    func convertToPDF(_ input: URL, output: URL) async throws {
        // Paths travel as arguments (argv), never pasted into the script text.
        let script = """
        on run argv
            set inFile to POSIX file (item 1 of argv)
            set outPath to (POSIX file (item 2 of argv)) as text
            with timeout of 600 seconds
                tell application "Microsoft Word"
                    -- If the user already has this document open, leave it open (and its unsaved edits alone).
                    set wasOpen to false
                    repeat with d in documents
                        if (full name of d) is (inFile as text) then set wasOpen to true
                    end repeat
                    open inFile
                    set theDoc to active document
                    save as theDoc file name outPath file format format PDF
                    if not wasOpen then close theDoc saving no
                end tell
            end timeout
        end run
        """
        try await Shell.run("/usr/bin/osascript", ["-e", script, input.path, output.path], timeout: .seconds(660))
        guard FileManager.default.fileExists(atPath: output.path) else {
            throw ConversionError.toolFailed(tool: name, output: "Word no generó el PDF.")
        }
    }
}

/// LibreOffice in headless mode: free and good, but layouts can shift versus Word.
struct LibreOfficeEngine: DocumentEngine {
    let name = "LibreOffice"

    private var soffice: URL? {
        let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.libreoffice.script")
            ?? URL(fileURLWithPath: "/Applications/LibreOffice.app")
        let binary = app.appendingPathComponent("Contents/MacOS/soffice")
        return FileManager.default.isExecutableFile(atPath: binary.path) ? binary : nil
    }

    var isAvailable: Bool { soffice != nil }

    func convertToPDF(_ input: URL, output: URL) async throws {
        guard let soffice else { throw ConversionError.noEngine("LibreOffice no está instalado.") }
        try await Output.withTemporaryDirectory { scratch in
            // A private profile avoids clashing with a LibreOffice window the user has open.
            let profile = scratch.appendingPathComponent("profile").absoluteString
            try await Shell.run(soffice.path, [
                "-env:UserInstallation=\(profile)",
                "--headless", "--convert-to", "pdf",
                "--outdir", scratch.path,
                input.path,
            ])
            let produced = scratch.appendingPathComponent(input.deletingPathExtension().lastPathComponent + ".pdf")
            // soffice exits with 0 even when it could not convert, so check the result exists.
            guard FileManager.default.fileExists(atPath: produced.path) else {
                throw ConversionError.toolFailed(tool: name, output: "LibreOffice no generó el PDF.")
            }
            try FileManager.default.moveItem(at: produced, to: output)
        }
    }
}

/// macOS's own text system (see `DocumentRenderer`): always available, never asks for permissions.
/// Keeps fonts, styles, lists and tables; complex Word layouts (columns, floating images) may shift.
struct NativeDocumentEngine: DocumentEngine {
    let name = "macOS (integrado)"
    let isAvailable = true

    func canConvert(_ input: URL) -> Bool {
        DocumentRenderer.readableExtensions.contains(input.pathExtension.lowercased())
    }

    func convertToPDF(_ input: URL, output: URL) async throws {
        try await MainActor.run {
            try DocumentRenderer.pdf(from: input, to: output)
        }
    }
}
