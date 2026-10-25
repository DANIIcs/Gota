import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Image conversions with ImageIO (built into macOS: HEIC, JPEG, PNG, TIFF, GIF, RAW…).
enum ImageConverter {
    /// - Parameters:
    ///   - quality: 0…1 for lossy formats (JPEG/HEIC). nil keeps ImageIO's default.
    ///   - scale: 1 keeps the size; 0.5 halves width and height.
    static func convert(_ input: URL, to type: UTType, quality: Double? = nil, scale: Double = 1, suffix: String? = nil) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil) else {
            throw ConversionError.unreadable(input)
        }
        let ext = type.preferredFilenameExtension ?? "img"
        let output = Output.file(for: input, extension: ext, suffix: suffix)
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.unsupported(ext.uppercased())
        }

        var properties: [CFString: Any] = [:]
        if let quality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }

        if scale == 1 {
            // Copies the picture with its metadata (orientation, color profile, EXIF).
            CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true, // apply EXIF orientation
                kCGImageSourceThumbnailMaxPixelSize: max(1, Int(Double(longestSide(of: source)) * scale)),
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw ConversionError.unreadable(input)
            }
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: output)
            throw ConversionError.unsupported(ext.uppercased())
        }
        return output
    }

    /// Whether ImageIO can write this format on this Mac.
    static func canWrite(_ type: UTType) -> Bool {
        let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return writable.contains(type.identifier)
    }

    private static func longestSide(of source: CGImageSource) -> Int {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        return max(width, height)
    }
}
