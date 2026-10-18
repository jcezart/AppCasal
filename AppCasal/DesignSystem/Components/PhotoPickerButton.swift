//
//  PhotoPickerButton.swift
//  AppCasal
//

import PhotosUI
import SwiftUI

/// Picks a single photo from the library and hands back a processed (downscaled) copy.
struct PhotoPickerButton<Label: View>: View {
    let onPicked: (ProcessedPhoto) -> Void
    var onFailure: ((String) -> Void)?
    @ViewBuilder let label: Label

    @State private var item: PhotosPickerItem?
    @State private var isPresented = false
    @State private var isProcessing = false

    var body: some View {
        // A plain button plus the picker modifier keeps the label on the main actor.
        Button { isPresented = true } label: {
            label
                .overlay {
                    if isProcessing {
                        ProgressView()
                    }
                }
        }
        .photosPicker(isPresented: $isPresented, selection: $item, matching: .images)
        .disabled(isProcessing)
        .onChange(of: item) {
            guard let item else { return }
            self.item = nil
            isProcessing = true
            Task {
                defer { isProcessing = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoProcessing.ProcessingError.unreadableImage
                    }
                    onPicked(try await PhotoProcessing.process(data))
                } catch {
                    onFailure?(error.localizedDescription)
                }
            }
        }
    }
}

/// Decodes image data off the main actor and keeps the result while the data is unchanged.
struct DecodedImage<Placeholder: View>: View {
    let data: Data?
    @ViewBuilder let placeholder: Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: data) {
            guard let data else {
                image = nil
                return
            }
            image = await ImageDecoder.decode(data)
        }
    }
}

/// Decodes image data for display off the main actor.
nonisolated enum ImageDecoder {
    @concurrent
    static func decode(_ data: Data) async -> UIImage? {
        await UIImage(data: data)?.byPreparingForDisplay()
    }
}
