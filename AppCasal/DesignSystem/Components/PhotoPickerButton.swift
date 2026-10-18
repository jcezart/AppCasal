//
//  PhotoPickerButton.swift
//  AppCasal
//

import PhotosUI
import SwiftUI

/// Picks a single photo from the library and hands back a processed (downscaled) copy.
/// With `crop`, the person first positions the photo in that frame.
struct PhotoPickerButton<Label: View>: View {
    let onPicked: (ProcessedPhoto) -> Void
    var onFailure: ((String) -> Void)?
    var crop: PhotoCropShape?
    @ViewBuilder let label: Label

    @State private var item: PhotosPickerItem?
    @State private var isPresented = false
    @State private var isProcessing = false
    @State private var pendingCrop: PendingCrop?

    private struct PendingCrop: Identifiable {
        let id = UUID()
        let data: Data
        let preview: UIImage
        let shape: PhotoCropShape
    }

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
                    if let crop {
                        pendingCrop = PendingCrop(data: data, preview: try await PhotoProcessing.preview(data), shape: crop)
                    } else {
                        onPicked(try await PhotoProcessing.process(data))
                    }
                } catch {
                    onFailure?(error.localizedDescription)
                }
            }
        }
        .fullScreenCover(item: $pendingCrop) { pending in
            PhotoCropView(image: pending.preview, shape: pending.shape) { rect in
                finishCrop(pending.data, rect)
            }
        }
    }

    private func finishCrop(_ data: Data, _ rect: CGRect) {
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                onPicked(try await PhotoProcessing.process(data, cropping: rect))
            } catch {
                onFailure?(error.localizedDescription)
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
