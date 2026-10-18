//
//  PhotoProcessing.swift
//  AppCasal
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A photo ready to store: downscaled full image and a small thumbnail.
nonisolated struct ProcessedPhoto: Sendable, Equatable {
    let imageData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

/// Downscales and compresses photos off the main actor with ImageIO, which decodes
/// directly at the target size instead of loading the full original into memory.
nonisolated enum PhotoProcessing {
    enum ProcessingError: LocalizedError {
        case unreadableImage
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage: String(localized: "Não foi possível abrir esta foto.")
            case .encodingFailed: String(localized: "Não foi possível preparar esta foto.")
            }
        }
    }

    /// Longest side of stored photos. Keeps CloudKit assets and the owner's iCloud quota small.
    static let maxPixelSize = 2048
    static let thumbnailPixelSize = 600

    @concurrent
    static func process(_ data: Data) async throws -> ProcessedPhoto {
        try processSynchronously(data)
    }

    /// Same as `process(_:)` on the calling thread; for tests and demo data.
    static func processSynchronously(_ data: Data) throws -> ProcessedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ProcessingError.unreadableImage
        }
        let full = try downscaled(source, maxPixelSize: maxPixelSize)
        let thumbnail = try downscaled(source, maxPixelSize: thumbnailPixelSize)
        return ProcessedPhoto(
            imageData: try encode(full, quality: 0.8),
            thumbnailData: try encode(thumbnail, quality: 0.7),
            pixelWidth: full.width,
            pixelHeight: full.height
        )
    }

    private static func downscaled(_ source: CGImageSource, maxPixelSize: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // applies EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ProcessingError.unreadableImage
        }
        return image
    }

    /// HEIC: about half the size of JPEG at similar quality. Metadata (including
    /// location) is not copied.
    private static func encode(_ image: CGImage, quality: Double) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.heic.identifier as CFString, 1, nil) else {
            throw ProcessingError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ProcessingError.encodingFailed }
        return output as Data
    }
}
