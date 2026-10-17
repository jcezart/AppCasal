//
//  SurfaceCard.swift
//  AppCasal
//

import SwiftUI

/// Stable, nearly flat card used for reading content. Never glass.
private struct SurfaceCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.05), radius: 12, y: 2)
    }
}

extension View {
    func surfaceCard(padding: CGFloat = Spacing.card) -> some View {
        modifier(SurfaceCardModifier(padding: padding))
    }

    /// Warm cream background behind scrolling screens.
    func canvasBackground() -> some View {
        background(Palette.canvas.ignoresSafeArea())
            .scrollContentBackground(.hidden)
    }
}

/// Small label above a group of content ("Última memória").
struct SectionLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.metadata)
            .foregroundStyle(Palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.m) {
        SectionLabel(title: "Última memória")
        Text("Conteúdo do cartão").surfaceCard()
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .background(Palette.canvas)
}
