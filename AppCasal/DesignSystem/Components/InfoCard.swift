//
//  InfoCard.swift
//  AppCasal
//

import SwiftUI

/// Compact card with an icon, a title and a message. Used for summaries and
/// small empty states inside other screens (Início).
struct InfoCard: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        AdaptiveStack {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accentText)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceMuted, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
