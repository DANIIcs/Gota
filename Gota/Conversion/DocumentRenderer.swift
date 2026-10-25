import AppKit

/// Lays rich text out on pages and writes a PDF with TextKit, the engine TextEdit uses.
/// Built into macOS: no app to open and no permission to grant, at the cost of exact Word layout.
enum DocumentRenderer {
    static let defaultPaper = NSSize(width: 595, height: 842) // A4
    static let defaultMargin: CGFloat = 72

    /// Formats macOS can read into an attributed string (Pages is not one of them).
    static let readableExtensions: Set<String> = ["docx", "doc", "odt", "rtf", "rtfd", "txt", "html", "htm"]

    /// Main actor because reading HTML goes through WebKit, which must run on the main thread.
    @MainActor
    static func pdf(from input: URL, to output: URL) throws {
        var attributes: NSDictionary?
        var text: NSAttributedString
        do {
            text = try NSAttributedString(url: input, options: [:], documentAttributes: &attributes)
        } catch {
            throw ConversionError.unreadable(input)
        }
        if ["html", "htm"].contains(input.pathExtension.lowercased()) {
            text = keepingOnlyImages(in: input.deletingLastPathComponent(), from: text)
        }
        let info = attributes as? [NSAttributedString.DocumentAttributeKey: Any] ?? [:]
        let paper = (info[.paperSize] as? NSValue)?.sizeValue ?? .zero
        let margins = NSEdgeInsets(
            top: margin(info[.topMargin]),
            left: margin(info[.leftMargin]),
            bottom: margin(info[.bottomMargin]),
            right: margin(info[.rightMargin])
        )
        try write(text, paper: paper.width > 0 && paper.height > 0 ? paper : defaultPaper, margins: margins, to: output)
    }

    /// An HTML page can point at any image on the Mac (`file:///…`, `../`) and macOS embeds it:
    /// a crafted page could smuggle the user's pictures into a PDF they send back.
    /// Keeps only images that are files inside the page's own folder; drops the rest.
    static func keepingOnlyImages(in folder: URL, from text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        let all = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.attachment, in: all, options: .reverse) { value, range, _ in
            guard let attachment = value as? NSTextAttachment, !isFile(attachment, inside: folder) else { return }
            result.replaceCharacters(in: range, with: "")
        }
        return result
    }

    /// Whether the attachment's bytes are those of a file (same name and content) under `folder`.
    private static func isFile(_ attachment: NSTextAttachment, inside folder: URL) -> Bool {
        guard let wrapper = attachment.fileWrapper,
              let name = wrapper.preferredFilename ?? wrapper.filename,
              let data = wrapper.regularFileContents else { return false }
        let root = folder.resolvingSymlinksInPath().path + "/"
        let files = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        var visited = 0
        while let url = files?.nextObject() as? URL, visited < 5_000 {
            visited += 1
            guard url.lastPathComponent == name,
                  (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize == data.count,
                  url.resolvingSymlinksInPath().path.hasPrefix(root) // a link inside pointing outside doesn't count
            else { continue }
            if (try? Data(contentsOf: url)) == data { return true }
        }
        return false
    }

    static func write(_ text: NSAttributedString, paper: NSSize, margins: NSEdgeInsets, to output: URL) throws {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let area = NSSize(
            width: paper.width - margins.left - margins.right,
            height: paper.height - margins.top - margins.bottom
        )

        // One container per page: TextKit fills them in order and starts a new one at page breaks (\f).
        var pages: [NSTextContainer] = []
        repeat {
            let container = NSTextContainer(size: area)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            pages.append(container)
        } while NSMaxRange(layout.glyphRange(for: pages[pages.count - 1])) < layout.numberOfGlyphs && pages.count < 10_000

        var box = CGRect(origin: .zero, size: paper)
        guard let context = CGContext(output as CFURL, mediaBox: &box, nil) else {
            throw ConversionError.unsupported("PDF")
        }
        let origin = NSPoint(x: margins.left, y: margins.top)
        for page in pages {
            context.beginPDFPage(nil)
            context.saveGState()
            // TextKit draws top-down (flipped); PDF pages grow bottom-up.
            context.translateBy(x: 0, y: paper.height)
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            let range = layout.glyphRange(for: page)
            layout.drawBackground(forGlyphRange: range, at: origin)
            layout.drawGlyphs(forGlyphRange: range, at: origin)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func margin(_ value: Any?) -> CGFloat {
        guard let number = value as? NSNumber, number.doubleValue >= 0 else { return defaultMargin }
        return CGFloat(number.doubleValue)
    }
}
