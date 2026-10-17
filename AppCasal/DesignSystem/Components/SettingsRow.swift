//
//  SettingsRow.swift
//  AppCasal
//

import SwiftUI

/// Row used in the "Nosso espaço" list.
struct SettingsRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    var subtitle: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Palette.accentText)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.s)
        .contentShape(.rect)
    }
}
