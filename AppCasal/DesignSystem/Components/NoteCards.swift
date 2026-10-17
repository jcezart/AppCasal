//
//  NoteCards.swift
//  AppCasal
//

import SwiftUI

/// A note ("recadinho") in the notes list: quote mark, serif text, author and date.
struct NoteCard: View {
    let text: String
    let authorName: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Image(systemName: "quote.opening")
                .font(.title3)
                .foregroundStyle(Palette.accentText)
                .accessibilityHidden(true)
            Text(text)
                .font(.noteQuote)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(authorName) · \(date, format: .relative(presentation: .named))")
                .font(.metadata)
                .foregroundStyle(Palette.textSecondary)
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}

/// Compact preview of the latest note, used on Início.
struct NotePreviewCard: View {
    let text: String
    let authorName: String
    let date: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdaptiveStack {
            Image(systemName: "envelope.open")
                .foregroundStyle(Palette.accentText)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceMuted, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Último recadinho")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                Text("“\(text)”")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                Text("\(authorName) · \(date, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: Spacing.m) {
        NoteCard(text: "Seu sorriso é minha parte favorita do dia.", authorName: "Lucas", date: .now)
        NotePreviewCard(text: "Seu sorriso é minha parte favorita do dia.", authorName: "Lucas", date: .now.addingTimeInterval(-3600))
    }
    .padding()
    .background(Palette.canvas)
}
