//
//  PaywallGateView.swift
//  AppCasal
//

import SwiftUI

/// Shown instead of the app while nobody in the couple subscribed. Opens the Superwall
/// paywall on arrival; the screen stays behind it so closing the paywall never lands
/// inside the app. An invited partner does not pay: the invitation link opens the space.
/// With the partner already in the space, the subscriber's date is looked up in iCloud
/// before the paywall opens, so nobody pays twice.
struct PaywallGateView: View {
    let environment: AppEnvironment
    let reason: AccessRules.Reason
    /// Set when both partners are in the space: reads the partner's paid period again,
    /// true when it unlocked the app.
    let checkPartnerAccess: (() async -> Bool)?

    @State private var didPresent = false
    @State private var isRestoring = false
    @State private var isShowingInvitationHelp = false
    @State private var isCheckingPartner = false
    @State private var partnerNotice: String?

    private var subscription: SubscriptionService { environment.subscription }

    var body: some View {
        PromptScaffold(
            systemImage: "heart.circle",
            title: title,
            message: message,
            note: "Uma assinatura vale para os dois. Cancele quando quiser nos Ajustes do iPhone."
        ) {
            if isCheckingPartner {
                HStack(spacing: Spacing.s) {
                    ProgressView()
                    Text("Conferindo a assinatura do seu par…")
                }
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
            }
            if let notice = partnerNotice ?? subscription.paywallProblem {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(Palette.accentText)
                    .multilineTextAlignment(.center)
            }
            Button("Começar 7 dias grátis") { subscription.presentPaywall() }
                .buttonStyle(.primary)
                .disabled(isCheckingPartner)
                .accessibilityIdentifier("paywall.start")
            if let checkPartnerAccess {
                Button("Meu par já assinou") {
                    Task {
                        partnerNotice = nil
                        isCheckingPartner = true
                        let isUnlocked = await checkPartnerAccess()
                        isCheckingPartner = false
                        guard !isUnlocked else { return }
                        partnerNotice = String(localized: "Ainda não encontramos a assinatura do seu par. Peça para seu par abrir o OnlyUs com internet e toque aqui de novo.")
                    }
                }
                .buttonStyle(.soft)
                .disabled(isCheckingPartner)
                .accessibilityIdentifier("paywall.partnerSubscribed")
            } else {
                Button("Recebi um convite do meu par") { isShowingInvitationHelp = true }
                    .buttonStyle(.soft)
                    .accessibilityIdentifier("paywall.invitation")
            }
            Button {
                Task {
                    isRestoring = true
                    await subscription.restore()
                    environment.recordSubscriptionAccess()
                    isRestoring = false
                }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Restaurar compras")
                }
            }
            .buttonStyle(.text)
            .disabled(isRestoring)
            HStack(spacing: Spacing.m) {
                Link("Termos de uso", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Política de privacidade", destination: URL(string: "https://jcapps.dev.br/onlyus/privacidade/")!)
            }
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
        }
        .task {
            // Once per appearance of the gate, so closing the paywall does not reopen it.
            guard !didPresent else { return }
            didPresent = true
            if let checkPartnerAccess {
                isCheckingPartner = true
                let isUnlocked = await checkPartnerAccess()
                isCheckingPartner = false
                // Unlocked by the partner: the gate is leaving, no paywall.
                guard !isUnlocked, !Task.isCancelled else { return }
            }
            subscription.presentPaywall()
        }
        .alert("Convite do seu par", isPresented: $isShowingInvitationHelp) {
            Button("Entendi", role: .cancel) {}
        } message: {
            Text("Você não precisa pagar. Feche esta tela e abra o link que seu par enviou (pelo WhatsApp, Mensagens ou outro app): você entra no espaço de vocês, e a assinatura de quem convidou vale para os dois.")
        }
    }

    private var title: LocalizedStringKey {
        switch reason {
        case .noSubscription: "Um lugar só de vocês dois"
        case .coupleAccessEnded: "O acesso de vocês terminou"
        }
    }

    private var message: LocalizedStringKey {
        if checkPartnerAccess != nil, reason == .noSubscription {
            return "Uma assinatura vale para os dois. Se seu par já assinou, toque em \"Meu par já assinou\" e vocês entram sem pagar de novo."
        }
        return switch reason {
        case .noSubscription:
            "Memórias, recadinhos, planos e a pergunta do dia, guardados no iCloud de vocês. Experimente 7 dias grátis."
        case .coupleAccessEnded:
            "A assinatura do casal não está mais ativa. Peça para quem assinou abrir o app, ou assine aqui para continuar. Nada do que vocês guardaram foi apagado."
        }
    }
}
