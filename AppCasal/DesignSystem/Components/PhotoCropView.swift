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

/// Positions the photo in the crop frame like Instagram or WhatsApp: drag in any
/// direction, pinch to zoom in or out around the fingers, double tap to zoom. Zooming
/// out down to the whole photo is allowed; the rest of the square is filled with a
/// blurred copy of the photo when saved. Past the limits the photo stretches a little
/// and springs back. Hands back the visible square as a rectangle normalized to the
/// image (it may extend beyond 0…1 when zoomed out).
struct PhotoCropView: View {
    let image: UIImage
    let shape: PhotoCropShape
    let onCrop: (CGRect) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 1 = the photo just covers the frame.
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var pinchStart: PinchStart?
    @State private var side: CGFloat = 1

    private struct PinchStart {
        let zoom: CGFloat
        let offset: CGSize
        /// Fingers' starting point, relative to the center of the frame.
        let anchor: CGSize
    }

    private static let maximumZoom: CGFloat = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                GeometryReader { geometry in
                    let side = min(geometry.size.width - Spacing.screen * 2, geometry.size.height)
                    cropArea(side: side, size: geometry.size)
                        .onAppear { self.side = side }
                        .onChange(of: side) { self.side = side }
                }
                Text("Arraste para posicionar. Use dois dedos para aproximar ou afastar; toque duas vezes para ampliar.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screen)
                Button("Mostrar a foto inteira") {
                    animate {
                        zoom = minimumZoom(side: side)
                        offset = .zero
                    }
                }
                .buttonStyle(.text)
                .accessibilityIdentifier("photoCrop.fit")
            }
            .padding(.vertical, Spacing.l)
            .canvasBackground()
            .tint(Palette.accentText)
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
                    .confirmationButtonStyle()
                    .accessibilityIdentifier("photoCrop.use")
                }
            }
        }
    }

    private func cropArea(side: CGFloat, size: CGSize) -> some View {
        let fill = fillSize(side: side)
        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: fill.width, height: fill.height)
                .scaleEffect(zoom)
                .offset(offset)
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
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(.rect)
        .gesture(dragGesture(side: side).simultaneously(with: pinchGesture(side: side, size: size)))
        .onTapGesture(count: 2) { location in
            doubleTap(at: location, side: side, size: size)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Foto"))
        .accessibilityHint(Text("Deslize para cima ou para baixo para aproximar ou afastar."))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: zoom = clampedZoom(zoom + 0.25, side: side)
            case .decrement: zoom = clampedZoom(zoom - 0.25, side: side)
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

    // MARK: Gestures

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // While pinching, the pinch moves the photo around the fingers.
                guard pinchStart == nil else { return }
                let start = dragStart ?? offset
                dragStart = start
                offset = rubberBanded(start + value.translation, zoom: zoom, side: side)
            }
            .onEnded { _ in
                dragStart = nil
                settle(side: side)
            }
    }

    private func pinchGesture(side: CGFloat, size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? PinchStart(
                    zoom: zoom,
                    offset: offset,
                    anchor: CGSize(width: value.startLocation.x - size.width / 2, height: value.startLocation.y - size.height / 2)
                )
                pinchStart = start
                let newZoom = rubberBandedZoom(start.zoom * value.magnification, side: side)
                // The point under the fingers stays under the fingers while zooming.
                offset = scaled(start.offset, around: start.anchor, by: newZoom / start.zoom)
                zoom = newZoom
            }
            .onEnded { _ in
                pinchStart = nil
                dragStart = nil
                settle(side: side)
            }
    }

    private func doubleTap(at location: CGPoint, side: CGFloat, size: CGSize) {
        let anchor = CGSize(width: location.x - size.width / 2, height: location.y - size.height / 2)
        animate {
            if zoom > 1.01 {
                zoom = 1
                offset = clamped(offset, zoom: 1, side: side)
            } else {
                let target: CGFloat = 2.5
                offset = clamped(scaled(offset, around: anchor, by: target / zoom), zoom: target, side: side)
                zoom = target
            }
        }
    }

    private func scaled(_ offset: CGSize, around anchor: CGSize, by ratio: CGFloat) -> CGSize {
        CGSize(
            width: anchor.width + (offset.width - anchor.width) * ratio,
            height: anchor.height + (offset.height - anchor.height) * ratio
        )
    }

    /// Springs back inside the limits after a gesture.
    private func settle(side: CGFloat) {
        animate {
            zoom = clampedZoom(zoom, side: side)
            offset = clamped(offset, zoom: zoom, side: side)
        }
    }

    private func animate(_ change: () -> Void) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0), change)
    }

    // MARK: Geometry

    /// Image size at zoom 1: just covers the frame.
    private func fillSize(side: CGFloat) -> CGSize {
        let width = max(image.size.width, 1)
        let height = max(image.size.height, 1)
        let scale = max(side / width, side / height)
        return CGSize(width: width * scale, height: height * scale)
    }

    /// The whole photo fits in the frame.
    private func minimumZoom(side: CGFloat) -> CGFloat {
        let fill = fillSize(side: side)
        return min(fill.width, fill.height) / max(fill.width, fill.height)
    }

    private func clampedZoom(_ value: CGFloat, side: CGFloat) -> CGFloat {
        min(max(value, minimumZoom(side: side)), Self.maximumZoom)
    }

    /// Beyond the limits the zoom keeps following the fingers, with resistance.
    private func rubberBandedZoom(_ value: CGFloat, side: CGFloat) -> CGFloat {
        let low = minimumZoom(side: side)
        if value < low { return low - (low - value) * 0.35 }
        if value > Self.maximumZoom { return Self.maximumZoom + (value - Self.maximumZoom) * 0.35 }
        return value
    }

    /// How far the photo may move from the center on each axis. When the photo is
    /// smaller than the frame on an axis (zoomed out), it stays centered on that axis.
    private func limits(zoom: CGFloat, side: CGFloat) -> CGSize {
        let fill = fillSize(side: side)
        return CGSize(width: max((fill.width * zoom - side) / 2, 0), height: max((fill.height * zoom - side) / 2, 0))
    }

    private func clamped(_ offset: CGSize, zoom: CGFloat, side: CGFloat) -> CGSize {
        let limit = limits(zoom: zoom, side: side)
        return CGSize(width: min(max(offset.width, -limit.width), limit.width), height: min(max(offset.height, -limit.height), limit.height))
    }

    private func rubberBanded(_ offset: CGSize, zoom: CGFloat, side: CGFloat) -> CGSize {
        let limit = limits(zoom: zoom, side: side)
        func band(_ value: CGFloat, _ limit: CGFloat) -> CGFloat {
            let excess = abs(value) - limit
            guard excess > 0 else { return value }
            // Resistance grows with distance, like scroll views at their edges.
            let resisted = excess * side * 0.55 / (side + 0.55 * excess)
            return (limit + resisted) * (value < 0 ? -1 : 1)
        }
        return CGSize(width: band(offset.width, limit.width), height: band(offset.height, limit.height))
    }

    private func normalizedCrop(side: CGFloat) -> CGRect {
        let fill = fillSize(side: side)
        let zoom = clampedZoom(zoom, side: side)
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
