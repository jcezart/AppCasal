//
//  States.swift
//  AppCasal
//

import SwiftUI

/// Empty state with an optional action.
struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 64

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(Palette.accentText)
                .frame(width: iconSize, height: iconSize)
                .background(Palette.surfaceMuted, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.soft)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

/// Full-area loading state.
struct LoadingStateView: View {
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.m) {
            ProgressView()
                .tint(Palette.accentText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Inline error with an optional retry.
struct ErrorBanner: View {
    let message: String
    var actionTitle: LocalizedStringKey = "Tentar novamente"
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.accentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Algo deu errado")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                if let retry {
                    Button(actionTitle, action: retry)
                        .buttonStyle(.soft)
                        .padding(.top, Spacing.xxs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .background(Palette.surfaceMuted, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// What the sync banner shows. Derived from account state and mirroring events.
enum SyncDisplayState: Equatable {
    case upToDate
    case syncing
    case failed(String)
    /// No network; local changes keep working and wait to be sent.
    case offline(pending: Int?)
    /// Connected, local changes not yet sent.
    case pending(Int)
    case accountUnavailable
    /// The iCloud storage holding the space (the owner's) is full: nothing is sent.
    case iCloudFull(isOwner: Bool)
    /// Local demo data, never synced.
    case demo
}

/// Sync status at the bottom of "Nosso espaço", as in the reference.
struct SyncStatusBanner: View {
    let state: SyncDisplayState

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Palette.accentText)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .background(Palette.surfaceMuted, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch state {
        case .upToDate: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .failed, .iCloudFull: "exclamationmark.icloud"
        case .offline: "wifi.slash"
        case .pending: "arrow.up.circle"
        case .accountUnavailable: "icloud.slash"
        case .demo: "hammer"
        }
    }

    private var title: LocalizedStringKey {
        switch state {
        case .upToDate: "Tudo sincronizado"
        case .syncing: "Sincronizando"
        case .failed: "Não foi possível sincronizar"
        case .iCloudFull: "iCloud cheio"
        case .offline: "Sem conexão"
        case .pending: "Enviando alterações"
        case .accountUnavailable: "iCloud indisponível"
        case .demo: "Modo demonstração"
        }
    }

    private var message: LocalizedStringKey {
        switch state {
        case .upToDate: "Suas alterações estão salvas no iCloud."
        case .syncing: "Você pode continuar usando o app normalmente."
        case .failed(let reason): "\(reason) Suas alterações continuam salvas neste iPhone."
        case .offline(let pending?) where pending > 0: "\(pending) alterações aguardando envio. Você pode continuar editando."
        case .offline: "Você pode continuar editando. Tudo é enviado quando a conexão voltar."
        case .pending(let count): "\(count) alterações aguardando envio ao iCloud."
        case .accountUnavailable: "Suas alterações ficam neste iPhone até o iCloud voltar."
        case .iCloudFull(isOwner: true): "O espaço de vocês fica no seu iCloud, que está cheio. Libere espaço ou aumente o plano nos Ajustes do iPhone. Até lá, nada novo chega ao seu par."
        case .iCloudFull(isOwner: false): "O espaço de vocês fica no iCloud do seu par, que está cheio. Peça para seu par liberar espaço. Até lá, o que você salvar fica só neste iPhone."
        case .demo: "Dados fictícios, só neste aparelho. Nada é enviado ao iCloud."
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.m) {
            EmptyStateView(systemImage: "photo.on.rectangle", title: "Nenhuma memória ainda", message: "Guardem aqui os momentos de vocês.")
            ErrorBanner(message: "Não foi possível abrir os dados.", retry: {})
            SyncStatusBanner(state: .upToDate)
            SyncStatusBanner(state: .failed("Sem conexão."))
            SyncStatusBanner(state: .demo)
            LoadingStateView(message: "Carregando…").frame(height: 120)
        }
        .padding()
    }
    .background(Palette.canvas)
}
