//
//  SharingSpikeView.swift
//  AppCasal
//

#if DEBUG
import CloudKit
import CoreData
import SwiftUI

/// DEBUG-only stage 1 test screen (no visual design): create a space, invite, accept,
/// and create/edit a simple record from both accounts. Reached from "Nosso espaço".
struct SharingSpikeView: View {
    let environment: AppEnvironment

    @State private var space: CoupleSpace?
    @State private var share: CKShare?
    @State private var errorMessage: String?

    private var account: AccountService { environment.account }

    var body: some View {
        List {
                AccountSection(account: account)
                if account.status == .available, let userRecordName = account.userRecordName {
                    acceptanceSection
                    if let space {
                        SpaceSection(
                            environment: environment,
                            space: space,
                            share: share,
                            userRecordName: userRecordName,
                            onChange: reload,
                            onError: { errorMessage = $0 }
                        )
                        if environment.spaces.member(for: userRecordName, in: space) != nil {
                            NewNoteSection(environment: environment, space: space, userRecordName: userRecordName, onError: { errorMessage = $0 })
                            NoteListSection(environment: environment, space: space, userRecordName: userRecordName, showsDeleted: false, onError: { errorMessage = $0 })
                            NoteListSection(environment: environment, space: space, userRecordName: userRecordName, showsDeleted: true, onError: { errorMessage = $0 })
                        }
                    } else {
                        CreateSpaceSection(environment: environment, userRecordName: userRecordName, onCreated: reload, onError: { errorMessage = $0 })
                    }
                }
                SyncSection(monitor: environment.sync)
            }
            .navigationTitle("Teste de compartilhamento")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { reload() }
            .alert("Erro", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        .task {
            await account.refresh()
            reload()
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                reload()
            }
        }
        .onChange(of: environment.sharing.shareRevision) { reload() }
        .onChange(of: environment.sharing.acceptance) { reload() }
        .onChange(of: account.userRecordName) { reload() }
    }

    @ViewBuilder
    private var acceptanceSection: some View {
        switch environment.sharing.acceptance {
        case .idle:
            EmptyView()
        case .accepting:
            Section("Convite") { ProgressView("Aceitando convite…") }
        case .accepted:
            Section("Convite") { Text("Convite aceito. Os dados aparecem após a sincronização; puxe para atualizar.") }
        case .rejected(let reason), .failed(let reason):
            Section("Convite") { Text(reason).foregroundStyle(.red) }
        }
    }

    private func reload() {
        space = environment.spaces.activeSpace()
        share = space.flatMap { environment.sharing.existingShare(for: $0) }
    }
}

private struct AccountSection: View {
    let account: AccountService

    var body: some View {
        Section("Conta iCloud") {
            switch account.status {
            case .checking:
                ProgressView()
            case .available:
                LabeledContent("Estado", value: String(localized: "Disponível"))
                if let name = account.userRecordName {
                    LabeledContent("Usuário", value: String(name.suffix(8)))
                }
            case .noAccount:
                Text("Entre no iCloud nos Ajustes para usar o espaço do casal.")
            case .restricted:
                Text("O uso do iCloud está restrito neste aparelho.")
            case .temporarilyUnavailable:
                Text("O iCloud está temporariamente indisponível.")
            case .couldNotDetermine:
                Text("Não foi possível verificar a conta iCloud.")
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            }
        }
    }
}

private struct CreateSpaceSection: View {
    let environment: AppEnvironment
    let userRecordName: String
    let onCreated: () -> Void
    let onError: (String) -> Void

    @State private var name = ""

    var body: some View {
        Section("Criar espaço") {
            TextField("Seu nome", text: $name)
                .textContentType(.givenName)
            Button("Criar espaço") {
                do {
                    _ = try environment.spaces.createSpace(ownerName: name, userRecordName: userRecordName)
                    onCreated()
                } catch {
                    onError(error.localizedDescription)
                }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            Text("Ou abra o link de convite recebido do seu parceiro ou parceira.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SpaceSection: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let share: CKShare?
    let userRecordName: String
    let onChange: () -> Void
    let onError: (String) -> Void

    @State private var participantName = ""
    @State private var isPreparingShare = false

    private var role: Member.Role { environment.spaces.role(in: space) }

    var body: some View {
        Section("Espaço") {
            LabeledContent("Papel", value: role == .owner ? String(localized: "Dono") : String(localized: "Participante"))
            LabeledContent("Banco", value: role == .owner ? String(localized: "Privado") : String(localized: "Compartilhado"))
            ForEach(sortedMembers) { member in
                LabeledContent(member.displayName ?? "—", value: member.role ?? "")
            }
            if let share {
                shareStatus(share)
            }
            if role == .owner {
                ownerActions
            } else if environment.spaces.member(for: userRecordName, in: space) == nil {
                TextField("Seu nome", text: $participantName)
                Button("Confirmar meu nome") {
                    do {
                        try environment.spaces.ensureMember(named: participantName, userRecordName: userRecordName, in: space)
                        onChange()
                    } catch {
                        onError(error.localizedDescription)
                    }
                }
                .disabled(participantName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var sortedMembers: [Member] {
        (space.members ?? []).sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    @ViewBuilder
    private func shareStatus(_ share: CKShare) -> some View {
        let summaries = CoupleLimit.summaries(of: share)
        LabeledContent("Parceiros no convite", value: "\(CoupleLimit.activePartnerCount(summaries))")
        ForEach(share.participants.filter { $0.role != .owner }, id: \.self) { participant in
            LabeledContent(
                participant.userIdentity.nameComponents?.formatted() ?? String(localized: "Convidado"),
                value: Self.describe(participant.acceptanceStatus)
            )
        }
        if !CoupleLimit.isValidCouple(summaries) {
            Text("Há mais de um parceiro no convite. Remova o excedente em Gerenciar.")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var ownerActions: some View {
        if space.sharingEndedAt != nil {
            Text("Compartilhamento encerrado. Os dados continuam com você. Um novo relacionamento começa em um novo espaço.")
                .foregroundStyle(.secondary)
        } else if let share {
            Button(CoupleLimit.canInvite(CoupleLimit.summaries(of: share)) ? "Convidar parceiro(a)" : "Gerenciar compartilhamento") {
                environment.sharing.presentSharingController(for: share, of: space)
            }
        } else {
            Button {
                Task { await createAndPresentShare() }
            } label: {
                if isPreparingShare {
                    ProgressView()
                } else {
                    Text("Convidar parceiro(a)")
                }
            }
            .disabled(isPreparingShare)
        }
    }

    private func createAndPresentShare() async {
        isPreparingShare = true
        defer { isPreparingShare = false }
        do {
            let newShare = try await environment.sharing.createShare(for: space)
            onChange()
            environment.sharing.presentSharingController(for: newShare, of: space)
        } catch {
            onError(error.localizedDescription)
        }
    }

    private static func describe(_ status: CKShare.ParticipantAcceptanceStatus) -> String {
        switch status {
        case .pending: String(localized: "Pendente")
        case .accepted: String(localized: "Aceito")
        case .removed: String(localized: "Removido")
        case .unknown: String(localized: "Desconhecido")
        @unknown default: String(localized: "Desconhecido")
        }
    }
}

private struct NewNoteSection: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let onError: (String) -> Void

    @State private var text = ""

    var body: some View {
        Section("Novo recadinho de teste") {
            TextField("Texto", text: $text, axis: .vertical)
            Button("Adicionar") {
                do {
                    try environment.notes.create(text: text, in: space, by: userRecordName)
                    text = ""
                } catch {
                    onError(error.localizedDescription)
                }
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

private struct NoteListSection: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let showsDeleted: Bool
    let onError: (String) -> Void

    @FetchRequest private var notes: FetchedResults<Note>
    @State private var editingNote: Note?

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String, showsDeleted: Bool, onError: @escaping (String) -> Void) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        self.showsDeleted = showsDeleted
        self.onError = onError
        let deletedPredicate = showsDeleted ? "deletedAt != nil" : "deletedAt == nil"
        _notes = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
            predicate: NSPredicate(format: "space == %@ AND \(deletedPredicate)", space)
        )
    }

    var body: some View {
        Section(showsDeleted ? "Excluídos recentemente" : "Recadinhos") {
            if notes.isEmpty {
                Text(showsDeleted ? "Nada excluído." : "Nenhum recadinho ainda.")
                    .foregroundStyle(.secondary)
            }
            ForEach(notes) { note in
                NoteRow(note: note, authorName: name(for: note.authorID), editorName: name(for: note.modifiedBy))
                    .contentShape(.rect)
                    .onTapGesture { if !showsDeleted { editingNote = note } }
                    .swipeActions {
                        if showsDeleted {
                            Button("Restaurar") { perform { try environment.notes.restore(note, by: userRecordName) } }
                                .tint(.green)
                        } else {
                            Button("Excluir", role: .destructive) { perform { try environment.notes.softDelete(note, by: userRecordName) } }
                        }
                    }
            }
        }
        .sheet(item: $editingNote) { note in
            EditNoteView(environment: environment, note: note, userRecordName: userRecordName, onError: onError)
        }
    }

    private func name(for userRecordName: String?) -> String {
        space.members?.first { $0.userRecordName == userRecordName }?.displayName ?? String(localized: "Desconhecido")
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            onError(error.localizedDescription)
        }
    }
}

private struct NoteRow: View {
    @ObservedObject var note: Note
    let authorName: String
    let editorName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.text ?? "")
            Text("De \(authorName) · editado por \(editorName) \(note.modifiedAt ?? .now, format: .relative(presentation: .named))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EditNoteView: View {
    let environment: AppEnvironment
    let note: Note
    let userRecordName: String
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(environment: AppEnvironment, note: Note, userRecordName: String, onError: @escaping (String) -> Void) {
        self.environment = environment
        self.note = note
        self.userRecordName = userRecordName
        self.onError = onError
        _text = State(initialValue: note.text ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Texto", text: $text, axis: .vertical)
            }
            .navigationTitle("Editar recadinho")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        do {
                            try environment.notes.update(note, text: text, by: userRecordName)
                            dismiss()
                        } catch {
                            onError(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}

private struct SyncSection: View {
    let monitor: SyncMonitor

    var body: some View {
        Section("Sincronização (diagnóstico)") {
            if monitor.entries.isEmpty {
                Text("Nenhum evento ainda.").foregroundStyle(.secondary)
            }
            ForEach(monitor.entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.kind) · \(entry.storeName) · \(entry.isFinished ? (entry.succeeded ? "ok" : "falhou") : "em andamento")")
                        .font(.caption.monospaced())
                    if let error = entry.errorDescription {
                        Text(error).font(.caption2).foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
#endif
