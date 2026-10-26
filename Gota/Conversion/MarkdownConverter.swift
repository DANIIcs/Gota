import AppKit

/// Markdown (`.md`) to HTML, PDF and Word, with macOS's own Markdown parser (Foundation, CommonMark with
/// GitHub tables): nothing to install.
///
/// The document is parsed into blocks (headings, lists, quotes, code, tables…), written out as styled
/// HTML, and that HTML goes through the same TextKit renderer as other documents.
enum MarkdownConverter {
    static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    /// Self-contained, styled HTML for the document.
    static func html(from input: URL) throws -> String {
        guard let source = try? String(contentsOf: input, encoding: .utf8) else { throw ConversionError.unreadable(input) }
        let document: AttributedString
        do {
            document = try AttributedString(
                markdown: source,
                options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
            )
        } catch {
            throw ConversionError.unreadable(input)
        }
        let title = escape(input.deletingPathExtension().lastPathComponent)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(title)</title><style>\(style)</style></head>
        <body>\(body(of: document))</body></html>
        """
    }

    static func toHTML(_ input: URL) throws -> URL {
        let output = Output.file(for: input, extension: "html")
        try html(from: input).write(to: output, atomically: true, encoding: .utf8)
        return output
    }

    @MainActor
    static func toPDF(_ input: URL, output: URL) throws {
        let text = try attributedString(from: input)
        try DocumentRenderer.write(text, paper: DocumentRenderer.defaultPaper,
                                   margins: NSEdgeInsets(top: 64, left: 64, bottom: 64, right: 64), to: output)
    }

    @MainActor
    static func toWord(_ input: URL) throws -> URL {
        let text = try attributedString(from: input)
        let data = try text.data(from: NSRange(location: 0, length: text.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
        let output = Output.file(for: input, extension: "docx")
        try data.write(to: output, options: .withoutOverwriting)
        return output
    }

    /// The styled document, with only the images that are files in the document's own folder.
    /// Main actor: reading HTML goes through WebKit.
    @MainActor
    static func attributedString(from input: URL) throws -> NSAttributedString {
        let folder = input.deletingLastPathComponent()
        guard let text = NSAttributedString(html: Data(try html(from: input).utf8), baseURL: folder, documentAttributes: nil) else {
            throw ConversionError.unreadable(input)
        }
        return DocumentRenderer.keepingOnlyImages(in: folder, from: text)
    }

    // MARK: - Blocks

    /// Walks the runs, opening and closing each block (by its identity) as the path from the document
    /// root to the run changes, so nested lists, quotes and tables come out properly nested.
    static func body(of document: AttributedString) -> String {
        var html = ""
        var open: [PresentationIntent.IntentType] = [] // outermost first
        for run in document.runs {
            let path = Array((run.presentationIntent?.components ?? []).reversed())
            var shared = 0
            while shared < min(open.count, path.count), open[shared].identity == path[shared].identity { shared += 1 }
            for component in open[shared...].reversed() { html += closing(component) }
            for (index, component) in path[shared...].enumerated() {
                html += opening(component, parent: shared + index > 0 ? path[shared + index - 1] : nil)
            }
            open = path
            if case .thematicBreak? = path.last?.kind { continue }
            html += inline(run, text: String(document[run.range].characters), inCode: isCode(path.last))
        }
        for component in open.reversed() { html += closing(component) }
        return html
    }

    private static func isCode(_ component: PresentationIntent.IntentType?) -> Bool {
        if case .codeBlock? = component?.kind { return true }
        return false
    }

    private static func opening(_ component: PresentationIntent.IntentType, parent: PresentationIntent.IntentType?) -> String {
        switch component.kind {
        case .paragraph: "<p>"
        case .header(let level): "<h\(min(max(level, 1), 6))>"
        case .orderedList: "<ol>"
        case .unorderedList: "<ul>"
        case .listItem: "<li>"
        case .codeBlock: "<pre><code>"
        case .blockQuote: "<blockquote>"
        case .thematicBreak: "<hr>"
        case .table: "<table>"
        case .tableHeaderRow, .tableRow: "<tr>"
        case .tableCell:
            if case .tableHeaderRow? = parent?.kind { "<th>" } else { "<td>" }
        @unknown default: "<div>"
        }
    }

    private static func closing(_ component: PresentationIntent.IntentType) -> String {
        switch component.kind {
        case .paragraph: "</p>"
        case .header(let level): "</h\(min(max(level, 1), 6))>"
        case .orderedList: "</ol>"
        case .unorderedList: "</ul>"
        case .listItem: "</li>"
        case .codeBlock: "</code></pre>"
        case .blockQuote: "</blockquote>"
        case .thematicBreak: ""
        case .table: "</table>"
        case .tableHeaderRow, .tableRow: "</tr>"
        case .tableCell: "</td>" // also closes <th>: HTML ends cells at the next cell or row
        @unknown default: "</div>"
        }
    }

    // MARK: - Inline

    private static func inline(_ run: AttributedString.Runs.Run, text: String, inCode: Bool) -> String {
        if let image = run.imageURL {
            // Only images next to the document: a remote image would be fetched on conversion, telling
            // whoever sent the file when it was opened (a tracking pixel), and file:// could reach anywhere.
            guard image.scheme == nil, !image.relativeString.hasPrefix("/") else { return escape(text) }
            return "<img src=\"\(escape(image.relativeString))\" alt=\"\(escape(text))\">"
        }
        var html = escape(text)
        if inCode { return html }
        let style = run.inlinePresentationIntent ?? []
        if style.contains(.lineBreak) { return "<br>" }
        if style.contains(.softBreak) { return " " }
        if style.contains(.code) { html = "<code>\(html)</code>" }
        if style.contains(.emphasized) { html = "<em>\(html)</em>" }
        if style.contains(.stronglyEmphasized) { html = "<strong>\(html)</strong>" }
        if style.contains(.strikethrough) { html = "<del>\(html)</del>" }
        if let link = run.link, ["https", "http", "mailto"].contains(link.scheme?.lowercased() ?? "") {
            html = "<a href=\"\(escape(link.absoluteString))\">\(html)</a>"
        }
        return html
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// GitHub-like look with the system font, kept to what TextKit's HTML import understands.
    private static let style = """
    body { font-family: -apple-system, 'Helvetica Neue', sans-serif; font-size: 11pt; line-height: 1.45; color: #1f2328; }
    h1 { font-size: 22pt; margin: 0 0 8pt; } h2 { font-size: 16pt; margin: 14pt 0 6pt; }
    h3 { font-size: 13pt; margin: 12pt 0 4pt; } h4, h5, h6 { font-size: 11pt; margin: 10pt 0 4pt; }
    p, ul, ol, blockquote, pre, table { margin: 0 0 8pt; }
    code { font-family: Menlo, monospace; font-size: 9.5pt; background-color: #f2f4f7; }
    pre { font-family: Menlo, monospace; font-size: 9.5pt; background-color: #f2f4f7; padding: 8pt; margin: 4pt 0 12pt; }
    blockquote { color: #59636e; border-left: 3pt solid #d1d9e0; padding-left: 10pt; margin-left: 0; }
    table { border-collapse: collapse; width: 100%; margin: 4pt 0 12pt; } th, td { border: 1px solid #d1d9e0; padding: 4pt 8pt; }
    th { background-color: #f6f8fa; font-weight: bold; } a { color: #0969da; }
    hr { border: 0; border-top: 1px solid #d1d9e0; }
    """
}
