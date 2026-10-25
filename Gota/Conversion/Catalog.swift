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
            actions.append(WheelAction(id: "image-pdf", title: "PDF", symbol: "doc.richtext") { files in
                [try PDFTools.imagesToPDF(files)]
            })
            return actions

        case .pdf:
            return [
                .eachFile(id: "pdf-png", title: "PNG", symbol: "photo.on.rectangle") { try PDFTools.pagesToImages($0, type: .png) },
                .eachFile(id: "pdf-jpeg", title: "JPEG", symbol: "photo.stack") { try PDFTools.pagesToImages($0, type: .jpeg) },
                .eachFile(id: "pdf-text", title: "Texto", symbol: "text.alignleft") { try PDFTools.text($0) },
            ]

        case .video:
            return [
                .eachFile(id: "video-mp4", title: "MP4", symbol: "film") {
                    try await MediaConverter.export($0, preset: AVAssetExportPresetHighestQuality, as: .mp4, extension: "mp4")
                },
                .eachFile(id: "video-mov", title: "MOV", symbol: "film.stack") {
                    try await MediaConverter.export($0, preset: AVAssetExportPresetHighestQuality, as: .mov, extension: "mov")
                },
                .eachFile(id: "video-m4a", title: "Solo audio", symbol: "waveform") {
                    try await MediaConverter.export($0, preset: AVAssetExportPresetAppleM4A, as: .m4a, extension: "m4a")
                },
            ]

        case .audio:
            return [
                .eachFile(id: "audio-m4a", title: "M4A", symbol: "waveform") {
                    try await MediaConverter.audio($0, format: "m4af", data: "aac", extension: "m4a")
                },
                .eachFile(id: "audio-wav", title: "WAV", symbol: "waveform.path") {
                    try await MediaConverter.audio($0, format: "WAVE", data: "LEI16", extension: "wav")
                },
                .eachFile(id: "audio-aiff", title: "AIFF", symbol: "waveform.path.ecg") {
                    try await MediaConverter.audio($0, format: "AIFF", data: "BEI16", extension: "aiff")
                },
            ]

        case .document:
            return [
                .eachFile(id: "doc-pdf", title: "PDF", symbol: "doc.richtext") { try await DocumentEngines.toPDF($0) },
                .eachFile(id: "doc-docx", title: "Word", symbol: "doc.text") { try await FileActions.textutil($0, to: "docx") },
                .eachFile(id: "doc-txt", title: "Texto", symbol: "text.alignleft") { try await FileActions.textutil($0, to: "txt") },
                .eachFile(id: "doc-html", title: "HTML", symbol: "chevron.left.forwardslash.chevron.right") {
                    try await FileActions.textutil($0, to: "html")
                },
            ]

        case .folder, .other:
            return []
        }
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
        [
            WheelAction(id: "action-airdrop", title: "AirDrop", symbol: "dot.radiowaves.left.and.right") { files in
                await FileActions.airDrop(files)
                return []
            },
            WheelAction(id: "action-zip", title: "ZIP", symbol: "doc.zipper") { files in
                [try await FileActions.zip(files)]
            },
            WheelAction(id: "action-copy-path", title: "Copiar ruta", symbol: "link") { files in
                await FileActions.copyPaths(files)
                return []
            },
            WheelAction(id: "action-reveal", title: "Mostrar en Finder", symbol: "folder") { files in
                await FileActions.revealInFinder(files)
                return []
            },
        ]
    }
}
