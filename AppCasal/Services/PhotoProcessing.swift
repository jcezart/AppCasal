//
//  PhotoProcessing.swift
//  AppCasal
//

import Foundation
import CoreImage
import ImageIO
import UIKit
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

    /// Downscaled, upright image for the crop screen. Same pixels `process(_:cropping:)`
    /// crops, so a rectangle normalized on it maps exactly.
    @concurrent
    static func preview(_ data: Data) async throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ProcessingError.unreadableImage
        }
        return UIImage(cgImage: try downscaled(source, maxPixelSize: maxPixelSize))
    }

    /// Keeps only `normalizedRect` (relative to the upright image), then processes as usual.
    /// A rectangle reaching beyond the image (photo zoomed out in the crop screen) is
    /// filled around the photo with a blurred, enlarged copy of it.
    @concurrent
    static func process(_ data: Data, cropping normalizedRect: CGRect) async throws -> ProcessedPhoto {
        try processSynchronously(data, cropping: normalizedRect)
    }

    static func processSynchronously(_ data: Data, cropping normalizedRect: CGRect) throws -> ProcessedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ProcessingError.unreadableImage
        }
        let full = try downscaled(source, maxPixelSize: maxPixelSize)
        let bounds = CGRect(x: 0, y: 0, width: full.width, height: full.height)
        let requested = CGRect(
            x: normalizedRect.minX * bounds.width,
            y: normalizedRect.minY * bounds.height,
            width: normalizedRect.width * bounds.width,
            height: normalizedRect.height * bounds.height
        ).integral
        guard !requested.isEmpty, requested.intersects(bounds) else {
            throw ProcessingError.unreadableImage
        }
        let cropped: CGImage
        if bounds.contains(requested) {
            guard let image = full.cropping(to: requested) else { throw ProcessingError.unreadableImage }
            cropped = image
        } else {
            cropped = try padded(full, in: requested)
        }
        return ProcessedPhoto(
            imageData: try encode(cropped, quality: 0.8),
            thumbnailData: try encode(try resized(cropped, maxPixelSize: thumbnailPixelSize), quality: 0.7),
            pixelWidth: cropped.width,
            pixelHeight: cropped.height
        )
    }

    /// Draws `image` where it sits inside `rect` (pixel coordinates of the image, top-left
    /// origin, partly outside it) over a blurred copy that fills the whole rectangle.
    private static func padded(_ image: CGImage, in rect: CGRect) throws -> CGImage {
        let scale = min(Double(maxPixelSize) / Double(max(rect.width, rect.height)), 1)
        let width = max(Int((rect.width * scale).rounded()), 1)
        let height = max(Int((rect.height * scale).rounded()), 1)
        let output = CGRect(x: 0, y: 0, width: width, height: height)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw ProcessingError.encodingFailed }
        context.interpolationQuality = .high

        // Background: the photo enlarged to cover everything, then blurred.
        let source = CIImage(cgImage: image)
        let cover = max(Double(width) / Double(image.width), Double(height) / Double(image.height))
        let enlarged = source.transformed(by: CGAffineTransform(scaleX: cover, y: cover))
        let centered = enlarged.transformed(by: CGAffineTransform(
            translationX: (Double(width) - enlarged.extent.width) / 2,
            y: (Double(height) - enlarged.extent.height) / 2
        ))
        let blurred = centered.clampedToExtent().applyingGaussianBlur(sigma: Double(max(width, height)) / 30).cropped(to: output)
        if let background = CIContext(options: [.cacheIntermediates: false]).createCGImage(blurred, from: output) {
            context.draw(background, in: output)
        }

        // The photo itself, at its place. Core Graphics draws from the bottom-left corner.
        let photoWidth = Double(image.width) * scale
        let photoHeight = Double(image.height) * scale
        let left = -rect.minX * scale
        let top = -rect.minY * scale
        context.draw(image, in: CGRect(x: left, y: Double(height) - top - photoHeight, width: photoWidth, height: photoHeight))
        guard let result = context.makeImage() else { throw ProcessingError.encodingFailed }
        return result
    }

    /// Redraws an already decoded image so its longest side is at most `maxPixelSize`.
    private static func resized(_ image: CGImage, maxPixelSize: Int) throws -> CGImage {
        let scale = min(Double(maxPixelSize) / Double(max(image.width, image.height)), 1)
        let width = max(Int((Double(image.width) * scale).rounded()), 1)
        let height = max(Int((Double(image.height) * scale).rounded()), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw ProcessingError.encodingFailed }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let output = context.makeImage() else { throw ProcessingError.encodingFailed }
        return output
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
