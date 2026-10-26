import Foundation

/// Where results go: next to the original, never overwriting anything.
/// "photo.heic" → "photo.png", then "photo 2.png", "photo 3.png"…
enum Output {
    static func file(for input: URL, extension ext: String, suffix: String? = nil) -> URL {
        let directory = input.deletingLastPathComponent()
        var base = baseName(of: input)
        if let suffix { base += " \(suffix)" }
        return unique(directory, base: base, extension: ext)
    }

    /// A new, empty folder next to the input, e.g. "report pages".
    static func folder(for input: URL, suffix: String) throws -> URL {
        let directory = input.deletingLastPathComponent()
        let base = baseName(of: input) + " \(suffix)"
        let url = unique(directory, base: base, extension: nil)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    /// "photo.heic" → "photo", but a folder "v1.2" stays "v1.2".
    static func baseName(of url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let isPlainFolder = values?.isDirectory == true && values?.isPackage != true // a .pages file is a package
        return isPlainFolder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
    }

    static func unique(_ directory: URL, base: String, extension ext: String?) -> URL {
        func candidate(_ name: String) -> URL {
            let url = directory.appendingPathComponent(name)
            guard let ext, !ext.isEmpty else { return url }
            return url.appendingPathExtension(ext)
        }
        var url = candidate(base)
        var number = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = candidate("\(base) \(number)")
            number += 1
        }
        return url
    }

    /// Some tools (textutil, soffice) exit with 0 even when they could not convert,
    /// so a result only counts if the file is really there.
    /// - Parameter input: the user's file, named in the error (the output may be a hidden temporary name).
    static func requireCreated(_ url: URL, by tool: String, from input: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConversionError.toolFailed(tool: tool, output: "no pudo convertir «\(input.lastPathComponent)».")
        }
    }

    /// A private scratch folder that is removed when `body` finishes.
    static func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gota-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await body(url)
    }
}
