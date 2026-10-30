//
//  SpaceView.swift
//  AppCasal
//

import CloudKit
import StoreKit
import SwiftUI

/// "Nosso espaço": both partners, connection, profile, couple photo, relationship date,
/// reminders, notifications, subscription, recently deleted, sharing and space management,
/// sync status.
struct SpaceView: View {
    /// Store screenshots (`-AppCasalStoreScreenshots YES`, DEBUG only): no demo banner
    /// or diagnostics, which do not exist in the shipped app.
    private static var hidesDemoChrome: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "AppCasalStoreScreenshots")
        #else
        false
        #endif
    }

    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @Environment(\.dismiss) private var dismiss
    @State private var share: CKShare?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var confirmation: Confirmation?
    @State private var isManagingSubscription = false

    private enum Confirmation: Identifiable {
        case leave, startNew, delete
        var id: Self { self }
    }

    private var me: Member? { environment.spaces.member(for: userRecordName, in: space) }
    private var partner: Member? { environment.spaces.partner(of: userRecordName, in: space) }
    private var isOwner: Bool { environment.spaces.role(in: space) == .owner }
    /// Only who subscribed on this Apple ID: the partner unlocked by the couple has nothing to manage.
    private var showsSubscription: Bool {
        environment.subscription.isEnforced && environment.subscription.isSubscribed == true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.m) {
                        CoupleAvatars(
                            firstName: me?.displayName ?? "",
                            secondName: partner?.displayName,
                            firstPhoto: me?.avatarData,
                            secondPhoto: partner?.avatarData
                        )
                        connectionChip
                    }
                    .padding(.top, Spacing.s)

                    rows

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if !Self.hidesDemoChrome {
                        SyncStatusBanner(state: environment.sync.displayState(
                            isDemo: environment.isDemo,
                            accountStatus: environment.account.status,
                            isConnected: environment.network.isConnected,
                            isOwner: isOwner
                        ))
                    }

                    if !environment.isDemo {
                        sharingRows
                    }

                    #if DEBUG
                    if !Self.hidesDemoChrome {
                        NavigationLink {
                            SharingSpikeView(environment: environment)
                        } label: {
                            Label("Diagnóstico de compartilhamento", systemImage: "wrench.and.screwdriver")
                        }
                        .buttonStyle(.soft)
                    }
                    #endif
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xl)
            }
            .canvasBackground()
            .disabled(isWorking)
            .overlay { if isWorking { ProgressView() } }
            .tint(Palette.accentText)
            .navigationTitle("Nosso espaço")
            .navigationSubtitle("Aqui é onde a nossa história continua.")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluído", systemImage: "checkmark", role: .confirm) { dismiss() }
                        .confirmationButtonStyle()
                }
            }
            .confirmationDialog(confirmationTitle, isPresented: Binding(
                get: { confirmation != nil && confirmation != .delete },
                set: { if !$0 { confirmation = nil } }
            ), titleVisibility: .visible, presenting: confirmation) { item in
                switch item {
                case .leave:
                    Button("Sair do espaço", role: .destructive) { run { try await environment.sharing.leave(space) } }
                case .startNew:
                    Button("Começar um novo espaço", role: .destructive) { run { try await environment.sharing.archive(space) } }
                case .delete:
                    EmptyView()
                }
            } message: { item in
                switch item {
                case .leave:
                    Text("Você deixa de ver o espaço neste iPhone. Nada é apagado do iCloud do seu par.")
                case .startNew:
                    Text("Este espaço fica arquivado com você e um novo espaço, vazio, é criado para um novo convite.")
                case .delete:
                    EmptyView()
                }
            }
            .sheet(isPresented: Binding(get: { confirmation == .delete }, set: { if !$0 { confirmation = nil } })) {
                DeleteSpaceView { run { try await environment.sharing.deletePermanently(space) } }
            }
            // Apple's own sheet: change plan or cancel without leaving the app (test sheet in TestFlight).
            .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
            .onChange(of: isManagingSubscription) { _, isPresented in
                guard !isPresented else { return }
                Task { await environment.subscription.refresh() }
            }
        }
        .task {
            reloadShare()
            await environment.reminderNotifications.refreshAuthorization()
        }
        .onChange(of: environment.sharing.shareRevision) { reloadShare() }
    }

    private var confirmationTitle: LocalizedStringKey {
        switch confirmation {
        case .leave: "Sair do espaço?"
        case .startNew: "Começar um novo espaço?"
        default: ""
        }
    }

    @ViewBuilder
    private var connectionChip: some View {
        if isPartnerConnected {
            StatusChip(title: "Conectados", systemImage: "circle.fill", tone: .success)
        } else if let share, CoupleLimit.activePartnerCount(CoupleLimit.summaries(of: share)) > 0 {
            StatusChip(title: "Convite enviado", systemImage: "paperplane", tone: .neutral)
        } else {
            StatusChip(title: "Aguardando seu par", systemImage: "hourglass", tone: .neutral)
        }
    }

    /// The partner's profile stays in the space after they leave or are removed (it signs
    /// their notes and memories), so the owner also needs them in the share.
    private var isPartnerConnected: Bool {
        guard partner != nil else { return false }
        guard isOwner, !environment.isDemo else { return true }
        guard let share else { return false }
        return CoupleLimit.acceptedPartnerCount(CoupleLimit.summaries(of: share)) > 0
    }

    /// The partner left or was removed but their profile is still here: the invitation can
    /// bring them back to the same space, while someone new should start a new one.
    private var formerPartnerName: String? {
        guard isOwner, !isPartnerConnected, let partner else { return nil }
        let name = partner.displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? String(localized: "seu par") : name
    }

    private var rows: some View {
        VStack(spacing: 0) {
            if let me {
                NavigationLink {
                    ProfileView(environment: environment, member: me)
                } label: {
                    SettingsRow(systemImage: "person", title: "Meu perfil", subtitle: me.displayName)
                }
                .buttonStyle(.plain)
                divider
            }
            NavigationLink {
                CouplePhotoView(environment: environment, space: space)
            } label: {
                SettingsRow(
                    systemImage: "camera",
                    title: "Foto do casal",
                    subtitle: space.coverPhotoData == nil ? String(localized: "Nenhuma foto") : nil
                )
            }
            .buttonStyle(.plain)
            divider
            NavigationLink {
                RelationshipStartView(environment: environment, space: space)
            } label: {
                SettingsRow(
                    systemImage: "calendar",
                    title: "Início do relacionamento",
                    subtitle: space.relationshipStart?.formatted(date: .long, time: .omitted) ?? String(localized: "Não definido")
                )
            }
            .buttonStyle(.plain)
            divider
            NavigationLink {
                RemindersView(environment: environment, space: space, userRecordName: userRecordName)
            } label: {
                SettingsRow(systemImage: "bell", title: "Lembretes", subtitle: remindersSubtitle)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("space.reminders")
            divider
            NavigationLink {
                NotificationSettingsView(environment: environment)
            } label: {
                SettingsRow(
                    systemImage: "app.badge",
                    title: "Notificações",
                    subtitle: environment.reminderNotifications.isAllowed ? String(localized: "Ativadas") : String(localized: "Desativadas")
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("space.notifications")
            divider
            if showsSubscription {
                Button { isManagingSubscription = true } label: {
                    SettingsRow(systemImage: "creditcard", title: "Gerenciar assinatura")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("space.subscription")
                divider
            }
            NavigationLink {
                DeletedItemsView(environment: environment, space: space, userRecordName: userRecordName)
            } label: {
                SettingsRow(systemImage: "trash", title: "Excluídos recentemente")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.card)
        .padding(.vertical, Spacing.xxs)
        .surfaceCard(padding: 0)
    }

    /// Invite, manage, leave, start over and delete. Not shown in demo mode (no CloudKit).
    @ViewBuilder
    private var sharingRows: some View {
        VStack(spacing: 0) {
            if isOwner {
                if space.sharingEndedAt != nil {
                    SettingsRow(
                        systemImage: "person.crop.circle.badge.xmark",
                        title: "Compartilhamento encerrado",
                        subtitle: String(localized: "Os dados continuam com você."),
                        showsChevron: false
                    )
                    divider
                    Button { confirmation = .startNew } label: {
                        SettingsRow(systemImage: "plus.circle", title: "Começar um novo espaço")
                    }
                    .buttonStyle(.plain)
                } else if let share, !CoupleLimit.canInvite(CoupleLimit.summaries(of: share)) {
                    manageSharingButton(share, title: "Gerenciar compartilhamento")
                } else {
                    Button {
                        run {
                            try await environment.sharing.presentInvitation(for: space)
                            reloadShare()
                        }
                    } label: {
                        if let formerPartnerName {
                            SettingsRow(
                                systemImage: "person.badge.plus",
                                title: "Convidar \(formerPartnerName) de volta",
                                subtitle: String(localized: "Quem abrir o link vê tudo o que vocês guardaram. Para outra pessoa, comece um novo espaço.")
                            )
                        } else {
                            SettingsRow(
                                systemImage: "person.badge.plus",
                                title: "Convidar seu par",
                                subtitle: String(localized: "No WhatsApp, toque em Continuar: só quem abrir o link primeiro entra.")
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    if let share {
                        divider
                        manageSharingButton(share, title: "Gerenciar convite")
                    }
                    if formerPartnerName != nil {
                        divider
                        Button { confirmation = .startNew } label: {
                            SettingsRow(systemImage: "plus.circle", title: "Começar um novo espaço")
                        }
                        .buttonStyle(.plain)
                    }
                }
                divider
                Button { confirmation = .delete } label: {
                    SettingsRow(systemImage: "exclamationmark.triangle", title: "Apagar o espaço", showsChevron: false)
                }
                .buttonStyle(.plain)
            } else {
                Button { confirmation = .leave } label: {
                    SettingsRow(systemImage: "rectangle.portrait.and.arrow.right", title: "Sair do espaço", showsChevron: false)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.card)
        .padding(.vertical, Spacing.xxs)
        .surfaceCard(padding: 0)
    }

    private var remindersSubtitle: String? {
        let count = (space.reminders ?? []).filter { $0.deletedAt == nil }.count
        return count == 0 ? nil : String(localized: "\(count) lembretes")
    }

    private var divider: some View {
        Divider().overlay(Palette.hairline)
    }

    private func reloadShare() {
        guard !environment.isDemo else { return }
        share = environment.sharing.existingShare(for: space)
    }

    /// Participants and stopping the share, in the system sharing screen.
    private func manageSharingButton(_ share: CKShare, title: LocalizedStringKey) -> some View {
        Button {
            environment.sharing.presentSharingController(for: share, of: space)
        } label: {
            SettingsRow(systemImage: "person.2", title: title)
        }
        .buttonStyle(.plain)
    }

    private func run(_ action: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Strong confirmation for the irreversible deletion: the owner types a word.
private struct DeleteSpaceView: View {
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    private let word = String(localized: "APAGAR")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Isto apaga o espaço e tudo o que há nele (memórias, fotos, recados, metas e lugares) para vocês dois, neste iPhone e no iCloud. Não dá para desfazer.")
                        .foregroundStyle(Palette.textPrimary)
                }
                .listRowBackground(Palette.surface)
                Section {
                    TextField(word, text: $typed)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Digite \(word) para confirmar")
                }
                .listRowBackground(Palette.surface)
            }
            .canvasBackground()
            .navigationTitle("Apagar o espaço")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apagar", systemImage: "trash", role: .destructive) {
                        dismiss()
                        onConfirm()
                    }
                    .disabled(typed.trimmingCharacters(in: .whitespaces).uppercased() != word)
                }
            }
        }
    }
}

private struct ProfileView: View {
    let environment: AppEnvironment
    @ObservedObject var member: Member

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
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.s) {
                        AvatarView(name: name, imageData: member.avatarData, size: 96)
                        HStack(spacing: Spacing.s) {
                            PhotoPickerButton(onPicked: { photo in
                                save { try environment.spaces.setAvatar(photo.thumbnailData, for: member) }
                            }, onFailure: { errorMessage = $0 }, crop: .circle) {
                                Text(member.avatarData == nil ? "Escolher foto" : "Trocar foto")
                            }
                            if member.avatarData != nil {
                                Button("Remover", role: .destructive) {
                                    save { try environment.spaces.setAvatar(nil, for: member) }
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
            Section {
                TextField("Seu nome", text: $name)
                    .textContentType(.givenName)
            } footer: {
                Text("É assim que você aparece para o seu par.")
            }
            .listRowBackground(Palette.surface)
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
                    .listRowBackground(Palette.surface)
            }
        }
        .canvasBackground()
        .tint(Palette.accentText)
        .navigationTitle("Meu perfil")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar", systemImage: "checkmark", role: .confirm) {
                    save {
                        try environment.spaces.updateDisplayName(member, to: name.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                }
                    .confirmationButtonStyle()
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CouplePhotoView: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace

    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                DecodedImage(data: space.coverPhotoData) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.surfaceMuted)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                .accessibilityLabel(Text("Foto do casal"))
                PhotoPickerButton(onPicked: { photo in
                    save { try environment.spaces.setCoverPhoto(photo.imageData, in: space) }
                }, onFailure: { errorMessage = $0 }, crop: .square) {
                    Label(space.coverPhotoData == nil ? "Escolher foto" : "Trocar foto", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.primary)
                if space.coverPhotoData != nil {
                    Button("Remover foto", role: .destructive) {
                        save { try environment.spaces.setCoverPhoto(nil, in: space) }
                    }
                    .buttonStyle(.text)
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                Text("A foto aparece no Início para vocês dois.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Spacing.screen)
        }
        .canvasBackground()
        .navigationTitle("Foto do casal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
            .listRowBackground(Palette.surface)
            if space.relationshipStart != nil {
                Section {
                    Button("Remover data", role: .destructive) { save(nil) }
                }
                .listRowBackground(Palette.surface)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
                    .listRowBackground(Palette.surface)
            }
        }
        .canvasBackground()
        .navigationTitle("Início do relacionamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar", systemImage: "checkmark", role: .confirm) { save(date) }
                    .confirmationButtonStyle()
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
