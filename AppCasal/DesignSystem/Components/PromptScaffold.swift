//
//  PromptScaffold.swift
//  AppCasal
//

import SwiftUI

/// Layout of the prompt sheets ("Convide seu par", notifications), after Apple's
/// permission and onboarding sheets: icon, title and message centered at the top;
/// the primary action full width at the bottom, the alternative as text under it.
struct PromptScaffold<Actions: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var note: LocalizedStringKey?
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: Spacing.l) {
            ScrollView {
                VStack(spacing: Spacing.m) {
                    Image(systemName: systemImage)
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Palette.accent)
                        .padding(.bottom, Spacing.xs)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.displayTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                    if let note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.top, Spacing.xs)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: Spacing.xs) {
                actions
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.m)
        .canvasBackground()
    }
}

#Preview {
    PromptScaffold(
        systemImage: "person.2",
        title: "Convide seu par",
        message: "O espaço fica completo com vocês dois.",
        note: "No WhatsApp, toque em Continuar."
    ) {
        Button("Convidar seu par") {}
            .buttonStyle(.primary)
        Button("Agora não") {}
            .buttonStyle(.text)
    }
}
