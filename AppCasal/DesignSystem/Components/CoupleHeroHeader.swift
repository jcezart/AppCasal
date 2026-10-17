//
//  CoupleHeroHeader.swift
//  AppCasal
//

import SwiftUI
import UIKit

/// Top of Início: couple names, days together and the couple photo fading into the canvas.
/// Without a photo, a warm gradient keeps the atmosphere.
struct CoupleHeroHeader: View {
    let title: String
    let daysTogether: Int?
    var photoData: Data?
    /// Height of the bars above the header. The header draws under them, as in the
    /// reference, and pushes its text below them.
    var topInset: CGFloat = 0

    /// Fixed on purpose: the title grows with Dynamic Type, the photo area does not.
    private let height: CGFloat = 300

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.displayTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let daysTogether {
                    HStack(spacing: Spacing.xxs) {
                        Text("\(daysTogether) dias juntos")
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Palette.accent)
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, topInset + Spacing.s)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, minHeight: height + topInset, alignment: .top)
    }

    @ViewBuilder
    private var background: some View {
        if let photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: height + topInset)
                .clipped()
                .overlay(fade)
                .accessibilityLabel(Text("Foto do casal"))
        } else {
            LinearGradient(
                colors: [Palette.surfaceMuted, Palette.accent.opacity(0.25), Palette.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "heart")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(Palette.accent.opacity(0.18))
                    .padding(Spacing.xl)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Keeps the title legible over the photo and blends into the canvas below.
    private var fade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.canvas.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
            Spacer()
            LinearGradient(colors: [.clear, Palette.canvas], startPoint: .top, endPoint: .bottom)
                .frame(height: 80)
        }
    }
}

#Preview {
    ScrollView {
        CoupleHeroHeader(title: "Ana e Lucas", daysTogether: 842)
    }
    .background(Palette.canvas)
}
