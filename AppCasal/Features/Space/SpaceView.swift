//
//  SpaceView.swift
//  AppCasal
//

import CloudKit
import SwiftUI

/// "Nosso espaço": both partners, connection, profile, relationship date and sync status.
struct SpaceView: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @Environment(\.dismiss) private var dismiss
    @State private var share: CKShare?
    @State private var isPreparingInvite = false
    @State private var errorMessage: String?

    private var me: Member? { environment.spaces.member(for: userRecordName, in: space) }
    private var partner: Member? { environment.spaces.partner(of: userRecordName, in: space) }
    private var isOwner: Bool { environment.spaces.role(in: space) == .owner }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.m) {
                        CoupleAvatars(firstName: me?.displayName ?? "", secondName: partner?.displayName)
                        connectionChip
                    }
                    .padding(.top, Spacing.s)

                    rows

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    SyncStatusBanner(state: environment.sync.displayState(
                        isDemo: environment.isDemo,
                        accountStatus: environment.account.status
                    ))

                    #if DEBUG
                    NavigationLink {
                        SharingSpikeView(environment: environment)
                    } label: {
                        Label("Diagnóstico de compartilhamento", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.soft)
                    #endif
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xl)
            }
            .canvasBackground()
            .navigationTitle("Nosso espaço")
            .navigationSubtitle("Aqui é onde a nossa história continua.")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .task { reloadShare() }
        .onChange(of: environment.sharing.shareRevision) { reloadShare() }
    }

    @ViewBuilder
    private var connectionChip: some View {
        if partner != nil {
            StatusChip(title: "Conectados", systemImage: "circle.fill", tone: .success)
        } else if let share, CoupleLimit.activePartnerCount(CoupleLimit.summaries(of: share)) > 0 {
            StatusChip(title: "Convite enviado", systemImage: "paperplane", tone: .neutral)
        } else {
            StatusChip(title: "Aguardando seu par", systemImage: "hourglass", tone: .neutral)
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            if let me {
                NavigationLink {
                    EditNameView(environment: environment, member: me)
                } label: {
                    SettingsRow(systemImage: "person", title: "Meu perfil", subtitle: me.displayName)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.hairline)
            }
            NavigationLink {
                RelationshipStartView(environment: environment, space: space)
            } label: {
                SettingsRow(
                    systemImage: "calendar",
                    title: "Início do relacionamento",
                    subtitle: space.relationshipStart?.formatted(date: .long, time: .omitted)
                        ?? String(localized: "Não definido")
                )
            }
            .buttonStyle(.plain)
            inviteRow
        }
        .padding(.horizontal, Spacing.card)
        .padding(.vertical, Spacing.xxs)
        .surfaceCard(padding: 0)
    }

    @ViewBuilder
    private var inviteRow: some View {
        if isOwner, !environment.isDemo, partner == nil {
            Divider().overlay(Palette.hairline)
            if space.sharingEndedAt != nil {
                SettingsRow(
                    systemImage: "person.crop.circle.badge.xmark",
                    title: "Compartilhamento encerrado",
                    subtitle: String(localized: "Os dados continuam com você. Um novo relacionamento começa em um novo espaço."),
                    showsChevron: false
                )
            } else if let share {
                Button {
                    environment.sharing.presentSharingController(for: share, of: space)
                } label: {
                    SettingsRow(
                        systemImage: "person.badge.plus",
                        title: CoupleLimit.canInvite(CoupleLimit.summaries(of: share)) ? "Convidar seu par" : "Gerenciar convite"
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await createInvite() }
                } label: {
                    SettingsRow(systemImage: "person.badge.plus", title: "Convidar seu par", showsChevron: !isPreparingInvite)
                        .overlay(alignment: .trailing) {
                            if isPreparingInvite { ProgressView() }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isPreparingInvite)
            }
        }
    }

    private func reloadShare() {
        guard !environment.isDemo else { return }
        share = environment.sharing.existingShare(for: space)
    }

    private func createInvite() async {
        isPreparingInvite = true
        defer { isPreparingInvite = false }
        do {
            let newShare = try await environment.sharing.createShare(for: space)
            share = newShare
            environment.sharing.presentSharingController(for: newShare, of: space)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditNameView: View {
    let environment: AppEnvironment
    let member: Member

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?

    init(environment: AppEnvironment, member: Member) {
        self.environment = environment
        self.member = member
        _name = State(initialValue: member.displayName ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("Seu nome", text: $name)
                    .textContentType(.givenName)
            } footer: {
                Text("É assim que você aparece para o seu par.")
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
            }
        }
        .canvasBackground()
        .navigationTitle("Meu perfil")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    do {
                        try environment.spaces.updateDisplayName(member, to: name.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

private struct RelationshipStartView: View {
    let environment: AppEnvironment
    let space: CoupleSpace

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var errorMessage: String?

    init(environment: AppEnvironment, space: CoupleSpace) {
        self.environment = environment
        self.space = space
        _date = State(initialValue: space.relationshipStart ?? .now)
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Data", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Palette.accentText)
            } footer: {
                Text("Usada para contar os dias juntos no Início.")
            }
            if space.relationshipStart != nil {
                Section {
                    Button("Remover data", role: .destructive) { save(nil) }
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
            }
        }
        .canvasBackground()
        .navigationTitle("Início do relacionamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { save(date) }
            }
        }
    }

    private func save(_ value: Date?) {
        do {
            try environment.spaces.setRelationshipStart(value, in: space)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    let environment = DemoData.previewEnvironment()
    SpaceView(environment: environment, space: environment.spaces.activeSpace()!, userRecordName: DemoData.ownerID)
        .environment(\.managedObjectContext, environment.persistence.viewContext)
}
#endif
