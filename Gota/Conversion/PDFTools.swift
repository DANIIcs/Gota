import AppKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// PDF work with PDFKit (built into macOS).
enum PDFTools {
    /// Every page as an image, in a new folder next to the PDF.
    /// - Parameters:
    ///   - namedAfter: the file the folder is named after and saved next to (default: the PDF itself),
    ///     for PDFs made in a scratch folder from a presentation.
    ///   - itemName: "Página 1.png"…, or "Diapositiva 1.png"… for slides.
    static func pagesToImages(
        _ input: URL,
        type: UTType,
        scale: CGFloat = 2,
        namedAfter: URL? = nil,
        suffix: String = "páginas",
        itemName: String = "Página"
    ) throws -> URL {
        let document = try open(input)
        let folder = try Output.folder(for: namedAfter ?? input, suffix: suffix)
        let ext = type.preferredFilenameExtension ?? "png"
        let digits = String(document.pageCount).count

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let size = displaySize(of: page)
            // A crafted PDF can declare a page meters wide: cap the image so it can't eat all memory.
            let pageScale = min(scale, maxPagePixels / max(size.width, size.height, 1))
            let image = page.thumbnail(of: NSSize(width: size.width * pageScale, height: size.height * pageScale), for: .mediaBox)
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

            let number = String(index + 1).leftPadded(to: digits)
            let url = folder.appendingPathComponent("\(itemName) \(number)").appendingPathExtension(ext)
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
                throw ConversionError.unsupported(ext.uppercased())
            }
            CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ConversionError.unsupported(ext.uppercased()) }
        }
        return folder
    }

    /// The PDF's text layer as a .txt file (scanned PDFs have none; OCR comes later).
    /// Several PDFs give one .txt with their texts in the order they were dragged.
    static func text(_ inputs: [URL]) throws -> URL {
        let text = try inputs.map { try open($0).string ?? "" }.joined(separator: "\n\n")
        // An empty .txt reported as "Listo" looks like a bug: say why instead.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.unsupported("PDF sin texto (¿escaneado?)")
        }
        let output = combinedOutput(for: inputs, extension: "txt")
        try text.write(to: output, atomically: true, encoding: .utf8)
        return output
    }

    /// The PDF's text, with its fonts and one Word page per PDF page, as an editable .docx.
    /// Written by macOS's own DOCX writer; images and exact layout are not kept.
    /// Several PDFs give one document with all their pages, in the order they were dragged.
    static func toWord(_ inputs: [URL]) throws -> URL {
        let text = NSMutableAttributedString()
        for input in inputs {
            let document = try open(input)
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index)?.attributedString else { continue }
                if text.length > 0 {
                    text.append(NSAttributedString(string: "\u{0C}")) // becomes a Word page break
                }
                text.append(page)
            }
        }
        guard !text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.unsupported("PDF sin texto (¿escaneado?)")
        }
        let data = try text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        let output = combinedOutput(for: inputs, extension: "docx")
        try data.write(to: output, options: .withoutOverwriting)
        return output
    }

    /// Several PDFs into one, in the order they were dragged.
    /// - Parameter namedAfter: the file the result is named after and saved next to (default: the first input).
    static func merge(_ inputs: [URL], namedAfter: URL? = nil) throws -> URL {
        guard let first = namedAfter ?? inputs.first else { throw ConversionError.unsupported("sin archivos") }
        let merged = PDFDocument()
        for input in inputs {
            let document = try open(input)
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
        let document = try open(input)
        let folder = try Output.folder(for: input, suffix: "dividido")
        let digits = String(document.pageCount).count
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
            let single = PDFDocument()
            single.insert(page, at: 0)
            let number = String(index + 1).leftPadded(to: digits)
            guard single.write(to: folder.appendingPathComponent("Página \(number).pdf")) else {
                throw ConversionError.unsupported("PDF")
            }
        }
        return folder
    }

    /// Rotates every page 90° clockwise into a new file.
    static func rotate(_ input: URL) throws -> URL {
        let document = try open(input)
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
        guard !inputs.isEmpty else { throw ConversionError.unsupported("sin archivos") }
        let document = PDFDocument()
        for input in inputs {
            guard let image = NSImage(contentsOf: input), let page = PDFPage(image: image) else {
                throw ConversionError.unreadable(input)
            }
            document.insert(page, at: document.pageCount)
        }
        let output = combinedOutput(for: inputs, extension: "pdf")
        guard document.write(to: output) else { throw ConversionError.unsupported("PDF") }
        return output
    }

    /// "foto.pdf" for one file, "foto unido.pdf" when several were combined into it.
    static func combinedOutput(for inputs: [URL], extension ext: String) -> URL {
        Output.file(for: inputs[0], extension: ext, suffix: inputs.count > 1 ? "unido" : nil)
    }
}

extension PDFTools {
    /// Longest side of a page exported as an image (about 3× a 4K screen).
    static let maxPagePixels: CGFloat = 10_000

    /// Password-protected PDFs open fine but have no readable pages: fail instead of producing empty output.
    static func open(_ input: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
        guard !document.isLocked else { throw ConversionError.unsupported("PDF con contraseña") }
        return document
    }

    /// The page as it is shown: a page rotated 90° is wider than its media box.
    /// Passing the unrotated size made `thumbnail` fit a tall page in a wide box, at half resolution.
    static func displaySize(of page: PDFPage) -> CGSize {
        let bounds = page.bounds(for: .mediaBox)
        return page.rotation % 180 == 0 ? bounds.size : CGSize(width: bounds.height, height: bounds.width)
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
