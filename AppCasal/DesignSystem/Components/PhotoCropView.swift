//
//  PhotoCropView.swift
//  AppCasal
//

import SwiftUI

/// Frame a picked photo is cropped to. Both are square: the profile photo shows in a
/// circle; the couple photo fills the Início header and the invitation thumbnail.
enum PhotoCropShape {
    case circle
    case square

    var title: LocalizedStringKey {
        switch self {
        case .circle: "Ajustar foto de perfil"
        case .square: "Ajustar foto do casal"
        }
    }
}

/// Lets the person drag and pinch the photo inside the crop frame before saving.
/// Hands back the visible part as a rectangle normalized to the image (0…1).
struct PhotoCropView: View {
    let image: UIImage
    let shape: PhotoCropShape
    let onCrop: (CGRect) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var pinch: CGFloat = 1
    @State private var drag: CGSize = .zero
    @State private var side: CGFloat = 1

    private static let maximumZoom: CGFloat = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.l) {
                GeometryReader { geometry in
                    let side = min(geometry.size.width - Spacing.screen * 2, geometry.size.height)
                    cropArea(side: side)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onAppear { self.side = side }
                        .onChange(of: side) { self.side = side }
                }
                Text("Arraste para posicionar e use dois dedos para aproximar.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screen)
            }
            .padding(.vertical, Spacing.l)
            .canvasBackground()
            .navigationTitle(shape.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Usar foto", systemImage: "checkmark", role: .confirm) {
                        onCrop(normalizedCrop(side: side))
                        dismiss()
                    }
                    .accessibilityIdentifier("photoCrop.use")
                }
            }
        }
    }

    private func cropArea(side: CGFloat) -> some View {
        let fill = fillSize(side: side)
        let currentZoom = clampedZoom(zoom * pinch)
        let currentOffset = clamped(offset + drag, zoom: currentZoom, side: side)
        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: fill.width, height: fill.height)
                .scaleEffect(currentZoom)
                .offset(currentOffset)
            // Outside the frame stays visible but dimmed, so the person sees what is cut.
            Rectangle()
                .fill(.black.opacity(0.55))
                .overlay {
                    frameShape
                        .frame(width: side, height: side)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .allowsHitTesting(false)
            frameShape
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: side, height: side)
                .allowsHitTesting(false)
        }
        .clipped()
        .contentShape(.rect)
        .gesture(dragGesture(side: side).simultaneously(with: pinchGesture(side: side)))
        .accessibilityElement()
        .accessibilityLabel(Text("Foto"))
        .accessibilityHint(Text("Deslize para cima ou para baixo para aproximar ou afastar."))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: zoom = clampedZoom(zoom + 0.25)
            case .decrement: zoom = clampedZoom(zoom - 0.25)
            @unknown default: break
            }
            offset = clamped(offset, zoom: zoom, side: side)
        }
    }

    private var frameShape: some Shape {
        switch shape {
        case .circle: AnyShape(Circle())
        case .square: AnyShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                offset = clamped(offset + value.translation, zoom: zoom, side: side)
                drag = .zero
            }
    }

    private func pinchGesture(side: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { pinch = $0.magnification }
            .onEnded { value in
                zoom = clampedZoom(zoom * value.magnification)
                pinch = 1
                withAnimation(.spring(duration: 0.3)) {
                    offset = clamped(offset, zoom: zoom, side: side)
                }
            }
    }

    /// Image size at zoom 1: just covers the frame.
    private func fillSize(side: CGFloat) -> CGSize {
        let width = max(image.size.width, 1)
        let height = max(image.size.height, 1)
        let scale = max(side / width, side / height)
        return CGSize(width: width * scale, height: height * scale)
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), Self.maximumZoom)
    }

    /// Keeps the image covering the whole frame.
    private func clamped(_ offset: CGSize, zoom: CGFloat, side: CGFloat) -> CGSize {
        let fill = fillSize(side: side)
        let maxX = max((fill.width * zoom - side) / 2, 0)
        let maxY = max((fill.height * zoom - side) / 2, 0)
        return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
    }

    private func normalizedCrop(side: CGFloat) -> CGRect {
        let fill = fillSize(side: side)
        let width = fill.width * zoom
        let height = fill.height * zoom
        let visible = clamped(offset, zoom: zoom, side: side)
        return CGRect(
            x: ((width - side) / 2 - visible.width) / width,
            y: ((height - side) / 2 - visible.height) / height,
            width: side / width,
            height: side / height
        )
    }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

#Preview {
    PhotoCropView(image: UIImage(systemName: "photo") ?? UIImage(), shape: .circle) { _ in }
}
