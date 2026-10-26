import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Decides which bubbles appear for the dragged files in each mode.
/// To add an option, add a `WheelAction` here (see docs/AGREGAR-CONVERSION.md).
enum Catalog {
    static func actions(for files: [URL], mode: WheelMode) -> [WheelAction] {
        guard !files.isEmpty else { return [] }
        let kind = FileKind.common(files)
        let actions: [WheelAction]
        switch mode {
        case .convert: actions = convert(kind, files)
        case .tools: actions = tools(kind, files)
        case .actions: actions = general(files)
        }
        return Array(actions.prefix(WheelLayout.maxItems))
    }

    // MARK: - Convert (⇧)

    private static func convert(_ kind: FileKind, _ files: [URL]) -> [WheelAction] {
        switch kind {
        case .image:
            let targets: [(UTType, String)] = [(.png, "PNG"), (.jpeg, "JPEG"), (.heic, "HEIC"), (.tiff, "TIFF")]
            // Don't offer "PNG" when every dragged file is already a PNG.
            let remaining = targets.filter { target in
                !files.allSatisfy { UTType(filenameExtension: $0.pathExtension.lowercased()) == target.0 }
            }
            var actions = remaining.map { target in
                let (type, label) = target
                return WheelAction.eachFile(id: "image-\(label)", title: label, symbol: "photo") { file in
                    try ImageConverter.convert(file, to: type, quality: type == .png || type == .tiff ? nil : 0.9)
                }.producing(type)
            }
            actions.append(.eachFile(id: "image-pdf", title: "PDF", symbol: "doc.richtext") { try PDFTools.imagesToPDF([$0]) }.producing(.pdf))
            actions += combined(files, id: "image-pdf", title: "PDF", output: .pdf) { [try PDFTools.imagesToPDF($0)] }
            return actions

        case .pdf:
            return [.eachFile(id: "pdf-docx", title: "Word", symbol: "doc.text") { try PDFTools.toWord([$0]) }.producing(docx)]
                + combined(files, id: "pdf-docx", title: "Word", output: docx) { [try PDFTools.toWord($0)] }
                + [
                    .eachFile(id: "pdf-png", title: "PNG", symbol: "photo.on.rectangle") { try PDFTools.pagesToImages($0, type: .png) }
                        .producing(.png),
                    .eachFile(id: "pdf-jpeg", title: "JPEG", symbol: "photo.stack") { try PDFTools.pagesToImages($0, type: .jpeg) }
                        .producing(.jpeg),
                    .eachFile(id: "pdf-text", title: String(localized: "Texto"), symbol: "text.alignleft") { try PDFTools.text([$0]) }.producing(.plainText),
                ]
                + combined(files, id: "pdf-text", title: String(localized: "Texto"), output: .plainText) { [try PDFTools.text($0)] }

        case .video:
            var actions: [WheelAction] = []
            if !all(files, haveExtension: ["mp4", "m4v"]) {
                actions.append(.eachFile(id: "video-mp4", title: "MP4", symbol: "film") {
                    try await MediaConverter.export($0, preset: AVAssetExportPresetHighestQuality, as: .mp4, extension: "mp4")
                }.producing(.mpeg4Movie))
            }
            if !all(files, haveExtension: ["mov"]) {
                actions.append(.eachFile(id: "video-mov", title: "MOV", symbol: "film.stack") {
                    try await MediaConverter.export($0, preset: AVAssetExportPresetHighestQuality, as: .mov, extension: "mov")
                }.producing(.quickTimeMovie))
            }
            actions.append(.eachFile(id: "video-m4a", title: String(localized: "Solo audio"), symbol: "waveform") {
                try await MediaConverter.export($0, preset: AVAssetExportPresetAppleM4A, as: .m4a, extension: "m4a")
            }.producing(UTType(filenameExtension: "m4a") ?? .mpeg4Audio))
            return actions

        case .audio:
            let targets: [(id: String, title: String, symbol: String, format: String, data: String, ext: String)] = [
                ("audio-m4a", "M4A", "waveform", "m4af", "aac", "m4a"),
                ("audio-wav", "WAV", "waveform.path", "WAVE", "LEI16", "wav"),
                ("audio-aiff", "AIFF", "waveform.path.ecg", "AIFF", "BEI16", "aiff"),
            ]
            return targets.filter { !all(files, haveExtension: [$0.ext]) }.map { target in
                .eachFile(id: target.id, title: target.title, symbol: target.symbol) {
                    try await MediaConverter.audio($0, format: target.format, data: target.data, extension: target.ext)
                }.producing(UTType(filenameExtension: target.ext) ?? .audio)
            }

        case .document:
            var actions: [WheelAction] = [
                .eachFile(id: "doc-pdf", title: "PDF", symbol: "doc.richtext") { try await DocumentEngines.toPDF($0) }.producing(.pdf),
            ]
            actions += combined(files, id: "doc-pdf", title: "PDF", output: .pdf) { [try await DocumentEngines.toSinglePDF($0)] }
            // textutil can't read Pages documents: only the PDF engines (LibreOffice) can.
            guard !files.contains(where: { $0.pathExtension.lowercased() == "pages" }) else { return actions }
            let targets: [(id: String, title: String, symbol: String, format: String, extensions: Set<String>)] = [
                ("doc-docx", "Word", "doc.text", "docx", ["docx"]),
                ("doc-txt", "Texto", "text.alignleft", "txt", ["txt"]),
                ("doc-html", "HTML", "chevron.left.forwardslash.chevron.right", "html", ["html", "htm"]),
            ]
            for target in targets where !all(files, haveExtension: target.extensions) {
                actions.append(.eachFile(id: target.id, title: target.title, symbol: target.symbol) {
                    try await FileActions.textutil($0, to: target.format)
                }.producing(UTType(filenameExtension: target.format) ?? .text))
            }
            return actions

        case .presentation:
            return [.eachFile(id: "slides-pdf", title: "PDF", symbol: "doc.richtext") { try await DocumentEngines.toPDF($0) }
                .producing(.pdf)]
                + combined(files, id: "slides-pdf", title: "PDF", output: .pdf) { [try await DocumentEngines.toSinglePDF($0)] }
                + [
                    .eachFile(id: "slides-png", title: "PNG", symbol: "photo.on.rectangle") {
                        try await DocumentEngines.toImages($0, type: .png)
                    }.producing(.png),
                    .eachFile(id: "slides-jpeg", title: "JPEG", symbol: "photo.stack") {
                        try await DocumentEngines.toImages($0, type: .jpeg)
                    }.producing(.jpeg),
                ]

        case .folder, .other:
            return []
        }
    }

    /// With several files, the "all in one file" twin of a per-file action ("PDF" → "PDF unido").
    private static func combined(
        _ files: [URL],
        id: String,
        title: String,
        output: UTType,
        _ perform: @escaping @Sendable ([URL]) async throws -> [URL]
    ) -> [WheelAction] {
        guard files.count > 1 else { return [] }
        let action = WheelAction(id: "\(id)-combined", title: String(localized: "\(title) unido", comment: "Bubble: several files into one, e.g. \"PDF merged\""), symbol: "square.stack", perform: perform)
        return [action.producing(output, combined: true)]
    }

    /// Word's format, so its bubble shows the Word document icon (or Pages', whichever opens .docx here).
    private static let docx = UTType(filenameExtension: "docx") ?? .data

    /// Converting to the format the files already have only makes a copy: don't offer it.
    private static func all(_ files: [URL], haveExtension extensions: Set<String>) -> Bool {
        files.allSatisfy { extensions.contains($0.pathExtension.lowercased()) }
    }

    // MARK: - Tools (⌥)

    private static func tools(_ kind: FileKind, _ files: [URL]) -> [WheelAction] {
        switch kind {
        case .image:
            return [
                .eachFile(id: "image-compress", title: String(localized: "Comprimir"), symbol: "arrow.down.right.and.arrow.up.left") {
                    try ImageConverter.convert($0, to: .jpeg, quality: 0.7, suffix: String(localized: "comprimido", comment: "File name suffix for a compressed image"))
                },
                .eachFile(id: "image-half", title: String(localized: "Reducir 50%"), symbol: "minus.magnifyingglass") { file in
                    // Keep the format when macOS can write it (RAW files can't be written: use JPEG).
                    let original = UTType(filenameExtension: file.pathExtension.lowercased())
                    let type = original.flatMap { ImageConverter.canWrite($0) ? $0 : nil } ?? .jpeg
                    return try ImageConverter.convert(file, to: type, quality: 0.9, scale: 0.5, suffix: "50%")
                },
            ]

        case .pdf:
            var actions: [WheelAction] = [
                .eachFile(id: "pdf-split", title: String(localized: "Dividir"), symbol: "rectangle.split.3x1") { try PDFTools.split($0) },
                .eachFile(id: "pdf-rotate", title: String(localized: "Rotar 90°"), symbol: "rotate.right") { try PDFTools.rotate($0) },
            ]
            if files.count > 1 {
                actions.insert(WheelAction(id: "pdf-merge", title: String(localized: "Unir"), symbol: "doc.on.doc") { files in
                    [try PDFTools.merge(files)]
                }, at: 0)
            }
            return actions

        case .video:
            return [
                .eachFile(id: "video-720", title: String(localized: "Comprimir 720p"), symbol: "arrow.down.right.and.arrow.up.left") {
                    try await MediaConverter.export($0, preset: AVAssetExportPreset1280x720, as: .mp4, extension: "mp4", suffix: "720p")
                },
            ]

        case .audio, .document, .presentation, .folder, .other:
            return []
        }
    }

    // MARK: - Actions (⌃) — any file

    private static func general(_ files: [URL]) -> [WheelAction] {
        var actions = [
            WheelAction(id: "action-airdrop", title: "AirDrop", symbol: "dot.radiowaves.left.and.right") { files in
                await FileActions.airDrop(files)
                return []
            },
            WheelAction(id: "action-zip", title: "ZIP", symbol: "doc.zipper") { files in
                [try await FileActions.zip(files)]
            }.producing(.zip, combined: files.count > 1),
        ]
        // "ZIP" already makes one archive with everything; with several files also offer one each.
        if files.count > 1 {
            actions.append(.eachFile(id: "action-zip-each", title: String(localized: "ZIP c/u"), symbol: "doc.zipper") { try await FileActions.zip([$0]) }.producing(.zip))
        }
        actions += [
            WheelAction(id: "action-copy-path", title: String(localized: "Copiar ruta"), symbol: "link") { files in
                await FileActions.copyPaths(files)
                return []
            },
            WheelAction(id: "action-reveal", title: String(localized: "Mostrar en Finder"), symbol: "folder") { files in
                await FileActions.revealInFinder(files)
                return []
            },
        ]
        return actions
    }
}
