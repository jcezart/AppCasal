//
//  Chips.swift
//  AppCasal
//

import SwiftUI

/// Category chip ("Praia", "Viagem").
struct TagChip: View {
    let title: String
    var systemImage: String?

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.chipLabel)
        .foregroundStyle(Palette.accentText)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xxs + 2)
        .background(Palette.surfaceMuted, in: .capsule)
    }
}

/// State chip ("Queremos ir", "Conectado").
struct StatusChip: View {
    enum Tone {
        case accent
        case success
        case neutral
    }

    let title: LocalizedStringKey
    let systemImage: String
    var tone: Tone = .accent

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.chipLabel)
            .foregroundStyle(foreground)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs + 2)
            .background(Palette.surfaceMuted, in: .capsule)
    }

    private var foreground: Color {
        switch tone {
        case .accent: Palette.accentText
        case .success: Palette.success
        case .neutral: Palette.textSecondary
        }
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        TagChip(title: "Praia")
        TagChip(title: "Viagem", systemImage: "airplane")
        StatusChip(title: "Queremos ir", systemImage: "bookmark.fill")
        StatusChip(title: "Conectado", systemImage: "circle.fill", tone: .success)
    }
    .padding()
    .background(Palette.canvas)
}
