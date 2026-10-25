import AppKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// PDF work with PDFKit (built into macOS).
enum PDFTools {
    /// Every page as an image, in a new folder next to the PDF.
    static func pagesToImages(_ input: URL, type: UTType, scale: CGFloat = 2) throws -> URL {
        guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
        let folder = try Output.folder(for: input, suffix: "páginas")
        let ext = type.preferredFilenameExtension ?? "png"
        let digits = String(document.pageCount).count

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let image = page.thumbnail(of: NSSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

            let number = String(index + 1).leftPadded(to: digits)
            let url = folder.appendingPathComponent("Página \(number)").appendingPathExtension(ext)
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
                throw ConversionError.unsupported(ext.uppercased())
            }
            CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
            _ = CGImageDestinationFinalize(destination)
        }
        return folder
    }

    /// The PDF's text layer as a .txt file (scanned PDFs have none; OCR comes later).
    static func text(_ input: URL) throws -> URL {
        guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
        let output = Output.file(for: input, extension: "txt")
        try (document.string ?? "").write(to: output, atomically: true, encoding: .utf8)
        return output
    }

    /// Several PDFs into one, in the order they were dragged.
    static func merge(_ inputs: [URL]) throws -> URL {
        guard let first = inputs.first else { throw ConversionError.unsupported("sin archivos") }
        let merged = PDFDocument()
        for input in inputs {
            guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
            for index in 0..<document.pageCount {
                if let page = document.page(at: index)?.copy() as? PDFPage {
                    merged.insert(page, at: merged.pageCount)
                }
            }
        }
        let output = Output.file(for: first, extension: "pdf", suffix: "unido")
        guard merged.write(to: output) else { throw ConversionError.unsupported("PDF") }
        return output
    }

    /// One PDF per page, in a new folder.
    static func split(_ input: URL) throws -> URL {
        guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
        let folder = try Output.folder(for: input, suffix: "dividido")
        let digits = String(document.pageCount).count
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
            let single = PDFDocument()
            single.insert(page, at: 0)
            let number = String(index + 1).leftPadded(to: digits)
            _ = single.write(to: folder.appendingPathComponent("Página \(number).pdf"))
        }
        return folder
    }

    /// Rotates every page 90° clockwise into a new file.
    static func rotate(_ input: URL) throws -> URL {
        guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
        for index in 0..<document.pageCount {
            if let page = document.page(at: index) {
                page.rotation = (page.rotation + 90) % 360
            }
        }
        let output = Output.file(for: input, extension: "pdf", suffix: "rotado")
        guard document.write(to: output) else { throw ConversionError.unsupported("PDF") }
        return output
    }

    /// Images into a single PDF, one page each, in the order they were dragged.
    static func imagesToPDF(_ inputs: [URL]) throws -> URL {
        guard let first = inputs.first else { throw ConversionError.unsupported("sin archivos") }
        let document = PDFDocument()
        for input in inputs {
            guard let image = NSImage(contentsOf: input), let page = PDFPage(image: image) else {
                throw ConversionError.unreadable(input)
            }
            document.insert(page, at: document.pageCount)
        }
        let output = Output.file(for: first, extension: "pdf")
        guard document.write(to: output) else { throw ConversionError.unsupported("PDF") }
        return output
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
