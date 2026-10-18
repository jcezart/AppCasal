//
//  OnboardingViews.swift
//  AppCasal
//

import SwiftUI

/// Shared layout for the onboarding screens: serif title, message, content.
private struct OnboardingScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Image(systemName: "heart")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(title)
                        .font(.displayTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                content
            }
            .padding(Spacing.screen)
            .padding(.top, Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .canvasBackground()
    }
}

/// Name field styled as a stable surface.
private struct NameField: View {
    @Binding var name: String

    var body: some View {
        TextField("Seu nome", text: $name)
            .textContentType(.givenName)
            .submitLabel(.done)
            .font(.body)
            .padding(Spacing.m)
            .background(Palette.surface, in: .rect(cornerRadius: Radius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Palette.hairline)
            }
    }
}

struct CreateSpaceView: View {
    let environment: AppEnvironment
    let userRecordName: String
    let onCreated: () -> Void

    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        OnboardingScaffold(
            title: "Um espaço só nosso",
            message: "Para guardar o que vivemos, o que sonhamos e tudo o que ainda vamos viver juntos."
        ) {
            NameField(name: $name)
            Button("Criar nosso espaço", action: create)
                .buttonStyle(.primary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }
            acceptanceStatus
            Text("Recebeu um convite? Abra o link que seu par enviou e o espaço de vocês aparece aqui.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder
    private var acceptanceStatus: some View {
        switch environment.sharing.acceptance {
        case .idle:
            EmptyView()
        case .accepting:
            LoadingStateView(message: "Aceitando o convite…")
                .frame(height: 80)
        case .accepted:
            LoadingStateView(message: "Convite aceito. Trazendo o espaço de vocês do iCloud…")
                .frame(height: 80)
        case .rejected(let reason), .failed(let reason):
            ErrorBanner(message: reason)
        }
    }

    private func create() {
        do {
            _ = try environment.spaces.createSpace(
                ownerName: name.trimmingCharacters(in: .whitespaces),
                userRecordName: userRecordName
            )
            onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Shown after the invitation is accepted while the shared space comes from iCloud.
/// No form here, so the participant cannot create a separate space by mistake.
struct AcceptingInvitationView: View {
    var body: some View {
        OnboardingScaffold(
            title: "Convite aceito",
            message: "Estamos trazendo o espaço de vocês do iCloud. Isso pode levar alguns segundos."
        ) {
            LoadingStateView(message: "Preparando o espaço de vocês…")
                .frame(height: 80)
        }
    }
}

/// Shown to the participant after accepting, before their member record exists.
struct JoinSpaceView: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let onJoined: () -> Void

    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        OnboardingScaffold(
            title: "Que bom ter você aqui",
            message: "Como você quer aparecer para o seu par?"
        ) {
            NameField(name: $name)
            Button("Entrar no espaço") {
                do {
                    try environment.spaces.ensureMember(
                        named: name.trimmingCharacters(in: .whitespaces),
                        userRecordName: userRecordName,
                        in: space
                    )
                    onJoined()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.primary)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
    }
}

struct AccountUnavailableView: View {
    let status: AccountService.Status
    let retry: () -> Void

    var body: some View {
        VStack {
            Spacer()
            EmptyStateView(
                systemImage: "icloud.slash",
                title: "Precisamos do iCloud",
                message: message,
                actionTitle: "Tentar novamente",
                action: retry
            )
            Spacer()
        }
        .padding(Spacing.screen)
    }

    private var message: LocalizedStringKey {
        switch status {
        case .noAccount:
            "Entre na sua conta iCloud nos Ajustes do iPhone para criar ou abrir o espaço de vocês."
        case .restricted:
            "O uso do iCloud está restrito neste iPhone."
        case .temporarilyUnavailable:
            "O iCloud está temporariamente indisponível. Tente de novo em instantes."
        case .failed(let reason):
            "Não foi possível verificar sua conta iCloud. \(reason)"
        case .checking, .available, .couldNotDetermine:
            "Não foi possível verificar sua conta iCloud."
        }
    }
}

#if DEBUG
#Preview("Criar espaço") {
    CreateSpaceView(environment: AppEnvironment(runMode: .preview), userRecordName: DemoData.ownerID, onCreated: {})
}

#Preview("Sem iCloud") {
    AccountUnavailableView(status: .noAccount, retry: {})
        .background(Palette.canvas)
}
#endif
