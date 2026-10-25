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
                }
            }
            actions.append(.eachFile(id: "image-pdf", title: "PDF", symbol: "doc.richtext") { try PDFTools.imagesToPDF([$0]) })
            actions += combined(files, id: "image-pdf", title: "PDF") { [try PDFTools.imagesToPDF($0)] }
            return actions

        case .pdf:
            return [.eachFile(id: "pdf-docx", title: "Word", symbol: "doc.text") { try PDFTools.toWord([$0]) }]
                + combined(files, id: "pdf-docx", title: "Word") { [try PDFTools.toWord($0)] }
                + [
                    .eachFile(id: "pdf-png", title: "PNG", symbol: "photo.on.rectangle") { try PDFTools.pagesToImages($0, type: .png) },
                    .eachFile(id: "pdf-jpeg", title: "JPEG", symbol: "photo.stack") { try PDFTools.pagesToImages($0, type: .jpeg) },
                    .eachFile(id: "pdf-text", title: "Texto", symbol: "text.alignleft") { try PDFTools.text([$0]) },
                ]
                + combined(files, id: "pdf-text", title: "Texto") { [try PDFTools.text($0)] }

        case .video:
            var actions: [WheelAction] = []
            if !all(files, haveExtension: ["mp4", "m4v"]) {
                actions.append(.eachFile(id: "video-mp4", title: "MP4", symbol: "film") {
                    try await MediaConverter.export($0, preset: AVAssetExportPresetHighestQuality, as: .mp4, extension: "mp4")
                })
            }
            if !all(files, haveExtension: ["mov"]) {
                actions.append(.eachFile(id: "video-mov", title: "MOV", symbol: "film.stack") {
                    try await MediaConverter.export($0, preset: AVAssetExportPresetHighestQuality, as: .mov, extension: "mov")
                })
            }
            actions.append(.eachFile(id: "video-m4a", title: "Solo audio", symbol: "waveform") {
                try await MediaConverter.export($0, preset: AVAssetExportPresetAppleM4A, as: .m4a, extension: "m4a")
            })
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
                }
            }

        case .document:
            var actions: [WheelAction] = [
                .eachFile(id: "doc-pdf", title: "PDF", symbol: "doc.richtext") { try await DocumentEngines.toPDF($0) },
            ]
            actions += combined(files, id: "doc-pdf", title: "PDF") { [try await DocumentEngines.toSinglePDF($0)] }
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
                })
            }
            return actions

        case .folder, .other:
            return []
        }
    }

    /// With several files, the "all in one file" twin of a per-file action ("PDF" → "PDF unido").
    private static func combined(
        _ files: [URL],
        id: String,
        title: String,
        _ perform: @escaping @Sendable ([URL]) async throws -> [URL]
    ) -> [WheelAction] {
        guard files.count > 1 else { return [] }
        return [WheelAction(id: "\(id)-combined", title: "\(title) unido", symbol: "square.stack", perform: perform)]
    }

    /// Converting to the format the files already have only makes a copy: don't offer it.
    private static func all(_ files: [URL], haveExtension extensions: Set<String>) -> Bool {
        files.allSatisfy { extensions.contains($0.pathExtension.lowercased()) }
    }

    // MARK: - Tools (⌥)

    private static func tools(_ kind: FileKind, _ files: [URL]) -> [WheelAction] {
        switch kind {
        case .image:
            return [
                .eachFile(id: "image-compress", title: "Comprimir", symbol: "arrow.down.right.and.arrow.up.left") {
                    try ImageConverter.convert($0, to: .jpeg, quality: 0.7, suffix: "comprimido")
                },
                .eachFile(id: "image-half", title: "Reducir 50%", symbol: "minus.magnifyingglass") { file in
                    // Keep the format when macOS can write it (RAW files can't be written: use JPEG).
                    let original = UTType(filenameExtension: file.pathExtension.lowercased())
                    let type = original.flatMap { ImageConverter.canWrite($0) ? $0 : nil } ?? .jpeg
                    return try ImageConverter.convert(file, to: type, quality: 0.9, scale: 0.5, suffix: "50%")
                },
            ]

        case .pdf:
            var actions: [WheelAction] = [
                .eachFile(id: "pdf-split", title: "Dividir", symbol: "rectangle.split.3x1") { try PDFTools.split($0) },
                .eachFile(id: "pdf-rotate", title: "Rotar 90°", symbol: "rotate.right") { try PDFTools.rotate($0) },
            ]
            if files.count > 1 {
                actions.insert(WheelAction(id: "pdf-merge", title: "Unir", symbol: "doc.on.doc") { files in
                    [try PDFTools.merge(files)]
                }, at: 0)
            }
            return actions

        case .video:
            return [
                .eachFile(id: "video-720", title: "Comprimir 720p", symbol: "arrow.down.right.and.arrow.up.left") {
                    try await MediaConverter.export($0, preset: AVAssetExportPreset1280x720, as: .mp4, extension: "mp4", suffix: "720p")
                },
            ]

        case .audio, .document, .folder, .other:
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
            },
        ]
        // "ZIP" already makes one archive with everything; with several files also offer one each.
        if files.count > 1 {
            actions.append(.eachFile(id: "action-zip-each", title: "ZIP c/u", symbol: "doc.zipper") { try await FileActions.zip([$0]) })
        }
        actions += [
            WheelAction(id: "action-copy-path", title: "Copiar ruta", symbol: "link") { files in
                await FileActions.copyPaths(files)
                return []
            },
            WheelAction(id: "action-reveal", title: "Mostrar en Finder", symbol: "folder") { files in
                await FileActions.revealInFinder(files)
                return []
            },
        ]
        return actions
    }
}
