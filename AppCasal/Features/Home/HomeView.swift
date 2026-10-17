//
//  HomeView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Início: couple header, latest note and summaries.
struct HomeView: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String
    let showSpace: () -> Void
    let showNotes: () -> Void

    @FetchRequest private var latestNotes: FetchedResults<Note>
    @State private var topInset: CGFloat = 0

    init(
        environment: AppEnvironment,
        space: CoupleSpace,
        userRecordName: String,
        showSpace: @escaping () -> Void,
        showNotes: @escaping () -> Void
    ) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        self.showSpace = showSpace
        self.showNotes = showNotes
        let request = Note.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@ AND deletedAt == nil", space)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        request.fetchLimit = 1
        _latestNotes = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CoupleHeroHeader(title: coupleTitle, daysTogether: space.daysTogether(), topInset: topInset)
                VStack(alignment: .leading, spacing: Spacing.m) {
                    latestNote
                    InfoCard(
                        systemImage: "target",
                        title: "Nenhuma meta ainda",
                        message: "Os planos de vocês e o progresso de cada um aparecem aqui."
                    )
                    SectionLabel(title: "Última memória")
                        .padding(.top, Spacing.xs)
                    InfoCard(
                        systemImage: "photo.on.rectangle.angled",
                        title: "Nenhuma memória ainda",
                        message: "A memória mais recente de vocês aparece aqui."
                    )
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, -Spacing.xxxl * 2)
                .padding(.bottom, Spacing.xl)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
        .canvasBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: showSpace) {
                    AvatarView(name: myName, size: 32)
                }
                .accessibilityLabel(Text("Nosso espaço"))
            }
        }
    }

    @ViewBuilder
    private var latestNote: some View {
        if let note = latestNotes.first {
            Button(action: showNotes) {
                NotePreviewCard(
                    text: note.text ?? "",
                    authorName: name(for: note.authorID),
                    date: note.createdAt ?? .now
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Abre os recados"))
        } else {
            InfoCard(
                systemImage: "envelope.open",
                title: "Nenhum recadinho ainda",
                message: "O último recadinho entre vocês aparece aqui."
            )
        }
    }

    private var myName: String {
        environment.spaces.member(for: userRecordName, in: space)?.displayName ?? ""
    }

    private var coupleTitle: String {
        guard let partner = environment.spaces.partner(of: userRecordName, in: space)?.displayName else {
            return myName
        }
        return String(localized: "\(myName) e \(partner)", comment: "Couple names, e.g. 'Ana e Lucas'")
    }

    private func name(for userRecordName: String?) -> String {
        space.members?.first { $0.userRecordName == userRecordName }?.displayName ?? String(localized: "Seu par")
    }
}

#if DEBUG
#Preview {
    let environment = DemoData.previewEnvironment()
    let space = environment.spaces.activeSpace()!
    NavigationStack {
        HomeView(environment: environment, space: space, userRecordName: DemoData.ownerID, showSpace: {}, showNotes: {})
    }
    .environment(\.managedObjectContext, environment.persistence.viewContext)
}
#endif
