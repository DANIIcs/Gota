import AppKit
import Foundation
import UniformTypeIdentifiers

/// Something that can turn a Word-like document (DOCX, DOC, ODT, RTF…) into a PDF.
///
/// Each input format has its own ranking of engines (`DocumentEngines.ranking`), from measured
/// fidelity. Adding an engine (Oxi or BetterOffice once they export PDF…) means adding
/// one type here and placing it in the rankings where its measurements put it. See docs/MOTORES.md.
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
    static let word = MicrosoftWordEngine()
    static let powerPoint = MicrosoftPowerPointEngine()
    static let docxide = DocxideEngine()
    static let libreOffice = LibreOfficeEngine()
    static let keynote = KeynoteEngine()
    static let pages = PagesEngine()
    static let native = NativeDocumentEngine()

    static let all: [any DocumentEngine] = [word, powerPoint, docxide, libreOffice, keynote, pages, native]

    /// The engines for a format, best first, from measurements against Word's and PowerPoint's own PDFs
    /// (docs/MOTORES.md). Three tiers:
    /// 1. Microsoft Office: exact, but opens its apps and asks for folders, so only when turned on.
    /// 2. Engines that convert silently, by measured fidelity: docxide for .docx (bundled with Gota),
    ///    LibreOffice for the other Office formats, macOS's own engine for plain text (it scored
    ///    higher and needs no LibreOffice launch).
    /// 3. Keynote and Pages, which open their app: only when nothing silent can read the file.
    static func ranking(forExtension ext: String) -> [any DocumentEngine] {
        switch ext.lowercased() {
        case "docx": [word, docxide, libreOffice, native]
        case "doc", "odt", "rtf", "html", "htm": [word, libreOffice, native]
        case "txt": [word, native, libreOffice]
        case "rtfd": [native]
        case "pages": [libreOffice, pages]
        case "pptx", "ppt", "ppsx", "pps", "odp": [powerPoint, libreOffice, keynote]
        case "key": [libreOffice, keynote]
        default: []
        }
    }

    static func preferred(for input: URL) -> (any DocumentEngine)? {
        ranking(forExtension: input.pathExtension).first { $0.isAvailable && $0.canConvert(input) }
    }

    static func toPDF(_ input: URL) async throws -> URL {
        let output = Output.file(for: input, extension: "pdf")
        try await convert(input, to: output)
        return output
    }

    /// Every document to PDF, then all of them in one PDF, in the order they were dragged.
    static func toSinglePDF(_ inputs: [URL]) async throws -> URL {
        guard let first = inputs.first else { throw ConversionError.unsupported("sin archivos") }
        return try await Output.withTemporaryDirectory { scratch in
            var parts: [URL] = []
            for (index, input) in inputs.enumerated() {
                let part = scratch.appendingPathComponent("\(index).pdf")
                try await convert(input, to: part)
                parts.append(part)
            }
            return try PDFTools.merge(parts, namedAfter: first)
        }
    }

    /// Every slide (or page) as an image, in a new folder next to the presentation.
    static func toImages(_ input: URL, type: UTType) async throws -> URL {
        try await Output.withTemporaryDirectory { scratch in
            let pdf = scratch.appendingPathComponent("slides.pdf")
            try await convert(input, to: pdf)
            return try PDFTools.pagesToImages(pdf, type: type, namedAfter: input, suffix: "diapositivas", itemName: "Diapositiva")
        }
    }

    private static func convert(_ input: URL, to output: URL) async throws {
        guard let engine = preferred(for: input) else {
            let isPresentation = FileKind.of(input) == .presentation
            throw ConversionError.noEngine(isPresentation
                ? "Para convertir presentaciones instala LibreOffice (gratis) o Keynote. Pulsa aquí para descargarlo."
                : "Para convertir este documento a PDF instala LibreOffice (gratis). Pulsa aquí para descargarlo.")
        }
        try await engine.convertToPDF(input, output: output)
    }
}

/// Microsoft Word itself, driven by AppleScript: the exact layout, because it *is* Word.
/// Off unless the user turns Microsoft Office on in Settings: the first time macOS asks to let Gota control
/// Word, and Word (sandboxed) asks for access to the folder, which is too much friction for a default.
struct MicrosoftWordEngine: DocumentEngine {
    let name = "Microsoft Word"

    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Word") != nil
    }

    var isAvailable: Bool {
        Preferences.useMicrosoftOffice && Self.isInstalled
    }

    /// Only what Word opens: it must never be handed a presentation.
    func canConvert(_ input: URL) -> Bool {
        ["docx", "doc", "rtf", "odt", "txt", "html", "htm"].contains(input.pathExtension.lowercased())
    }

    func convertToPDF(_ input: URL, output: URL) async throws {
        // Word's dictionary can't iterate `documents` directly ("doesn't understand count"), so documents
        // are looked up by index. The converted one is found by its path, never as "the active document":
        // if Word failed to open the file, that would be another document the user has open, which
        // would then be closed without saving.
        let script = """
        on run argv
            set inFile to POSIX file (item 1 of argv)
            set outPath to (POSIX file (item 2 of argv)) as text
            with timeout of 600 seconds
                tell application "Microsoft Word"
                    set wasOpen to false
                    repeat with i from 1 to (count of documents)
                        if (full name of document i) is (inFile as text) then set wasOpen to true
                    end repeat
                    open inFile
                    -- Older formats take a while to open: wait for the document instead of giving up.
                    set theDoc to missing value
                    repeat 120 times
                        repeat with i from 1 to (count of documents)
                            if (full name of document i) is (inFile as text) then set theDoc to document i
                        end repeat
                        if theDoc is not missing value then exit repeat
                        delay 0.5
                    end repeat
                    if theDoc is missing value then error "Word no pudo abrir el archivo."
                    save as theDoc file name outPath file format format PDF
                    -- Leave a document the user already had open (and its unsaved edits) alone.
                    if not wasOpen then close theDoc saving no
                end tell
            end timeout
        end run
        """
        try await AppleScriptExport.run(script, input: input, output: output, by: name)
    }
}

/// Microsoft PowerPoint, driven by AppleScript: the exact layout for PowerPoint files.
/// Turned on together with Word (Settings → Usar Microsoft Office).
struct MicrosoftPowerPointEngine: DocumentEngine {
    let name = "Microsoft PowerPoint"

    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Powerpoint") != nil
    }

    var isAvailable: Bool {
        Preferences.useMicrosoftOffice && Self.isInstalled
    }

    /// Keynote files aren't PowerPoint's: they go to LibreOffice or Keynote.
    func canConvert(_ input: URL) -> Bool {
        ["pptx", "ppt", "ppsx", "pps", "odp"].contains(input.pathExtension.lowercased())
    }

    func convertToPDF(_ input: URL, output: URL) async throws {
        // PowerPoint reports `full name` as a POSIX path (Word uses the old colon form).
        let script = """
        on run argv
            set inFile to POSIX file (item 1 of argv)
            set outPath to (POSIX file (item 2 of argv)) as text
            with timeout of 600 seconds
                tell application "Microsoft PowerPoint"
                    set wasOpen to false
                    repeat with i from 1 to (count of presentations)
                        if (full name of presentation i) is (item 1 of argv) then set wasOpen to true
                    end repeat
                    open inFile
                    -- .ppt and .odp take a while to open: wait for the presentation instead of giving up.
                    set thePres to missing value
                    repeat 120 times
                        repeat with i from 1 to (count of presentations)
                            if (full name of presentation i) is (item 1 of argv) then set thePres to presentation i
                        end repeat
                        if thePres is not missing value then exit repeat
                        delay 0.5
                    end repeat
                    if thePres is missing value then error "PowerPoint no pudo abrir el archivo."
                    save thePres in outPath as save as PDF
                    if not wasOpen then close thePres saving no
                end tell
            end timeout
        end run
        """
        try await AppleScriptExport.run(script, input: input, output: output, by: name)
    }
}

/// Runs an export script for a sandboxed app (Word, PowerPoint, Keynote).
///
/// Those apps can only write where the user let them, usually the folder the document is in, and not
/// in Gota's temporary folder (used for "PDF unido" and slide images). So they export next to the input,
/// under a hidden temporary name, and Gota moves the result where it was asked for.
enum AppleScriptExport {
    static func run(_ script: String, input: URL, output: URL, by app: String) async throws {
        let beside = input.deletingLastPathComponent()
            .appendingPathComponent(".gota-\(UUID().uuidString)")
            .appendingPathExtension(output.pathExtension)
        defer { try? FileManager.default.removeItem(at: beside) }
        // Paths travel as arguments (argv), never pasted into the script text.
        try await Shell.run("/usr/bin/osascript", ["-e", script, input.path, beside.path], timeout: .seconds(660))
        try Output.requireCreated(beside, by: app, from: input)
        try FileManager.default.moveItem(at: beside, to: output)
    }
}

/// docxide-pdf, a Rust DOCX → PDF converter built to match Word's layout (Apache-2.0), bundled inside
/// Gota by Engines/docxide/build.sh: no install, no window, under a second and ~35 MB of memory.
/// Measured the most faithful engine for .docx without Office (docs/MOTORES.md). It gets the bundled
/// Carlito and Caladea fonts, metric clones of Word's Calibri and Cambria, which Macs without Office
/// don't have. It never follows links to other files (checked in SecurityTests) and has no network code.
struct DocxideEngine: DocumentEngine {
    let name = "Gota (docxide)"

    private var binary: URL? {
        Bundle.main.url(forAuxiliaryExecutable: "docxide-pdf")
    }

    /// Builds made without Rust don't bundle it; then .docx falls back to LibreOffice.
    var isAvailable: Bool { binary != nil }

    func canConvert(_ input: URL) -> Bool {
        input.pathExtension.lowercased() == "docx"
    }

    func convertToPDF(_ input: URL, output: URL) async throws {
        guard let binary else { throw ConversionError.noEngine("Esta copia de Gota no incluye su motor de Word.") }
        guard try await FontResolver.unpackedSize(of: input) <= FontResolver.maxPackageBytes else {
            throw ConversionError.unsupported("documento demasiado grande una vez descomprimido")
        }
        let fonts = await FontResolver.prepare(for: input, bundled: Bundle.main.resourceURL?.appendingPathComponent("Fonts"))
        let environment = ["DOCXIDE_FONTS": fonts.folders.map(\.path).joined(separator: ":")]
        try await Shell.run(binary.path, [input.path, output.path], environment: environment, timeout: .seconds(120))
        try Output.requireCreated(output, by: name, from: input)
        if !fonts.missing.isEmpty {
            // The PDF is made, but in a substitute font: say so instead of leaving a silent difference.
            Notifier.post(
                title: "Faltan fuentes en «\(input.lastPathComponent)»",
                body: "\(fonts.missing.joined(separator: ", ")) no está en tu Mac y no es libre: el PDF puede verse distinto. Para el formato exacto, instálala o activa Microsoft Office en Ajustes → Motores."
            )
        }
    }
}

/// LibreOffice in headless mode: free and good, but layouts can shift versus Word.
struct LibreOfficeEngine: DocumentEngine {
    let name = "LibreOffice"

    /// The official download page, opened in the browser when the user asks (Gota itself never goes online).
    static let downloadPage = URL(string: "https://www.libreoffice.org/download/download-libreoffice/")!

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
            let profile = scratch.appendingPathComponent("profile")
            try Self.writeHardenedSettings(in: profile)
            try await Shell.run(soffice.path, [
                "-env:UserInstallation=\(profile.absoluteString)",
                "--headless", "--convert-to", "pdf",
                "--outdir", scratch.path,
                input.path,
            ])
            let produced = scratch.appendingPathComponent(input.deletingPathExtension().lastPathComponent + ".pdf")
            // soffice exits with 0 even when it could not convert, so check the result exists.
            guard FileManager.default.fileExists(atPath: produced.path) else {
                throw ConversionError.toolFailed(tool: name, output: "no pudo convertir «\(input.lastPathComponent)».")
            }
            try FileManager.default.moveItem(at: produced, to: output)
        }
    }

    /// A document can link to any file on the Mac (`file:///…`, `../`) or on the web, and LibreOffice
    /// would embed it in the PDF: a crafted file could smuggle the user's pictures into a PDF they send
    /// back. `BlockUntrustedRefererLinks` makes LibreOffice refuse links from documents it doesn't trust.
    static func writeHardenedSettings(in profile: URL) throws {
        let user = profile.appendingPathComponent("user")
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        let settings = """
        <?xml version="1.0" encoding="UTF-8"?>
        <oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <item oor:path="/org.openoffice.Office.Common/Security/Scripting">\
        <prop oor:name="BlockUntrustedRefererLinks" oor:op="fuse"><value>true</value></prop></item>
        </oor:items>
        """
        try settings.write(to: user.appendingPathComponent("registrymodifications.xcu"), atomically: true, encoding: .utf8)
    }
}

/// Apple's Keynote, driven by AppleScript: opens PowerPoint and Keynote files and exports a PDF.
/// Free and on many Macs, but macOS asks once to let Gota control Keynote, and LibreOffice measured
/// slightly more faithful (SSIM 0.97 vs 0.95 against PowerPoint), so it comes after LibreOffice.
struct KeynoteEngine: DocumentEngine {
    let name = "Keynote"

    var isAvailable: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iWork.Keynote") != nil
    }

    func canConvert(_ input: URL) -> Bool {
        FileKind.presentationExtensions.contains(input.pathExtension.lowercased())
    }

    func convertToPDF(_ input: URL, output: URL) async throws {
        // Paths travel as arguments (argv), never pasted into the script text.
        let script = """
        on run argv
            set inFile to POSIX file (item 1 of argv)
            set outFile to POSIX file (item 2 of argv)
            with timeout of 600 seconds
                tell application "Keynote"
                    -- If the user already has this presentation open, leave it open.
                    set openNames to name of every document
                    set theDoc to open inFile
                    export theDoc to outFile as PDF
                    if openNames does not contain (name of theDoc) then close theDoc saving no
                end tell
            end timeout
        end run
        """
        try await AppleScriptExport.run(script, input: input, output: output, by: name)
    }
}

/// Apple's Pages, driven by AppleScript: the original app for .pages documents. It opens its window
/// and asks once to be controlled, so it's only used for .pages files when LibreOffice is missing.
struct PagesEngine: DocumentEngine {
    let name = "Pages"

    var isAvailable: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iWork.Pages") != nil
    }

    func canConvert(_ input: URL) -> Bool {
        input.pathExtension.lowercased() == "pages"
    }

    func convertToPDF(_ input: URL, output: URL) async throws {
        let script = """
        on run argv
            set inFile to POSIX file (item 1 of argv)
            set outFile to POSIX file (item 2 of argv)
            with timeout of 600 seconds
                tell application "Pages"
                    -- If the user already has this document open, leave it open.
                    set openNames to name of every document
                    set theDoc to open inFile
                    export theDoc to outFile as PDF
                    if openNames does not contain (name of theDoc) then close theDoc saving no
                end tell
            end timeout
        end run
        """
        try await AppleScriptExport.run(script, input: input, output: output, by: name)
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
