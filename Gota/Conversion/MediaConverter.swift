import AVFoundation
import Foundation

/// Video and audio with AVFoundation and `afconvert` (both built into macOS, hardware accelerated).
enum MediaConverter {
    /// Re-encodes a video (or extracts its audio) with an AVFoundation export preset.
    static func export(_ input: URL, preset: String, as fileType: AVFileType, extension ext: String, suffix: String? = nil) async throws -> URL {
        let asset = AVURLAsset(url: input)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw ConversionError.unsupported(input.pathExtension.uppercased())
        }
        let output = Output.file(for: input, extension: ext, suffix: suffix)
        do {
            try await session.export(to: output, as: fileType)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return output
    }

    /// Audio formats with Apple's `afconvert`.
    /// - Parameters:
    ///   - format: file format, e.g. "m4af", "WAVE", "AIFF".
    ///   - data: data format, e.g. "aac", "LEI16", "BEI16".
    static func audio(_ input: URL, format: String, data: String, extension ext: String) async throws -> URL {
        let output = Output.file(for: input, extension: ext)
        try await Shell.run("/usr/bin/afconvert", ["-f", format, "-d", data, input.path, output.path])
        try Output.requireCreated(output, by: "afconvert", from: input)
        return output
    }
}
