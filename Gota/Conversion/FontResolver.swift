import AppKit
import Foundation

/// Makes sure a Word document's fonts are there before it's converted.
///
/// A document set in a font the Mac doesn't have (Word downloads Poppins, Montserrat… from Microsoft's
/// cloud without telling you) comes out in Arial instead: different widths, every line and page moves.
/// Measured on a real 9-page document: 0.497 SSIM and 7 pages with Arial, 0.859 and 9 pages with Poppins.
///
/// So, for the fonts the document uses that aren't installed:
/// - open-source ones are downloaded once from Google Fonts' official repository into Gota's own folder
///   (about 0.5–3 MB per family). Only the font's name is sent, never the document. Can be turned off;
/// - the rest (Microsoft's own, like Aptos) are reported, so the user knows the PDF may differ.
enum FontResolver {
    /// Gota's folder for downloaded fonts, one subfolder per family.
    static var downloadedFonts: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Gota/Fonts", isDirectory: true)
    }

    struct Result {
        /// Font folders to hand to the engine (`DOCXIDE_FONTS`).
        var folders: [URL]
        /// Fonts the document uses that are still missing.
        var missing: [String]
    }

    /// Fonts that Gota already covers without installing anything: its bundled metric clones.
    private static let coveredByBundledClones: Set<String> = ["calibri", "cambria", "carlito", "caladea"]

    /// Symbol and decorative fonts Word uses for bullets and glyphs: not worth a warning.
    private static let ignored: Set<String> = ["symbol", "wingdings", "wingdings 2", "wingdings 3", "webdings",
                                               "ms mincho", "ms gothic", "simsun", "mangal"]

    static func prepare(for docx: URL, bundled: URL?) async -> Result {
        var folders = [bundled, downloadedFonts].compactMap { $0 }
        guard let used = try? await fonts(usedBy: docx) else { return Result(folders: folders, missing: []) }
        var missing = used.filter { !isAvailable($0) }.sorted()
        if Preferences.downloadOpenFonts, !missing.isEmpty {
            for family in missing where (try? await GoogleFonts.download(family, into: downloadedFonts)) == true {
                missing.removeAll { $0 == family }
            }
        }
        folders.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
        return Result(folders: folders, missing: missing)
    }

    // MARK: - Which fonts the document uses

    /// Font names set on text, styles and defaults, plus the theme's fonts when something refers to them.
    /// Reads a few XML parts of the package with `unzip -p`; refuses documents that unpack to more than
    /// `maxXMLBytes` (a zip bomb would otherwise fill the disk).
    static func fonts(usedBy docx: URL) async throws -> Set<String> {
        let listing = try await Shell.run("/usr/bin/unzip", ["-Z1", docx.path], timeout: .seconds(10))
        let parts = listing.split(separator: "\n").map(String.init).filter { name in
            name.hasPrefix("word/") && name.hasSuffix(".xml")
                && ["document", "styles", "header", "footer", "footnotes", "endnotes", "numbering"].contains { name.contains($0) }
        }
        let theme = listing.split(separator: "\n").map(String.init).first { $0.hasPrefix("word/theme/") && $0.hasSuffix(".xml") }
        guard !parts.isEmpty else { return [] }
        let sizes = try await Shell.run("/usr/bin/unzip", ["-l", docx.path] + parts, timeout: .seconds(10))
        let total = sizes.split(separator: "\n").last.flatMap { Int($0.split(separator: " ").first ?? "") } ?? 0
        guard total <= maxXMLBytes else { return [] }

        let xml = try await Shell.run("/usr/bin/unzip", ["-p", docx.path] + parts, timeout: .seconds(20))
        var names = Set(matches(of: #"w:(?:ascii|hAnsi)="([^"]+)""#, in: xml))
        if xml.contains("w:asciiTheme=") || xml.contains("w:hAnsiTheme=") || !xml.contains("<w:rPrDefault>"), let theme {
            let themeXML = try await Shell.run("/usr/bin/unzip", ["-p", docx.path, theme], timeout: .seconds(10))
            names.formUnion(matches(of: #"<a:(?:major|minor)Font>\s*<a:latin typeface="([^"]+)""#, in: themeXML))
        }
        return Set(names.filter { !$0.isEmpty && !ignored.contains($0.lowercased()) })
    }

    static let maxXMLBytes = 60 * 1024 * 1024

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    // MARK: - Is it there?

    static func isAvailable(_ family: String) -> Bool {
        let name = family.lowercased()
        if coveredByBundledClones.contains(name) { return true }
        if NSFontManager.shared.availableFontFamilies.contains(where: { $0.lowercased() == name }) { return true }
        if NSFont(name: family, size: 12) != nil { return true }
        return GoogleFonts.isDownloaded(family, in: downloadedFonts)
    }
}

/// Downloads open-source fonts from Google Fonts' repository on GitHub (github.com/google/fonts),
/// the same files fonts.google.com serves, under the SIL Open Font License or Apache 2.0.
enum GoogleFonts {
    private static let licenseFolders = ["ofl", "apache", "ufl"]
    /// Biggest font file accepted (static families are ~150–400 KB per style).
    static let maxFileBytes = 10 * 1024 * 1024
    /// Biggest family accepted in total.
    static let maxFamilyBytes = 12 * 1024 * 1024

    /// "Open Sans" → "opensans", the repository's folder name. Anything but letters, digits and spaces
    /// is refused, so a crafted document can't make Gota request arbitrary paths.
    static func folderName(for family: String) -> String? {
        guard !family.isEmpty, family.count <= 64,
              family.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == " ") }) else { return nil }
        return family.lowercased().replacingOccurrences(of: " ", with: "")
    }

    static func isDownloaded(_ family: String, in root: URL) -> Bool {
        guard let folder = folderName(for: family) else { return false }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(folder).path)) ?? []
        return files.contains { $0.lowercased().hasSuffix(".ttf") || $0.lowercased().hasSuffix(".otf") }
    }

    /// Word names extra weights as their own family ("Poppins SemiBold"): the repository keeps them in
    /// the base family's folder ("poppins"), as "Poppins-SemiBold.ttf".
    static let weights = ["Thin", "ExtraLight", "Light", "Medium", "SemiBold", "ExtraBold", "Black"]

    /// ("Poppins", ["Regular", "Bold", "Italic", "BoldItalic"]) or ("Poppins", ["SemiBold", "SemiBoldItalic"]).
    static func request(for family: String) -> (family: String, styles: Set<String>) {
        for weight in weights where family.hasSuffix(" " + weight) {
            return (String(family.dropLast(weight.count + 1)), [weight, weight + "Italic"])
        }
        return (family, ["Regular", "Bold", "Italic", "BoldItalic"])
    }

    /// Returns false when Google Fonts doesn't have the family (it isn't open source).
    /// Only the styles the document can use are fetched: ~0.7 MB for four static styles instead of
    /// a whole family (3 MB and 18 files for Poppins).
    static func download(_ family: String, into root: URL) async throws -> Bool {
        let (base, styles) = request(for: family)
        guard let folder = folderName(for: base), let saved = folderName(for: family) else { return false }
        for license in licenseFolders {
            guard let files = try await listing(license: license, folder: folder) else { continue }
            let fonts = choose(files, styles: styles)
            guard !fonts.isEmpty, fonts.reduce(0, { $0 + $1.size }) <= maxFamilyBytes else { return false }
            let destination = root.appendingPathComponent(saved, isDirectory: true)
            let staging = root.appendingPathComponent(".\(saved)-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging) }
            for file in fonts {
                let data = try await fetch(file.download, limit: maxFileBytes)
                guard isFont(data) else { throw URLError(.cannotDecodeContentData) }
                try data.write(to: staging.appendingPathComponent(file.name))
            }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: staging, to: destination)
            return true
        }
        return false
    }

    struct RemoteFile: Decodable {
        let name: String
        let size: Int
        let download: URL

        enum CodingKeys: String, CodingKey { case name, size, download = "download_url" }
    }

    /// The family's files, or nil if the folder doesn't exist under that license.
    private static func listing(license: String, folder: String) async throws -> [RemoteFile]? {
        let url = URL(string: "https://api.github.com/repos/google/fonts/contents/\(license)/\(folder)")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Gota/\(UpdateChecker.currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard status == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([RemoteFile].self, from: data)
    }

    /// The requested static styles when the family has them ("Poppins-Bold.ttf"), otherwise its variable
    /// font. Only files served from the repository itself are accepted.
    static func choose(_ files: [RemoteFile], styles: Set<String> = ["Regular", "Bold", "Italic", "BoldItalic"]) -> [RemoteFile] {
        let trusted = files.filter { file in
            file.download.scheme == "https" && file.download.host() == "raw.githubusercontent.com"
                && file.download.path().hasPrefix("/google/fonts/") && file.size <= maxFileBytes
                && (file.name.hasSuffix(".ttf") || file.name.hasSuffix(".otf"))
                && !file.name.contains("/") && !file.name.hasPrefix(".")
        }
        let statics = trusted.filter { file in
            guard !file.name.contains("["), let dash = file.name.lastIndex(of: "-"), let dot = file.name.lastIndex(of: ".") else { return false }
            return styles.contains(String(file.name[file.name.index(after: dash)..<dot]))
        }
        return statics.isEmpty ? trusted.filter { $0.name.contains("[") } : statics
    }

    private static func fetch(_ url: URL, limit: Int) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Gota/\(UpdateChecker.currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= limit else { throw URLError(.badServerResponse) }
        return data
    }

    /// A TrueType or OpenType file that macOS's own font parser accepts.
    static func isFont(_ data: Data) -> Bool {
        let magic = data.prefix(4)
        let known: [Data] = [Data([0, 1, 0, 0]), Data("true".utf8), Data("OTTO".utf8)]
        guard known.contains(magic) else { return false }
        let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor] ?? []
        return !descriptors.isEmpty
    }

    /// Size of the downloaded fonts, for Settings.
    static func downloadedSize(in root: URL) -> Int64 {
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.compactMap { ($0 as? URL).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } }
            .reduce(0) { $0 + Int64($1) }
    }
}
