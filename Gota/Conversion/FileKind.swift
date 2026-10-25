import Foundation
import UniformTypeIdentifiers

/// Broad family of a file, used to pick which bubbles the wheel shows.
enum FileKind: Hashable, Sendable {
    case image
    case pdf
    case video
    case audio
    case document
    case folder
    case other

    static let documentExtensions: Set<String> = ["docx", "doc", "odt", "rtf", "rtfd", "pages", "txt", "html", "htm"]

    static func of(_ url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        // Checked first: .rtfd and .pages documents are folders (packages) on disk.
        if documentExtensions.contains(ext) { return .document }
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return .folder
        }
        guard let type = UTType(filenameExtension: ext) else { return .other }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return .other
    }

    /// The kind shared by all files, or `.other` when they are mixed.
    static func common(_ urls: [URL]) -> FileKind {
        let kinds = Set(urls.map(of))
        guard kinds.count == 1, let kind = kinds.first else { return .other }
        return kind
    }
}
