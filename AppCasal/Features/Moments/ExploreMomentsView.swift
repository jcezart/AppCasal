//
//  ExploreMomentsView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// "Explorar momentos": the question of the day first, the other activities lighter below.
/// No store, coins or ranking.
struct ExploreMomentsView: View {
    let context: MomentsContext

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            content
        }
        .canvasBackground()
        .navigationTitle("Hoje, nós dois")
        .onAppear { context.environment.prepareMoments() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Uma pergunta para se descobrirem e uma ideia para viverem juntos.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                MomentsHomeCard(context: context)
                SectionLabel(title: "Mais momentos")
                VStack(spacing: 0) {
                    row(.game, systemImage: "person.2.wave.2", title: "Quem conhece melhor?", subtitle: gameSubtitle)
                    divider
                    row(.dates, systemImage: "dice", title: "Escolhe por nós", subtitle: datesSubtitle)
                    divider
                    row(.gesture, systemImage: "hand.wave", title: "Pequeno gesto", subtitle: String(localized: "Uma gentileza simples para hoje."))
                    divider
                    row(.revive, systemImage: "arrow.counterclockwise.circle", title: "Vamos reviver?", subtitle: String(localized: "Uma memória de vocês para lembrar juntos."))
                }
                .padding(.horizontal, Spacing.card)
                .padding(.vertical, Spacing.xxs)
                .surfaceCard(padding: 0)
                VStack(spacing: 0) {
                    row(.history, systemImage: "clock.arrow.circlepath", title: "Perguntas anteriores", subtitle: String(localized: "Respostas e descobertas de outros dias."))
                    divider
                    row(.plans, systemImage: "calendar", title: "Planos e convites", subtitle: plansSubtitle)
                }
                .padding(.horizontal, Spacing.card)
                .padding(.vertical, Spacing.xxs)
                .surfaceCard(padding: 0)
            }
            .padding(Spacing.screen)
        }
    }

    private var divider: some View {
        Divider().overlay(Palette.hairline)
    }

    private func row(_ route: MomentsRoute, systemImage: String, title: LocalizedStringKey, subtitle: String) -> some View {
        NavigationLink(value: route) {
            MomentsActivityRow(systemImage: systemImage, title: title, subtitle: subtitle)
                .padding(.vertical, Spacing.s)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("moments.explore.\(route.payload)")
    }

    private var gameSubtitle: String {
        guard let round = context.repository.openRound(in: context.space) else {
            return String(localized: "Rodada curta de cinco perguntas.")
        }
        let mine = context.repository.gameAnswer(for: round, by: context.userRecordName) != nil
        if mine { return String(localized: "Você terminou. Esperando \(context.partnerName).") }
        if round.createdBy != context.userRecordName { return String(localized: "\(context.partnerName) começou uma rodada.") }
        return String(localized: "Rodada em andamento.")
    }

    private var datesSubtitle: String {
        let invitations = pendingInvitationsForMe
        if invitations > 0 {
            return String(localized: "\(invitations) convite(s) de \(context.partnerName) esperando resposta.")
        }
        return String(localized: "Uma ideia de encontro, do app ou de vocês.")
    }

    private var plansSubtitle: String {
        let open = context.repository.plans(in: context.space).filter { $0.completedAt == nil && $0.invitation != DateInvitation.declined.rawValue && $0.invitation != DateInvitation.cancelled.rawValue }.count
        return open == 0 ? String(localized: "Nada combinado ainda.") : String(localized: "\(open) plano(s) em aberto.")
    }

    private var pendingInvitationsForMe: Int {
        context.repository.plans(in: context.space).filter {
            $0.invitation == DateInvitation.pending.rawValue && $0.createdBy != context.userRecordName && $0.completedAt == nil
        }.count
    }
}
