//
//  PhotoView.swift
//  AppCasal
//

import CoreData
import SwiftUI
import UIKit

/// Displays a stored memory photo. Decoding happens off the main actor and the
/// result is kept per photo, so scrolling does not decode images on every update.
struct PhotoView: View {
    let photo: MemoryPhoto
    var usesThumbnail = true

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Palette.surfaceMuted
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .task(id: photo.objectID) {
            let data = usesThumbnail ? (photo.thumbnailData ?? photo.imageData) : (photo.imageData ?? photo.thumbnailData)
            guard let data else { return }
            image = await ImageDecoder.decode(data)
        }
    }
}
