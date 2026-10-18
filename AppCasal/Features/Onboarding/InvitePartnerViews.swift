//
//  InvitePartnerViews.swift
//  AppCasal
//

import SwiftUI

/// Whether the owner should be nudged to invite: a real space, still without partner.
enum InvitePartner {
    static func isPending(_ environment: AppEnvironment, space: CoupleSpace, userRecordName: String) -> Bool {
        !environment.isDemo
            && space.sharingEndedAt == nil
            && environment.spaces.role(in: space) == .owner
            && environment.spaces.partner(of: userRecordName, in: space) == nil
    }

    static let whatsAppHint: LocalizedStringKey = "No WhatsApp, toque em Continuar: só quem abrir o link primeiro entra."
}

/// Offered right after "Criar nosso espaço". Saves the share here, with progress, so
/// the share sheet opens at once after this sheet closes (`onInvite`).
struct InvitePartnerPromptView: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    let onInvite: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPreparing = false
    @State private var errorMessage: String?

    var body: some View {
        PromptScaffold(
            systemImage: "person.2",
            title: "Convide seu par",
            message: "O espaço fica completo com vocês dois. Envie o convite pelo WhatsApp, por Mensagens ou como preferir.",
            note: InvitePartner.whatsAppHint
        ) {
            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }
            Button(action: prepare) {
                if isPreparing {
                    ProgressView()
                        .tint(Palette.onAccent)
                        .accessibilityLabel(Text("Preparando convite"))
                } else {
                    Text("Convidar seu par")
                }
            }
            .buttonStyle(.primary)
            .disabled(isPreparing)
            .accessibilityIdentifier("invitePrompt.invite")
            Button("Agora não") { dismiss() }
                .buttonStyle(.text)
                .disabled(isPreparing)
                .accessibilityHint(Text("Você pode convidar depois, pelo Início ou em Nosso espaço."))
                .accessibilityIdentifier("invitePrompt.later")
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isPreparing)
    }

    private func prepare() {
        isPreparing = true
        errorMessage = nil
        Task {
            defer { isPreparing = false }
            do {
                _ = try await environment.sharing.ensureShare(for: space)
                onInvite()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Início, while the partner has not joined: a clear way to send the invitation.
struct InvitePartnerCard: View {
    let environment: AppEnvironment
    let space: CoupleSpace

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            AdaptiveStack {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(Palette.accentText)
                    .frame(width: 36, height: 36)
                    .background(Palette.surfaceMuted, in: .rect(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Seu par ainda não está aqui")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(InvitePartner.whatsAppHint)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }
            Button(action: invite) {
                Group {
                    if isWorking {
                        ProgressView()
                            .accessibilityLabel(Text("Preparando convite"))
                    } else {
                        Label("Convidar seu par", systemImage: "paperplane")
                    }
                }
                // Full width inside the card, like the other card actions.
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.soft)
            .disabled(isWorking)
            .accessibilityIdentifier("home.invitePartner")
        }
        .surfaceCard()
    }

    private func invite() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await environment.sharing.presentInvitation(for: space)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
