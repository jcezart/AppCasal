//
//  NotesView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Recados: received, sent and personal favorites. Authors edit or delete their own notes.
struct NotesView: View {
    enum Filter: Hashable {
        case received
        case sent
        case favorites
    }

    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @State private var filter = Filter.received
    @State private var composer: NoteComposerView.Mode?
    @State private var errorMessage: String?
    @FetchRequest private var notes: FetchedResults<Note>
    @FetchRequest private var favorites: FetchedResults<NoteFavorite>

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        _notes = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
            predicate: NSPredicate(format: "space == %@ AND deletedAt == nil", space),
            animation: .default
        )
        _favorites = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "userRecordName == %@", userRecordName)
        )
    }

    private var favoriteIDs: Set<UUID> { Set(favorites.compactMap(\.noteID)) }

    private var filteredNotes: [Note] {
        switch filter {
        case .received: notes.filter { $0.authorID != userRecordName }
        case .sent: notes.filter { $0.authorID == userRecordName }
        case .favorites: notes.filter { $0.id.map(favoriteIDs.contains) ?? false }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                PillSegmentedControl(selection: $filter, options: [
                    .init(value: .received, title: "Recebidos"),
                    .init(value: .sent, title: "Enviados"),
                    .init(value: .favorites, title: "Favoritos"),
                ])
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                content
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .canvasBackground()
        .navigationTitle("Recados")
        .navigationSubtitle("Pequenas palavras, grandes significados.")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Escrever recadinho", systemImage: "pencil") { composer = .new }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("notes.compose")
            }
        }
        .sheet(item: $composer) { mode in
            NoteComposerView(environment: environment, space: space, userRecordName: userRecordName, mode: mode)
        }
    }

    @ViewBuilder
    private var content: some View {
        let items = filteredNotes
        if items.isEmpty {
            switch filter {
            case .received:
                EmptyStateView(systemImage: "envelope", title: "Nenhum recadinho recebido", message: "Os recadinhos do seu par aparecem aqui.")
            case .sent:
                EmptyStateView(
                    systemImage: "pencil.line",
                    title: "Nenhum recadinho enviado",
                    message: "Pequenas palavras guardadas para sempre.",
                    actionTitle: "Escrever recadinho",
                    action: { composer = .new }
                )
            case .favorites:
                EmptyStateView(
                    systemImage: "heart",
                    title: "Nenhum favorito ainda",
                    message: "Os recadinhos que você marcar com o coração aparecem aqui. Só você vê seus favoritos."
                )
            }
        } else {
            LazyVStack(spacing: Spacing.s) {
                ForEach(items) { note in
                    card(for: note)
                }
            }
        }
    }

    private func card(for note: Note) -> some View {
        let isMine = note.authorID == userRecordName
        return NoteCard(
            text: note.text ?? "",
            authorName: isMine ? String(localized: "Você") : name(for: note.authorID),
            date: note.createdAt ?? .now,
            isEdited: (note.modifiedAt ?? .distantPast) > (note.createdAt ?? .distantPast).addingTimeInterval(1),
            isFavorite: note.id.map(favoriteIDs.contains) ?? false,
            onToggleFavorite: { toggleFavorite(note) }
        )
        .contextMenu {
            if isMine {
                Button("Editar", systemImage: "pencil") { composer = .edit(note) }
                Button("Excluir", systemImage: "trash", role: .destructive) {
                    perform { try environment.notes.softDelete(note, by: userRecordName) }
                }
            }
        }
        .accessibilityActions {
            if isMine {
                Button("Editar") { composer = .edit(note) }
                Button("Excluir") { perform { try environment.notes.softDelete(note, by: userRecordName) } }
            }
        }
    }

    private func toggleFavorite(_ note: Note) {
        guard let id = note.id else { return }
        perform { try environment.favorites.toggle(noteID: id, for: userRecordName) }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func name(for authorID: String?) -> String {
        space.members?.first { $0.userRecordName == authorID }?.displayName ?? String(localized: "Seu par")
    }
}

/// Writes a new note to the partner or edits one of your own.
struct NoteComposerView: View {
    enum Mode: Identifiable {
        case new
        case edit(Note)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let note): note.objectID.uriRepresentation().absoluteString
            }
        }
    }

    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String, mode: Mode) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        self.mode = mode
        if case .edit(let note) = mode {
            _text = State(initialValue: note.text ?? "")
        } else {
            _text = State(initialValue: "")
        }
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var partnerName: String? { environment.spaces.partner(of: userRecordName, in: space)?.displayName }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let partnerName {
                    Text("Para \(partnerName)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                TextField("Escreva algo bonito…", text: $text, axis: .vertical)
                    .font(.noteQuote)
                    .lineLimit(4...12)
                    .focused($isFocused)
                    .padding(Spacing.card)
                    .background(Palette.surface, in: .rect(cornerRadius: Radius.card, style: .continuous))
                    .accessibilityIdentifier("noteComposer.text")
                    .onChange(of: text) {
                        if text.count > NoteRepository.maximumLength {
                            text = String(text.prefix(NoteRepository.maximumLength))
                        }
                    }
                Text("\(text.count)/\(NoteRepository.maximumLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                Spacer()
            }
            .padding(Spacing.screen)
            .canvasBackground()
            .navigationTitle(isEditing ? "Editar recadinho" : "Novo recadinho")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Salvar" : "Enviar", action: send)
                        .disabled(trimmed.isEmpty)
                        .accessibilityIdentifier("noteComposer.send")
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func send() {
        do {
            switch mode {
            case .new:
                let recipient = environment.spaces.partner(of: userRecordName, in: space)?.userRecordName
                try environment.notes.create(text: trimmed, to: recipient, in: space, by: userRecordName)
            case .edit(let note):
                try environment.notes.update(note, text: trimmed, by: userRecordName)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    let environment = DemoData.previewEnvironment()
    NavigationStack {
        NotesView(environment: environment, space: environment.spaces.activeSpace()!, userRecordName: DemoData.ownerID)
    }
    .environment(\.managedObjectContext, environment.persistence.viewContext)
}
#endif
