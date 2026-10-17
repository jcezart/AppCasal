//
//  NotesView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Recados: received and sent notes. Writing and favorites arrive in the notes increment.
struct NotesView: View {
    enum Filter: Hashable {
        case received
        case sent
        case favorites
    }

    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @State private var filter = Filter.received
    @FetchRequest private var notes: FetchedResults<Note>

    init(space: CoupleSpace, userRecordName: String) {
        self.space = space
        self.userRecordName = userRecordName
        _notes = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
            predicate: NSPredicate(format: "space == %@ AND deletedAt == nil", space)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                PillSegmentedControl(selection: $filter, options: [
                    .init(value: .received, title: "Recebidos"),
                    .init(value: .sent, title: "Enviados"),
                    .init(value: .favorites, title: "Favoritos"),
                ])
                content
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .canvasBackground()
        .navigationTitle("Recados")
        .navigationSubtitle("Pequenas palavras, grandes significados.")
    }

    @ViewBuilder
    private var content: some View {
        switch filter {
        case .favorites:
            EmptyStateView(
                systemImage: "heart",
                title: "Nenhum favorito ainda",
                message: "Os recadinhos que você marcar com o coração aparecem aqui. Só você vê seus favoritos."
            )
        case .received, .sent:
            let filtered = notes.filter { (note: Note) in
                (note.authorID == userRecordName) == (filter == .sent)
            }
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "envelope",
                    title: filter == .sent ? "Nenhum recadinho enviado" : "Nenhum recadinho recebido",
                    message: "Pequenas palavras guardadas para sempre."
                )
            } else {
                LazyVStack(spacing: Spacing.s) {
                    ForEach(filtered) { note in
                        NoteCard(text: note.text ?? "", authorName: name(for: note.authorID), date: note.createdAt ?? .now)
                    }
                }
            }
        }
    }

    private func name(for authorID: String?) -> String {
        space.members?.first { $0.userRecordName == authorID }?.displayName ?? String(localized: "Seu par")
    }
}

#if DEBUG
#Preview {
    let environment = DemoData.previewEnvironment()
    NavigationStack {
        NotesView(space: environment.spaces.activeSpace()!, userRecordName: DemoData.ownerID)
    }
    .environment(\.managedObjectContext, environment.persistence.viewContext)
}
#endif
