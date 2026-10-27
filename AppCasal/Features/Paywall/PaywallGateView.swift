//
//  PaywallGateView.swift
//  AppCasal
//

import SwiftUI

/// Shown instead of the app while nobody in the couple subscribed. Opens the Superwall
/// paywall on arrival; the screen stays behind it so closing the paywall never lands
/// inside the app. An invited partner does not pay: the invitation link opens the space.
struct PaywallGateView: View {
    let environment: AppEnvironment
    let reason: AccessRules.Reason

    @State private var didPresent = false
    @State private var isRestoring = false
    @State private var isShowingInvitationHelp = false

    private var subscription: SubscriptionService { environment.subscription }

    var body: some View {
        PromptScaffold(
            systemImage: "heart.circle",
            title: title,
            message: message,
            note: "Uma assinatura vale para os dois. Cancele quando quiser nos Ajustes do iPhone."
        ) {
            if let problem = subscription.paywallProblem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(Palette.accentText)
                    .multilineTextAlignment(.center)
            }
            Button("Começar 7 dias grátis") { subscription.presentPaywall() }
                .buttonStyle(.primary)
                .accessibilityIdentifier("paywall.start")
            Button("Recebi um convite do meu par") { isShowingInvitationHelp = true }
                .buttonStyle(.text)
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
            subscription.presentPaywall()
        }
        .alert("Convite do seu par", isPresented: $isShowingInvitationHelp) {
            Button("Entendi", role: .cancel) {}
        } message: {
            Text("Abra o link que seu par enviou (pelo WhatsApp, Mensagens ou outro app). Você entra no espaço de vocês sem pagar: a assinatura de quem convidou vale para os dois.")
        }
    }

    private var title: LocalizedStringKey {
        switch reason {
        case .noSubscription: "Um lugar só de vocês dois"
        case .coupleAccessEnded: "O acesso de vocês terminou"
        }
    }

    private var message: LocalizedStringKey {
        switch reason {
        case .noSubscription:
            "Memórias, recadinhos, planos e a pergunta do dia, guardados no iCloud de vocês. Experimente 7 dias grátis."
        case .coupleAccessEnded:
            "A assinatura do casal não está mais ativa. Peça para quem assinou abrir o app, ou assine aqui para continuar. Nada do que vocês guardaram foi apagado."
        }
    }
}
